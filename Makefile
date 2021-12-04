SHELL=/usr/bin/env bash -euo pipefail

all: images

images:
	$(MAKE) -C build/images
