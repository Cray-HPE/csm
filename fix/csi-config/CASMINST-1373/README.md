# CASMINST-1373 Workaround

Some services have not fully migrated away from using "api-gw-service-nmn.local" as the
internal kubernetes API getaway alias.  As a workaround, issue the following `sed` command
to update the value in customizations.yaml

```
pit# sed -i 's/internal_api: api-gw-service.nmn/internal_api: api-gw-service-nmn.local/g' /mnt/pitdata/prep/${SYSTEM_NAME}/customizations.yaml 2>/dev/null
```
