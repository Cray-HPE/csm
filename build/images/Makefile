manifests_yaml := $(wildcard ../../manifests/*.yaml)
manifests_images := $(patsubst ../../manifests/%.yaml,manifests/%.txt,$(manifests_yaml))

HELM_CACHE_HOME ?= $(abspath ../.helm/cache)
HELM_CONFIG_HOME ?= $(abspath ../.helm/config)
export HELM_CACHE_HOME HELM_CONFIG_HOME

SHELL=/usr/bin/env bash -euo pipefail

# Get the process ID of the process running Make
MAKEPID:= $(shell echo $$PPID)

all: index.txt chartmap.csv

index.txt: docker/index.txt $(manifests_images)
	cat $^ | sort -u | parallel -j 75% --retries 5 --halt-on-error soon,fail=100% ./inspect.sh | sort -u > $@

# Kill (SIGINT) the make PGID to short-circuit parallel makes (fail fast)
manifests/%.txt: ../../manifests/%.yaml
	@mkdir -p $(@D)
	./extract.sh $< | sort -u > $@ || kill -INT -$(MAKEPID)

docker/index.txt: ../../docker/index.yaml
	@mkdir -p $(@D)
	./list_images.sh $< | sort -u > $@ || kill -INT -$(MAKEPID)

chartmap.csv: index.txt
	@echo "Helm charts cached:"
	@ls -1 $(HELM_CACHE_HOME)/repository/
	@echo "manifest,chart,image" > chartmap.csv
	@find ./charts -type f -name chartmap.csv -exec cat {} \; | sort -u >> chartmap.csv

.PHONY: clean
clean:
	rm -rf index.txt $(manifests_images) docker/index.txt chartmap.csv charts/ values/ ../.helm docker/ manifests/

