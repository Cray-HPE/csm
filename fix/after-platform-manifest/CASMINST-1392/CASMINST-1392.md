After Kea has been installed, the cray-dhcp-kea-jobs configmap should be manually updated

Change line 626 in configmap cray-dhcp-kea-jobs

```
if 'sw-' not in ip_reservations[j]['Name']:
```

to

```
if 'sw-' not in ip_reservations[j]['Name'] and 'external-dns' not in ip_reservations[j]['Name']:
```

