SHELL=/usr/bin/env bash -euo pipefail

PLATFORM_OS ?= $(shell uname -s | tr A-Z a-z)
PLATFORM_ARCH ?= $(shell uname -m | sed -e 's/x86_64/amd64/')

YQ_PLATFORM = $(PLATFORM_OS)_$(PLATFORM_ARCH)
HELM_PLATFORM = $(PLATFORM_OS)-$(PLATFORM_ARCH)
ifeq ($(PLATFORM_OS),darwin)
SNYK_PLATFORM = macos
JQ_PLATFORM = osx-$(PLATFORM_ARCH)
else
SNYK_PLATFORM=$(PLATFORM_OS)
ifneq ($(filter %64,$(PLATFORM_ARCH)),)
JQ_PLATFORM = $(PLATFORM_OS)64
else
JQ_PLATFORM = $(PLATFORM_OS)32
endif
endif

all: images

images:
	$(MAKE) -C build/images

clean:
	$(MAKE) -C build/images clean

build/.env: build/requirements.txt
	$(RM) -r $@ && python3 -m venv $@
	. $@/bin/activate && \
		python3 -m ensurepip --upgrade && \
		pip install -r build/requirements.txt
	curl -sfL https://github.com/mikefarah/yq/releases/download/3.4.1/yq_$(YQ_PLATFORM) -o $@/bin/yq && chmod +x $@/bin/yq
	curl -sfL https://github.com/stedolan/jq/releases/download/jq-1.6/jq-$(JQ_PLATFORM) -o $@/bin/jq && chmod +x $@/bin/jq
	curl -sfL https://get.helm.sh/helm-v3.7.1-$(HELM_PLATFORM).tar.gz | tar -xzf - -O $(HELM_PLATFORM)/helm > $@/bin/helm && chmod +x $@/bin/helm
	curl -sfL https://static.snyk.io/cli/latest/snyk-$(SNYK_PLATFORM) -o $@/bin/snyk && chmod +x $@/bin/snyk

.PHONY: all images clean build/.env
