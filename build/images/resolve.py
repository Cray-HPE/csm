#!/usr/bin/env python3

import argparse
import sys

from docker_image.reference import Reference

INVALID_DOMAINS = set([
    'dtr.dev.cray.com',
])

NON_MIRRORED_DOMAINS = set([
    'artifactory.algol60.net',
    'arti.dev.cray.com',
])

parser = argparse.ArgumentParser(description="Resolves image repositories to canonical forms")
parser.add_argument('-m', '--mirrors', action='store_true', default=False, help="Resolve images as artifactory.algol60.net mirrors")
parser.add_argument('image', metavar='IMAGE', nargs='+', help="image reference")
args = parser.parse_args()

for image in args.image:
    ref = Reference.parse_normalized_named(image)
    domain = ref.domain()
    ref = ref.string()

    if domain in INVALID_DOMAINS:
        print(f'error: invalid domain: {ref}', file=sys.stderr)
        sys.exit(1)

    if not args.mirrors:
        print(ref)
    elif domain in NON_MIRRORED_DOMAINS:
        print(ref)
    else:
        print(f'artifactory.algol60.net/{ref}')
