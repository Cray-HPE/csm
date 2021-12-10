#!/usr/bin/env python3

import argparse
from docker_image.reference import Reference

INVALID_DOMAINS = set([
    'dtr.dev.cray.com',
])

NON_MIRRORED_DOMAINS = set([
    'artifactory.algol60.net',
    'arti.dev.cray.com',
])

parser = argparse.ArgumentParser(description="Resolve image repositories to artifactory.algol60.net mirrors")
parser.add_argument('image', metavar='IMAGE', nargs='+', help="image reference")
args = parser.parse_args()

for image in args.image:
    ref = Reference.parse_normalized_named(image)
    domain = ref.domain()
    ref = ref.string()

    if domain in INVALID_DOMAINS:
        parser.error(f'invalid domain: {image}')

    if domain in NON_MIRRORED_DOMAINS:
        print(ref)
    else:
        print(f'artifactory.algol60.net/{ref}')
