## CASMINST-778 cloud-init failure/race-condition

#### Symptoms

1. NCN boots with a hostname of `ncn`
2. This command returns meta-data:
    ```bash
    ncn:~ # curl http://pit:8888/meta-data
    ```
3. No cloud-init jobs ran, or it returned `SUCCESS` in `/var/log/cloud-init-output.log` despite no hostname being set.


##### Fix

1. Run the provided script on the LiveCD:
    ```bash
    pit:~ # ./casminst-778.sh
    ```
2. Your web-root now has a usable script that nodes can fetch (`/var/www/ephemeral/workarounds/casminst-778.sh`)
3. For each afflicted NCN, login and run this:
   ```bash
   ncn:~ # screen -mS casminst-778
   ncn:~ # curl -s http://pit/ephemeral/workarounds/casminst-778 | sh -
   ```
   Now you can detach with `^A D` (ctrl+`a` then `d`).

