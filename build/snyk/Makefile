SHELL=/usr/bin/env bash -euo pipefail

GIT_COMMIT ?= $(shell git rev-parse --short HEAD)

all: docker

docker: ../images/index.txt
	parallel -j 75% --halt-on-error now,fail=1 -v -a ../images/index.txt --colsep '\t' ../../hack/snyk-scan.sh docker '{2}' '{1}'

../images/index.txt:
	$(MAKE) -C ../images index.txt

docker/snyk-results.xlsx: docker
	../hack/snyk-aggregate-results docker --sheet-name csm-$(GIT_COMMIT)

html: docker
	../../hack/snyk-to-html.sh .

.PHONY: docker clean

clean:
	$(RM) -f docker
