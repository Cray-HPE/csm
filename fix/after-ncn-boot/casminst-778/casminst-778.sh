#!/bin/bash
# This script CREATES a script that an administrator can easily http-fetch and run on each afflicted
# NCN node. For directions please consule the README.md paired with this file.
# THIS DOES NOT FIX THE ISSUE THE SUPPLIES THE FIX :) Similar to a Docker install, or any other
# web-script install requiring a pipe into sh.

# works for FQDN names (system-ncn-m001-pit) and vanilla pit.
[[ "$(hostname)" =~ 'pit$' ]] || (echo this must run on the liveCD && exit 2)

mkdir -p /var/www/ephemeral/workarounds/
cat << EOF > /var/www/ephemeral/workarounds/casminst-778.sh
#!/bin/sh
cloud-init clean
cloud-init init
cloud-init modules -m init
cloud-init modules -m config
cloud-init modules -m final

EOF
chmod +x /var/www/ephemeral/workarounds/casminst-778.sh
