all: docker

docker: Dockerfile
	docker build -t snyk-aggregate-results .

.PHONY: clean

clean:
	docker rmi snyk-aggregate-results
