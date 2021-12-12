SHELL=/usr/bin/env bash -euo pipefail

all: index.txt

index.txt: ../../docker/index.yaml
	../../hack/list-images.py $< | sort -u | parallel -j 75% --retries 5 --halt-on-error soon,fail=100% ./inspect.sh | sort -u > $@

.PHONY: clean

clean:
	$(RM) index.txt
