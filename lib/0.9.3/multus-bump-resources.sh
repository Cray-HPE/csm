#!/bin/bash
echo "Applying new resource limits to /etc/cray/kubernetes/multus-daemonset.yml"
mfile=/etc/cray/kubernetes/multus-daemonset.yml
yq w -i --doc 5 $mfile 'spec.template.spec.containers.(name==kube-multus).resources.limits.memory' '100Mi'
kubectl apply -f $mfile
