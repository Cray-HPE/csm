#
# MIT License
#
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
SHELL=/usr/bin/env bash -euo pipefail

RELEASE_NAME ?= csm
RELEASE_VERSION ?= $(shell ./version.sh)
RELEASE ?= $(RELEASE_NAME)-$(RELEASE_VERSION)
BUILDDIR ?= dist/$(RELEASE)
PARALLEL_JOBS ?= "1"

define header
	@echo
	@echo "****************************************************************************"
	@echo "${1}"
	@echo "****************************************************************************"
endef

# List targets (aliases)
.PHONY: list
list:
	@echo "List of targets:"
	@make -pRrq | awk '{ if ( $$0 == "# Files" ) started=1; if ( $$0 ~ /^[^#\.\t].+:/ && $$0 !~ /^dist\// && started == 1 && not_target != 1 ) print "\t" $$0; not_target=( $$0 == "# Not a target:" ); }' | sed -e 's/:.*//' | sort || true

# Cleanup
.PHONY: clean
clean:
	$(MAKE) -C build/images clean
	$(RM) -rf dist/

# Pre-flight checks
pre-flight-check:
	$(call header,"Executing pre-flight checks ...")
	@for t in curl wget yq jq parallel timeout rsync rpm rpm2cpio cpio docker cosign; do echo -ne "Checking $$t ... "; which $$t; done
	./get_base.sh

# Validate assets (node images - ISO, squashfs, etc)
.PHONY: validate-assets
validate-assets: pre-flight-check
	$(call header,"Validating assets")
	hack/assets.sh --validate

# Validate container image references and produce image index (build/images/index.txt),
# chart map (build/images/chartmap.csv) and helm chart cache (.helm/cache)
.PHONY: validate-images
validate-images: pre-flight-check
	$(call header,"Validating container images")
	@$(MAKE) -C build/images -f Makefile

# Validate that all RPMs explicitly stated in manifests can be resolved
.PHONY: validate-rpms
validate-rpms: pre-flight-check
	$(call header,"Validating RPM Index")
	hack/rpms.sh --validate

# Validate that all RPMs installed on node images (aka "embedded repo") are available for download
.PHONY: validate-embedded-repo
validate-embedded-repo: pre-flight-check
	$(call header,"Validating Embedded Repo RPM Index")
	hack/embedded-repo.sh --validate

# Populate build directory with node image files - ISO, squashfs, etc
.PHONY: assets
assets:
	$(call header,"Synchronizing assets into $(BUILDDIR)/images")
	@$(MAKE) $(BUILDDIR)/images
$(BUILDDIR)/images:
	hack/assets.sh --download

# Populate build directory with container images
# Depends on build/images/index.txt file, produced by validate-images
.PHONY: images
images: validate-images
	$(call header,"Synchronizing container images into $(BUILDDIR)/docker")
	@$(MAKE) $(BUILDDIR)/docker
$(BUILDDIR)/docker:
	parallel -j1 --halt-on-error now,fail=1 -v \
		-a build/images/index.txt --colsep '\t' \
		build/images/sync.sh "{1}" "{2}" "$(BUILDDIR)/docker/"
	cp "build/images/index.txt" "dist/$(RELEASE)-images.txt"

# Validate image signatures with cosign.
# Depends on build/images/index.txt file, produced by validate-images
.PHONY: image-signatures
image-signatures: validate-images
	$(call header,"Validating container image signatures with cosign")
	@$(MAKE) $(BUILDDIR)/security/keys/oci
$(BUILDDIR)/security/keys/oci:
	hack/cosign-install-keys.sh
	parallel -j $(PARALLEL_JOBS) --halt-on-error now,fail=1 \
		-a build/images/index.txt --colsep '\t' \
		hack/cosign-verify-image.sh '{1}' '{2}'

# Snyk scanning images
# Depends on build/images/index.txt file, produced by validate-images
.PHONY: snyk
snyk: validate-images
	$(call header,"Performing Snyk scan for container images in $(BUILDDIR)/docker")
	@$(MAKE) $(BUILDDIR)/scans
$(BUILDDIR)/scans:
	parallel -j $(PARALLEL_JOBS) --halt-on-error now,fail=1 -v \
		--ungroup -a build/images/index.txt --colsep '\t' \
		hack/snyk-scan.sh '{1}' '{2}' "$(BUILDDIR)/scans/docker"
	cp build/images/chartmap.csv "$(BUILDDIR)/scans/docker/"
	hack/snyk-aggregate-results.sh "$(BUILDDIR)/scans/docker" --helm-chart-map "/data/chartmap.csv" --sheet-name "$(RELEASE)"
	hack/snyk-to-html.sh "$(BUILDDIR)/scans/docker"
	mkdir -p "dist/$(RELEASE)-scans"
	rsync -aq "$(BUILDDIR)/scans/" "dist/$(RELEASE)-scans/"
	cp "dist/$(RELEASE)-scans/docker/snyk-results.xlsx" "dist/$(RELEASE)-snyk-results.xlsx"
	tar -C "dist" --owner=0 --group=0 -cvzf "dist/$(RELEASE)-scans.tar.gz" "$(RELEASE)-scans/" --remove-files

