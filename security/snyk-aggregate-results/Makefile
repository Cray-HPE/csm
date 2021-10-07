# Copyright 2021 Hewlett Packard Enterprise Development LP

all: docker

docker: Dockerfile entrypoint.sh requirements.txt snyk-aggregate-results.py
	docker build --pull -t snyk-aggregate-results .

.PHONY: clean

clean:
	docker rmi snyk-aggregate-results
