#!/bin/bash
echo "Applying new resource limits to coredns pods"
cfile=/tmp/coredns-deployment.yaml
kubectl -n kube-system get deployment coredns -o yaml > $cfile
yq w -i $cfile 'spec.template.spec.containers.(name==coredns).resources.requests.cpu' '300m'
yq w -i $cfile 'spec.template.spec.containers.(name==coredns).resources.requests.memory' '140Mi'
yq w -i $cfile 'spec.template.spec.containers.(name==coredns).resources.limits.memory' '340Mi'
kubectl apply -f $cfile
