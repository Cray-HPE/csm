all: docker

docker: Dockerfile entrypoint.sh requirements.txt snyk-aggregate-results.py
	docker build -t snyk-aggregate-results .

.PHONY: clean

clean:
	docker rmi snyk-aggregate-results
