#!/bin/bash
set -euo pipefail

for master in $(kubectl get nodes | grep 'master' | awk '{print $1}'); do
  if kubectl describe pod -n kube-system "kube-apiserver-${master}" | grep -q 'enable-admission-plugins=NodeRestriction,PodSecurityPolicy'; then
	echo "* Disabling PodSecurityPolicy on kube-apiserver node ${master}"
	  ssh "$master" "sed -i 's/--enable-admission-plugins=NodeRestriction,PodSecurityPolicy$/--enable-admission-plugins=NodeRestriction/' /etc/kubernetes/manifests/kube-apiserver.yaml"
	  for i in 1 2 3 4 5; do
	    if ! kubectl describe pod -n kube-system "kube-apiserver-${master}" | grep -q 'enable-admission-plugins=NodeRestriction,PodSecurityPolicy'; then
	      sleep 5
	      break
	    fi
	  sleep 10
	  done

	  if kubectl describe pod -n kube-system "kube-apiserver-${master}" | grep -q 'enable-admission-plugins=NodeRestriction,PodSecurityPolicy'; then
	    echo "kube-apiserver-${master} pod did not restart on its own. Forcing recreation."
	    kubectl rm pod -n kube-system "kube-apiserver-${master}"
	    sleep 10
	  fi
  else
	  echo "* PodSecurityPolicy already disabled on kube-apiserver node ${master}"
  fi
done

echo "* Validating kube-apiserver pods all have PodSecurityPolicy disabled"

fail=0
for master in $(kubectl get nodes | grep 'master' | awk '{print $1}'); do
  if kubectl describe pod -n kube-system "kube-apiserver-${master}" | grep -q 'enable-admission-plugins=NodeRestriction,PodSecurityPolicy'; then
    echo "PodSecurityPolicy failed to disable on kube-apiserver-${master}"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "PodSecurityPolicy has been disabled."
else
  echo "One or more kube-apiservers failed to disable PodSecurityPolicy. Please manually disable the PSP on the problem nodes by removing PodSecurityPolicy from the admissions-plugin line in /etc/kubernetes/manifests/kube-apiserver.yaml"
fi
