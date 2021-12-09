manifests_yaml := $(wildcard ../../manifests/*.yaml)
manifests_images := $(patsubst ../../manifests/%.yaml,manifests/%.txt,$(manifests_yaml))

SHELL=/usr/bin/env bash -euo pipefail

all: index.txt

index.txt: $(manifests_images) docker/index.txt
	cat $^ | sort -u | parallel --retries 5 --halt-on-error soon,fail=100% ./resolve.sh | sort -u > $@

manifests/%.txt: ../../manifests/%.yaml
	@mkdir -p $(@D)
	./extract.sh $< | sort -u > $@

# Special cases for handling cray-dns-unbound and cray-dhcp-kea charts until
# CASMNET-941 and CASMNET-943 are resolved.
manifests/core-services.txt: ../../manifests/core-services.yaml
	@mkdir -p $(@D)
	./extract.sh $< | sort -u | sed \
		-e '/cray-dns-unbound/d' \
		-e '/cray-dhcp-kea/d' > $@

docker/index.txt: ../../docker/index.yaml
	@mkdir -p $(@D)
	../../hack/list-images.py $< | sort -u > $@

.PHONY: clean

clean:
	$(RM) index.txt $(manifests_images) docker/index.txt
