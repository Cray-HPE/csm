HELM_CACHE_HOME ?= .helm/cache
HELM_CONFIG_HOME ?= .helm/config

manifests_yaml := $(wildcard ../../manifests/*.yaml)
manifests_images := $(patsubst ../../manifests/%.yaml,manifests/%.txt,$(manifests_yaml))

SHELL=/usr/bin/env bash -euo pipefail


all: index.txt

index.txt: $(manifests_images) docker/index.txt
	cat $^ | sort -u | parallel --retries 5 --halt-on-error soon,fail=100% ./resolve.sh | sort -u > $@

manifests/%.txt: ../../manifests/%.yaml
	@mkdir -p $(@D)
	HELM_CACHE_HOME="$(HELM_CACHE_HOME)" HELM_CONFIG_HOME="$(HELM_CONFIG_HOME)" ./extract.sh $< | sort -u > $@

docker/index.txt: ../../docker/index.yaml
	@mkdir -p $(@D)
	../../hack/list-images.py $< | sort -u > $@


.PHONY: clean

clean:
	$(RM) -r "$(HELM_CACHE_HOME)" "$(HELM_CONFIG_HOME)"
	$(RM) index.txt $(manifests_images) docker/index.txt
