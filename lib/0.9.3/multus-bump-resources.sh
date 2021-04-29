#!/bin/bash
echo "Applying new resource limits to kube-multus pods"
mfile=/tmp/multus-daemonset.yml
kubectl -n kube-system get daemonset kube-multus-ds-amd64 -o yaml > $mfile
yq w -i --doc 5 $mfile 'spec.template.spec.containers.(name==kube-multus).resources.limits.memory' '100Mi'
kubectl apply -f $mfile
