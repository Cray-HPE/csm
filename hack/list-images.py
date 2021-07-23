#!/usr/bin/env python3

import inspect

filename = inspect.getframeinfo(inspect.currentframe()).filename

def images(index):
    for k, v in index.items():
        if 'images' not in v:
            continue
        for name, tags in v['images'].items():
            for t in tags:
                yield f'{k}/{name}:{t}'


def main():
    import argparse
    import inspect
    from pathlib import Path
    import yaml

    default_index = Path(inspect.getframeinfo(inspect.currentframe()).filename).parent / '../docker/index.yaml'

    parser = argparse.ArgumentParser()
    parser.add_argument('index', nargs='?', type=argparse.FileType('r'), default=None)
    args = parser.parse_args()

    if args.index is None:
        args.index = open(default_index.resolve())

    for image in images(yaml.safe_load(args.index)):
        print(image)


if __name__ == '__main__':
    main()

