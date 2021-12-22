SHELL=/usr/bin/env bash -euo pipefail

HELM_CACHE_HOME ?= $(abspath build/.helm/cache)
HELM_CONFIG_HOME ?= $(abspath build/.helm/config)
export HELM_CACHE_HOME HELM_CONFIG_HOME

all: images

images:
	$(MAKE) -C build/images

clean:
	$(MAKE) -C build/images clean
	$(RM) -r $(HELM_CACHE_HOME) $(HELM_CONFIG_HOME)

build/.env: build/requirements.txt build/install-tools.sh
	$(RM) -r $@ && python3 -m venv $@
	. $@/bin/activate && \
		python3 -m ensurepip --upgrade && \
		pip install -r build/requirements.txt
	./build/install-tools.sh -d $@/bin

.PHONY: all images clean build/.env
