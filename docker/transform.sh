#!/usr/bin/env bash

# Copyright 2020-2021 Hewlett Packard Enterprise Development LP

# Moves docker directories to locations where helm charts will be expecting them

set -e

DISTDIR=$1

# Transform images to 1.4 dtr.dev.cray.com structure
(
    cd "${DISTDIR}"
    mv -v arti.dev.cray.com/third-party-docker-stable-local/ dtr.dev.cray.com/
    mv -v dtr.dev.cray.com/registry.opensource.zalan.do/acid/* dtr.dev.cray.com/acid/
    mv -v arti.dev.cray.com/baseos-docker-master-local/ dtr.dev.cray.com/baseos/
    mv -v arti.dev.cray.com/csm-docker-stable-local/ dtr.dev.cray.com/cray/
    mv -v arti.dev.cray.com/shasta-docker-stable-local/* dtr.dev.cray.com/cray/
    mv -v arti.dev.cray.com/analytics-docker-stable-local/* dtr.dev.cray.com/cray/
    mv -v arti.dev.cray.com/wlm-slurm-docker-stable-local/* dtr.dev.cray.com/cray/
    mv -v arti.dev.cray.com/internal-docker-stable-local/* dtr.dev.cray.com/cray/
    mv -v arti.dev.cray.com/csm-docker-unstable-local/docker.io/library/* dtr.dev.cray.com/library/
    mv -v artifactory.algol60.net/csm-docker/stable/docker.io/* dtr.dev.cray.com/docker.io/
    mv -v artifactory.algol60.net/csm-docker/unstable/* dtr.dev.cray.com/cray/ || true
    mv -v artifactory.algol60.net/csm-docker/stable/* dtr.dev.cray.com/cray/ || true
    mkdir -pv dtr.dev.cray.com/prometheus/
    mv -v quay.io/prometheus/* dtr.dev.cray.com/prometheus/

    cd dtr.dev.cray.com
    mv -v nginx:* cache/
    mv -v docker.io/library/postgres:* cache/
    mv -v wrouesnel/postgres_exporter:0.8.2/ cache/postgres-exporter:0.8.2/
    mv -v ghcr.io/banzaicloud/ banzaicloud/
    mv -v docker.io/bats/ bats/
    mv -v docker.io/bitnami/* bitnami/
    mv -v docker.io/grafana/* grafana/
    mv -v docker.io/jboss/ jboss/
    mv -v quay.io/kiali/ kiali/
    mv -v openjdk:* library/
    mv -v redis:* library/
    mv -v vault:* library/
    mv -v docker.io/prom/* prom/
    mv -v quay.io/prometheus/* prometheus/
    mv -v docker.io/weaveworks/ weaveworks/
    mv -v docker.io/unguiculus/ unguiculus/
    mv -v gcr.io/spiffe-io/ spiffe-io/
    mv -v quay.io/cephcsi/ cephcsi/
    mv -v quay.io/coreos/* coreos/
    mv -v quay.io/k8scsi/ k8scsi/
    mv -v quay.io/keycloak/ keycloak/
    mv -v quay.io/sighup/ sighup/
    mkdir -v loftsman
    mv -v cray/docker-kubectl:* loftsman/
    mv -v cray/loftsman:* loftsman/

    # Temporary workarounds
    cp -v -r baseos/alpine:3.12 baseos/alpine:3.11.5
    cp -v -r baseos/alpine:3.12 baseos/alpine:3.12.0
    cp -v -r cray/cray-nexus-setup:0.5.2 cray/cray-nexus-setup:0.3.2
    cp -v -r cray/cray-nexus-setup:0.5.2 cray/cray-nexus-setup:0.4.0
    cp -v -r cray/cray-uai-broker:1.2.3 cray/cray-uai-broker:latest
    cp -v -r loftsman/docker-kubectl:0.2.0 loftsman/docker-kubectl:latest
    cp -v -r loftsman/loftsman:0.5.1 loftsman/loftsman:latest
    cp -v -r openpolicyagent/opa:0.24.0-envoy-1 openpolicyagent/opa:latest
)
