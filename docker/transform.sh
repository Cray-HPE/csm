#!/usr/bin/env bash

# Copyright 2020-2021 Hewlett Packard Enterprise Development LP

# Moves docker directories to locations where helm charts will be expecting them

set -e

DISTDIR=$1

# Transform images to dtr.dev.cray.com structure
(
    cd "${DISTDIR}"
    mkdir -p dtr.dev.cray.com
    mkdir -p dtr.dev.cray.com/cray

    # Move artifactory.alogl60.net container-image 3rd party rebuilds
    mv -v artifactory.algol60.net/csm-docker/stable/docker.io/library dtr.dev.cray.com/library
    mv -v artifactory.algol60.net/csm-docker/stable/docker.io dtr.dev.cray.com/docker.io
    mv -v artifactory.algol60.net/csm-docker/stable/gcr.io dtr.dev.cray.com/gcr.io
    mv -v artifactory.algol60.net/csm-docker/stable/ghcr.io dtr.dev.cray.com/ghcr.io
    mv -v artifactory.algol60.net/csm-docker/stable/k8s.gcr.io dtr.dev.cray.com/k8s.gcr.io
    mv -v artifactory.algol60.net/csm-docker/stable/quay.io dtr.dev.cray.com/quay.io
    mv -v artifactory.algol60.net/csm-docker/stable/registry.opensource.zalan.do dtr.dev.cray.com/registry.opensource.zalan.do

    # Move artiractory.algol60.net cray images
    mv -v artifactory.algol60.net/csm-docker/stable/* dtr.dev.cray.com/cray/
    mv -v artifactory.algol60.net/csm-docker/unstable/* dtr.dev.cray.com/cray/ || true

    # Move arti.dev.cray.com images
    mv -v arti.dev.cray.com/third-party-docker-stable-local/docker.io/* dtr.dev.cray.com/docker.io/
    mv -v arti.dev.cray.com/third-party-docker-stable-local/sdlc-ops/ dtr.dev.cray.com/
    mv -v arti.dev.cray.com/baseos-docker-master-local/ dtr.dev.cray.com/baseos/
    mv -v arti.dev.cray.com/csm-docker-stable-local/* dtr.dev.cray.com/cray/
    mv -v arti.dev.cray.com/shasta-docker-stable-local/* dtr.dev.cray.com/cray/
    mv -v arti.dev.cray.com/analytics-docker-stable-local/* dtr.dev.cray.com/cray/
    mv -v arti.dev.cray.com/wlm-slurm-docker-stable-local/* dtr.dev.cray.com/cray/
    mv -v arti.dev.cray.com/internal-docker-stable-local/* dtr.dev.cray.com/cray/
    mv -v arti.dev.cray.com/csm-docker-unstable-local/docker.io/library/* dtr.dev.cray.com/library/

    cd dtr.dev.cray.com
    mkdir -pv cache/
    mkdir -v loftsman
    mv -v cray/docker-kubectl:* loftsman/
    mv -v cray/loftsman:* loftsman/
    mv -v docker.io/alpine/ alpine/
    mv -v docker.io/appropriate/ appropriate/
    mv -v docker.io/bats/ bats/
    mv -v docker.io/bitnami bitnami/
    mv -v docker.io/ceph ceph/
    mv -v docker.io/coredns coredns
    mv -v docker.io/curlimages/ curlimages/
    mv -v docker.io/demisto/ demisto/
    mv -v docker.io/ghostunnel/ ghostunnel/
    mv -v docker.io/grafana grafana/
    mv -v docker.io/istio istio/
    mv -v docker.io/jaegertracing jaegertracing/
    mv -v docker.io/jboss/ jboss/
    mv -v docker.io/gitea/ gitea/
    mv -v quay.io/kiali/ kiali/
    mv -v docker.io/jettech jettech/
    mv -v docker.io/jimmidyson/ jimmidyson/
    mv -v docker.io/kiwigrid/ kiwigrid/
    mv -v docker.io/metallb/ metallb/
    mv -v docker.io/openpolicyagent openpolicyagent
    mv -v docker.io/prom/ prom/
    mv -v docker.io/roffe/ roffe/
    mv -v docker.io/sonatype/ sonatype/
    mv -v docker.io/unguiculus/ unguiculus/
    mv -v docker.io/velero/ velero/
    mv -v docker.io/weaveworks/ weaveworks/
    mv -v docker.io/wrouesnel/postgres_exporter:latest/ cache/postgres-exporter:latest/
    mv -v docker.io/zeromq/ zeromq/
    mv -v gcr.io/spiffe-io/ spiffe-io/
    mv -v ghcr.io/banzaicloud/ banzaicloud/
    mv -v library/nginx:* cache/
    mv -v library/postgres:* cache/
    mv -v quay.io/strimzi/ strimzi/
    mv -v quay.io/bitnami/* bitnami/
    mv -v quay.io/cephcsi/ cephcsi/
    mv -v quay.io/coreos coreos/
    mv -v quay.io/jetstack jetstack/
    mv -v quay.io/k8scsi/ k8scsi/
    mv -v quay.io/keycloak/ keycloak/
    mv -v quay.io/prometheus/ prometheus/
    mv -v quay.io/sighup/ sighup/
    mv -v registry.opensource.zalan.do/acid/ acid/

    # Temporary workarounds
    cp -v -r baseos/alpine:3.12 baseos/alpine:3.11.5
    cp -v -r baseos/alpine:3.12 baseos/alpine:3.12.0
    cp -v -r cray/cray-nexus-setup:0.5.2 cray/cray-nexus-setup:0.3.2
    cp -v -r cray/cray-nexus-setup:0.5.2 cray/cray-nexus-setup:0.4.0
    cp -v -r cray/cray-uai-broker:1.2.4 cray/cray-uai-broker:latest
    cp -v -r cray/istio/* cray/
    cp -v -r cray/istio/* istio/
    cp -v -r cray/proxyv2* istio/
    cp -v -r loftsman/docker-kubectl:0.2.0 loftsman/docker-kubectl:latest
    cp -v -r loftsman/loftsman:0.5.1 loftsman/loftsman:latest
    cp -v -r openpolicyagent/opa:0.24.0-envoy-1 openpolicyagent/opa:latest

    mv -v appropriate tutum
    mv -v bitnami/minideb:bullseye bitnami/minideb:stretch
    mv -v cache/nginx:1.18.0-alpine cache/nginx:1.18.0
    mv -v cache/postgres-exporter:latest cache/postgres-exporter:0.8.2
    mv -v cache/postgres:13.2-alpine cache/postgres:13.2
    mv -v roffe/kube-etcdbackup:latest roffe/kube-etcdbackup:v0.1.0
)
