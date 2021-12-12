FROM artifactory.algol60.net/docker.io/library/python:3

WORKDIR /usr/src/app

RUN pip install --quiet --no-cache-dir openpyxl pandas

COPY . .

ENTRYPOINT [ "/usr/src/app/entrypoint.sh" ]
