# CASMINST-1297 Workaround

Before the PIT is rebooted to become m001 up to two steps need to be taken.

1. **Before** running `csi handoff bss-metadata` as instructed in 007-CSM-INSTALL-REBOOT:
    * Take a copy of `data.json`:
    ```bash
   pit# cp /var/www/ephemeral/configs/data.json ./data-bss.json 
   ```
   * Edit that file and make 2 changes:
        1. Find the entry corresponding to ncn-m001 (you can search for `hostname`). Remove this line from the `runcmd` array:
            ```text
           "/srv/cray/scripts/metal/set-dhcp-to-static.sh",
            ```
        2. In the "Global" section update:
            ```text
            "dns-server": "10.252.1.12",
            ```
           To (the IP of Unbound)::
            ```text
            "dns-server": "10.92.100.225",
            ```
   * Ensure when you do the handoff step you give the path to this patched file and not the one in the configs directory.
2. This step is always safe to execute however if m001 is to be rebooted more than 2 hours after the first master was 
   initialized the join command must be refreshed with a new certificate key (**note** this need to be run on m002):
```bash
ncn-m002# kubeadm init phase upload-certs --upload-certs --config /etc/cray/kubernetes/kubeadm.yaml 2>/dev/null | tail -n 1 \
  > /etc/cray/kubernetes/certificate-key
ncn-m002# kubeadm token create --print-join-command > /etc/cray/kubernetes/join-command 2>/dev/null
ncn-m002# echo "$(cat /etc/cray/kubernetes/join-command) --control-plane --certificate-key $(cat /etc/cray/kubernetes/certificate-key)" \
  > /etc/cray/kubernetes/join-command-control-plane
```