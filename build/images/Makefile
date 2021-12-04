manifests_yaml := $(wildcard ../../manifests/*.yaml)
manifests_images := $(patsubst ../../manifests/%.yaml,manifests/%.txt,$(manifests_yaml))

SHELL=/usr/bin/env bash -euo pipefail


all: index.txt

index.txt: $(manifests_images) docker/index.txt
	@mkdir -p $(@D)
	cat $^ | sort -u | parallel -k --retries 5 --halt-on-error soon,fail=100% ./resolve.sh | sort -u > $@

manifests/%.txt: manifests/%.yaml
	@mkdir -p $(@D)
	./extract.sh $< | sort -u > $@

docker/index.txt: ../../docker/index.yaml
	@mkdir -p $(@D)
	../../hack/list-images.py $< | sort -u > $@


.PHONY: clean

clean:
	$(RM) -r index.txt manifests/*.txt docker/index.txt
