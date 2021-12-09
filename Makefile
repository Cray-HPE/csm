HELM_CACHE_HOME ?= $(abspath build/.helm/cache)
HELM_CONFIG_HOME ?= $(abspath build/.helm/config)

export HELM_CACHE_HOME HELM_CONFIG_HOME

SHELL=/usr/bin/env bash -euo pipefail

.PHONY: all images clean

all: images

images:
	$(MAKE) -C build/images

clean:
	$(MAKE) -C build/images clean
	$(RM) -r $(HELM_CACHE_HOME) $(HELM_CONFIG_HOME)
