# Structure


    # The customizations file for site specific info
    customizations.yaml
    # Scripts to be used by product stream installers during deploy
    deploy
      ├──deploydecryptionkey.sh
    # Meta dir to initialize a clone of this repo (minus this dir)
    meta
      ├──init.sh
    # Utilities that are useful day to day outside install/upgrade procedures
    # these script SHOULD NEVER be called by any scripts in the ./deploy directory
    utils
      ├──bin # Relatively static binaries we assume users don't have
      ├──gencerts.sh
      ├──migrate-customizations.sh
      ├──openssl.cnf
      ├──sync.sh
      ├──secrets-gen-random.sh
      ├──secrets-reencrypt.sh
      ├──secrets-seed-customizations.sh
      ├──secrets-encrypt.sh
      └──test-generate.sh
    # The certs used for the system. These should ideally be saved in an offline location 
    # while not being used for install.
    certs
      ├──sealed_secrets.key
      └──sealed_secrets.crt

# Customizations.yaml

See [Customizations Documentation](docs/CUSTOMIZATIONS.md).

# Sealed Secrets

See [Sealed Secrets Documentation](docs/SEALED-SECRETS.md).

# Deployment

[Documentation](docs/INTERNAL-DEPLOY.md) for deployment to HPE Internal systems.

[Documentation](docs/CUSTOMER-DEPLOY.md) for deployment to customers (base process).

# How do I test my changes?

See product stream (e.g., CSM) documentation re: how to test an install.
