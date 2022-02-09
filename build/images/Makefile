manifests_yaml := $(wildcard ../../manifests/*.yaml)
manifests_images := $(patsubst ../../manifests/%.yaml,manifests/%.txt,$(manifests_yaml))

HELM_CACHE_HOME ?= $(abspath ../.helm/cache)
HELM_CONFIG_HOME ?= $(abspath ../.helm/config)
export HELM_CACHE_HOME HELM_CONFIG_HOME

SHELL=/usr/bin/env bash -euo pipefail

all: index.txt chartmap

index.txt: $(manifests_images) docker/index.txt
	cat $^ | sort -u | parallel -j 75% --retries 5 --halt-on-error soon,fail=100% ./inspect.sh | sort -u > $@

manifests/%.txt: ../../manifests/%.yaml
	@mkdir -p $(@D)
	./extract.sh $< | sort -u > $@

docker/index.txt: ../../docker/index.yaml
	@mkdir -p $(@D)
	../../hack/list-images.py $< | sort -u > $@

.PHONY: chartmap

chartmap:
	@echo "manifest,chart,image" >> chartmap.csv
	@tac chartmap.csv > chartmap-tac.csv
	@mv chartmap-tac.csv chartmap.csv

.PHONY: clean

clean:
	$(RM) index.txt $(manifests_images) docker/index.txt chartmap.csv
