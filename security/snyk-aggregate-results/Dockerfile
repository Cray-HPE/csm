FROM artifactory.algol60.net/docker.io/library/python:3

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN pip install --quiet --no-cache-dir -r requirements.txt

COPY . .

ENTRYPOINT [ "/usr/src/app/entrypoint.sh" ]
