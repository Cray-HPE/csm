#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

# Moves docker directories to locations where helm charts will be expecting them

set -e

DISTDIR=$1

# Transform images to 1.4 dtr.dev.cray.com structure
(
    cd "${DISTDIR}"
    mv arti.dev.cray.com/third-party-docker-stable-local/ dtr.dev.cray.com/
    mv dtr.dev.cray.com/registry.opensource.zalan.do/acid/* dtr.dev.cray.com/acid/
    mv arti.dev.cray.com/baseos-docker-master-local/ dtr.dev.cray.com/baseos/
    mv arti.dev.cray.com/csm-docker-stable-local/ dtr.dev.cray.com/cray/
    mv arti.dev.cray.com/shasta-docker-stable-local/* dtr.dev.cray.com/cray/
    mv arti.dev.cray.com/analytics-docker-stable-local/* dtr.dev.cray.com/cray/
    mv arti.dev.cray.com/wlm-slurm-docker-stable-local/* dtr.dev.cray.com/cray/
    mv arti.dev.cray.com/internal-docker-stable-local/* dtr.dev.cray.com/cray/
    mv arti.dev.cray.com/csm-docker-unstable-local/docker.io/library/* dtr.dev.cray.com/library/
    mv artifactory.algol60.net/csm-docker/unstable/* dtr.dev.cray.com/cray/ || true
    mv artifactory.algol60.net/csm-docker/stable/* dtr.dev.cray.com/cray/ || true

    cd dtr.dev.cray.com
    mv gitea/* cache/
    mv nginx:* cache/
    mv docker.io/library/postgres:* cache/
    mv wrouesnel/postgres_exporter:0.8.2/ cache/postgres-exporter:0.8.2/
    mv ghcr.io/banzaicloud/ banzaicloud/
    mv docker.io/bitnami/* bitnami/
    mv docker.io/grafana/* grafana/
    mv docker.io/jboss/ jboss/
    mv quay.io/kiali/ kiali/
    mv openjdk:* library/
    mv redis:* library/
    mv vault:* library/
    mv docker.io/prom/* prom/
    mv quay.io/prometheus/* prometheus/
    mv docker.io/weaveworks/ weaveworks/
    mv docker.io/unguiculus/ unguiculus/
    mv gcr.io/spiffe-io/ spiffe-io/
    mv quay.io/cephcsi/ cephcsi/
    mv quay.io/coreos/* coreos/
    mv quay.io/k8scsi/ k8scsi/
    mv quay.io/keycloak/ keycloak/
    mv quay.io/sighup/ sighup/
    mkdir loftsman
    mv cray/docker-kubectl:* loftsman/
    mv cray/loftsman:* loftsman/

    # Temporary workarounds
    cp -r baseos/alpine:3.12 baseos/alpine:3.11.5
    cp -r baseos/alpine:3.12 baseos/alpine:3.12.0
    cp -r cray/cray-nexus-setup:0.5.2 cray/cray-nexus-setup:0.3.2
    cp -r cray/cray-nexus-setup:0.5.2 cray/cray-nexus-setup:0.4.0
    cp -r cray/cray-uai-broker:1.2.1 cray/cray-uai-broker:latest
    cp -r loftsman/docker-kubectl:0.2.0 loftsman/docker-kubectl:latest
    cp -r loftsman/loftsman:0.5.1 loftsman/loftsman:latest
    cp -r openpolicyagent/opa:0.24.0-envoy-1 openpolicyagent/opa:latest
)
