# CUSTOMER: Overview

The procedures listed herein are intended to prepare a shasta-cfg repository to support installation of Shasta product streams. Thus, product stream installers will further direct expectations regarding how and where this material must be made avaialable. 

This README is focused on the creation of a customer deliverable tarball.

# Create Customer Distribution

1. Clone this repo and checkout your desired source branch

```bash
# cd ~/git
# git clone ssh://git@stash.us.cray.com:7999/shasta-cfg/stable.git
# cd shasta-cfg
# git checkout master
```

2. If applicable, edit the ```customizations.yaml``` file to match the customer environment (if known/optional)

3. Execute ```package/package.sh```, supplying a version reference

```bash
# ./package/package.sh 1.4.0
a shasta-cfg
a shasta-cfg/deploy
a shasta-cfg/meta
a shasta-cfg/utils
a shasta-cfg/docs
a shasta-cfg/README.md
a shasta-cfg/.version
a shasta-cfg/customizations.yaml
a shasta-cfg/docs/SEALED-SECRETS.md
a shasta-cfg/docs/CUSTOMER-DEPLOY.md
a shasta-cfg/docs/INTERNAL-DEPLOY.md
a shasta-cfg/utils/gencerts.sh
a shasta-cfg/utils/migrations
a shasta-cfg/utils/secrets-decrypt.sh
a shasta-cfg/utils/bin
a shasta-cfg/utils/secrets-encrypt.sh
a shasta-cfg/utils/migrate-customizations.sh
a shasta-cfg/utils/secrets-reencrypt.sh
a shasta-cfg/utils/migrate.sh
a shasta-cfg/utils/openssl.cnf
a shasta-cfg/utils/secrets-seed-customizations.sh
a shasta-cfg/utils/generators
a shasta-cfg/utils/generators/randstr
a shasta-cfg/utils/generators/rsa
a shasta-cfg/utils/generators/platform_ca
a shasta-cfg/utils/generators/zmq_curve
a shasta-cfg/utils/generators/static
a shasta-cfg/utils/generators/static_platform_ca
a shasta-cfg/utils/bin/linux
a shasta-cfg/utils/bin/darwin
a shasta-cfg/utils/bin/darwin/yq
a shasta-cfg/utils/bin/darwin/kubeseal
a shasta-cfg/utils/bin/linux/yq
a shasta-cfg/utils/bin/linux/kubeseal
a shasta-cfg/utils/migrations/06_unbound_airgap_forwarder
a shasta-cfg/utils/migrations/08_keycloak_sealed_secrets
a shasta-cfg/utils/migrations/01_sealed_secrets
a shasta-cfg/utils/migrations/07_istio_opa_issuers
a shasta-cfg/utils/migrations/02_ingressgatewayhmn
a shasta-cfg/utils/migrations/02_keycloak
a shasta-cfg/utils/migrations/05_sysmgmt-health
a shasta-cfg/utils/migrations/04_nexus
a shasta-cfg/utils/migrations/03_capsules
a shasta-cfg/meta/init.sh
a shasta-cfg/deploy/deploydecryptionkey.sh
Created package successfully!
PACKAGE_LOCATION=/Users/jeremyd/git/cray-bitbucket/shasta-cfg-stable/dist/shasta-cfg-1.4.0.tgz
```

> This process strips any previously encrypted sealed secrets from customizations (does not clear generator blocks), and adds a set of templated secrets that the customer must update and encrypt as part of the pre-install process. 