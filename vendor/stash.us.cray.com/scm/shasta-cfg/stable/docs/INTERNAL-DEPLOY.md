# INTERNAL: Overview

The procedures listed herein are intended to prepare a shasta-cfg repository to support installation of Shasta product streams. Thus, product stream installers will further direct expectations regarding how and where this material must be made avaialable. 

This README is focused on HPE Internal Development Systems.

# Setup for New System

1. Clone this repo and checkout your desired source branch

```bash
# cd ~/git
# git clone ssh://git@stash.us.cray.com:7999/shasta-cfg/stable.git
# git checkout master
```

1. Create a new git repository for your system at ```https://stash.us.cray.com/projects/SHASTA-CFG``` (e.g., new-system)

2. Run ```meta/init.sh``` against a local (new) working directory for your configuration.

```bash
# SYSTEM_NAME="bard"
# mkdir -p /tmp/shasta-cfg/${SYSTEM_NAME}
# cd /tmp/shasta-cfg/${SYSTEM_NAME}
# ~/git/meta/init.sh .
```

3. Edit the ```customizations.yaml``` file and address any FIXMEs.

4. Add/commit your changes and push your branch (unless only testing changes locally)

```bash
# git add -A
# git commit -m "Initial commit"
# git remote add origin ssh://git@stash.us.cray.com:7999/shasta-cfg/${SYSTEM_NAME}
# git push -u origin master
```

5. Ask someone in CASM CLOUD Team to configure a Jenskins build job for your repo (#casm-cloud)

# Updating Existing System

1. Clone the repo for your target system (or alternatively refresh your clone, etc)

```bash
# SYSTEM_NAME="bard"
# cd ~/git
# git clone ssh://git@stash.us.cray.com:7999/shasta-cfg/${SYSTEM_NAME}
# git checkout master
# git checkout -b your-branch-for-mods
```

2. Update the ```.syncing``` file to set the branch and repository you want to sync against, for stable. 

```
SYNC_TAG_OR_BRANCH=master
SYNC_REPO=ssh://git@stash.us.cray.com:7999/shasta-cfg/stable.git
```

3. Execute the ```utils/sync.sh``` script from the root of your system repo

```bash
# cd ~/git/${SYSTEM_NAME}
# ./utils/sync.sh
```

> The ```utils/sync.sh``` is intended to be re-reunnable/re-entrant. So you can run it at any time to perform a sync.

4. Assuming no errors on sync, view the changes to ```customizations.yaml```, address any FIXMEs, review network/... settings to verify they are appropriate for your system, add and then commit the resulting changes. Note that you will see many changes in customizations re: sealed secrets (e.g., diff lines referencing changes in the context of ```encryptedData``` fields) -- this is normal as secrets are added (canonically via generators) and re-encrypted. Unless you have customized other aspects of your shasta-cfg repo (e.g., things in ```utils```), add/commit your changes. 

5. Push your branch, create a PR, etc once ready to publish changes.