# Pluto scans charts for deprecated APIs in chart templates, generated in build/images/templates/ during validate-images
.PHONY: pluto
pluto: validate-images
	$(call header,"Performing Pluto scan for deprecated API usage in $(BUILDDIR)/helm")
	@$(MAKE) dist/pluto-report.txt
dist/pluto-report.txt:
	mkdir -p dist
	docker run --rm -v "$(shell realpath build/images/templates):/charts" us-docker.pkg.dev/fairwinds-ops/oss/pluto:v5 detect-files -d /charts -o custom \
		--columns "FILEPATH,COMPONENT,KIND,VERSION,REPLACEMENT,DEPRECATED,DEPRECATED IN,REMOVED,REMOVED IN,REPL AVAIL,REPL AVAIL IN" -v 3 \
		| sed -e 's|^///charts/||' | sed -e 's|\.yaml||' | sed -e 's|^FILEPATH            |CHART|' > dist/pluto-report.txt || true

# Populate build directory with helm charts
# Depends on validate-images, because charts are taken from build/.helm/cache repo created during image validation.
.PHONY: charts
charts: validate-images
	$(call header,"Synchronizing Helm charts into $(BUILDDIR)/helm")
	@$(MAKE) $(BUILDDIR)/helm
$(BUILDDIR)/helm:
	mkdir -p "$(BUILDDIR)/helm"
	rsync -av build/.helm/cache/repository/*.tgz "$(BUILDDIR)/helm"

# Synchronizing RPMs explicitly described in manifests into build dir
.PHONY: rpms
rpms: pre-flight-check
	$(call header,"Synchronizing RPMs")
	@$(MAKE) $(BUILDDIR)/rpm/cray
$(BUILDDIR)/rpm/cray:
	hack/rpms.sh --download

# Synchronizing RPMs installed on node images (aka "embedded repo") into build dir.
# Depends on "rpms" as we search for duplicated packages.
.PHONY: embedded-repo
embedded-repo: rpms
	$(call header,"Building embedded RPM repo")
	@$(MAKE) $(BUILDDIR)/rpm/embedded
$(BUILDDIR)/rpm/embedded:
	hack/embedded-repo.sh --download

# Unpack docs-csm RPM into build dir
.PHONY: docs
docs: rpms
	$(call header,"Unpacking docs-csm into build dir")
	@$(MAKE) $(BUILDDIR)/docs
$(BUILDDIR)/docs:
	mkdir -p "$(BUILDDIR)/tmp/docs"
	cd "$(BUILDDIR)/tmp/docs" && \
		find "$(abspath $(BUILDDIR))/rpm/cray/csm/noos" -type f -name docs-csm-\*.rpm | head -n 1 | xargs -n 1 rpm2cpio | cpio -idvm ./usr/share/doc/csm/*
	mv "$(BUILDDIR)/tmp/docs/usr/share/doc/csm" "$(BUILDDIR)/docs"
	rm -Rf "$(BUILDDIR)/tmp"

# Unpack workarounds RPM(s) into build dir
.PHONY: workarounds
workarounds: rpms
	$(call header,"Unpacking workarounds into build dir")
	@$(MAKE) $(BUILDDIR)/workarounds
$(BUILDDIR)/workarounds:
	mkdir -p "$(BUILDDIR)/tmp/workarounds"
	cd "$(BUILDDIR)/tmp/workarounds" && \
		find "$(abspath $(BUILDDIR))/rpm/cray/csm/sle-15sp2" -type f -name csm-install-workarounds-\*.rpm | head -n 1 | xargs -n 1 rpm2cpio | cpio -idvm ./opt/cray/csm/workarounds/*
	find "$(BUILDDIR)/tmp/workarounds" -type f -name '.keep' -delete
	mv "$(BUILDDIR)/tmp/workarounds/opt/cray/csm/workarounds" "$(BUILDDIR)/workarounds"
	rm -Rf "$(BUILDDIR)/tmp"

# Create CSM release tarball
.PHONY: package
package: rpms images image-signatures snyk charts assets docs workarounds
	$(call header,"Creating CSM release tarball")
	@$(MAKE) dist/$(RELEASE).tar.gz
dist/$(RELEASE).tar.gz:
	./release.sh
