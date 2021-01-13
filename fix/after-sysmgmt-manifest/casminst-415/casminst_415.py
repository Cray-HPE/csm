#!/usr/bin/python3
 
import json
import os
import sys
import subprocess as subp
 
from cryptography import x509
 
def get_bss_cloud_init():
 
    p = subp.run(["curl -ks http://api_gw_service.local:8888/meta-data?key=Global"],
                 shell=True,
                 stdout=subp.PIPE,
                 encoding="utf-8")
    return json.loads(p.stdout)
 
def cloud_init_certs(certs):
 
    ca_certs = dict()
    ca_certs['remove-defaults'] = False
    ca_certs['trusted'] = list()
 
    f_list = list()
    for c in certs:
        ca_certs['trusted'].append(c.replace('\\n', '\n'))
 
    return ca_certs
 
def cloud_init_spire(certs):
 
    spire = dict()
    p = subp.run(["helm get values spire -a -n spire | grep fqdn:"],
                 shell=True,
                 stdout=subp.PIPE,
                 encoding="utf-8")
    spire_fqdn = p.stdout.strip().split()[-1].strip()
    p = subp.run(["helm get values spire -a -n spire | grep trustDomain:"],
                 shell=True,
                 stdout=subp.PIPE,
                 encoding="utf-8")
    spire_trustdomain = p.stdout.strip().split()[-1].strip()
    spire['domain'] = spire_trustdomain
    spire['server'] = spire_fqdn
 
    # find root CA in certs
    for c in certs:
        _c = x509.load_pem_x509_certificate(bytes(c, "utf-8")) 
        if _c.subject == _c.issuer:
            spire['certbundle'] = c.replace('\\n', '\n')
 
    return spire
 
def main():
 
    cert_bundle = sys.stdin.read()
    CERT_START = "-----BEGIN CERTIFICATE-----"
    certs = [CERT_START+c for c in cert_bundle.split(CERT_START)][1:]
    certs[-1] = certs[-1] + '\n'
 
    if len(certs) < 1:
        print("[e] no certs detected from STDIN?")
        sys.exit(1)
 
    existing_meta = get_bss_cloud_init()
    meta = dict()
 
    meta["hosts"] = ["Global"]
    meta["cloud-init"] = dict()
    meta["cloud-init"]["meta-data"] = dict()
 
    for k in existing_meta.keys():
        meta["cloud-init"]["meta-data"][k] = existing_meta[k]

    meta["cloud-init"]["meta-data"]["ca-certs"] = cloud_init_certs(certs)
    meta["cloud-init"]["meta-data"]["spire"] = cloud_init_spire(certs)

    fn = "bss_cloudinit_update.json"
    with open(fn, 'w') as f:
        json.dump(meta,f,indent=3,sort_keys=True)
    print(f"[i] BSS update written to {fn}")
 
if __name__ == "__main__":
    main()