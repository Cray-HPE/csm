#
# MIT License
#
# (C) Copyright 2025 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

import argparse
import sys
import yaml

from packaging.version import Version

def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate K8s 1.24-specific versions of CSM Loftsman manifests based on two separate input manifests."
    )
    parser.add_argument("file1")
    parser.add_argument("file2")

    return parser.parse_args()

def main():
    args = parse_args()

    f1yaml = None
    f2yaml = None
    with open(args.file1, "r") as f1, open(args.file2, "r") as f2:
        f1yaml = yaml.safe_load(f1)
        f2yaml = yaml.safe_load(f2)

    charts1 = f1yaml.get("spec", {}).get("charts")
    charts2 = f2yaml.get("spec", {}).get("charts")

    versions1 = {}
    for chart in charts1:
        versions1.update({ chart.get("name"): chart })

    versions2 = {}
    for chart in charts2:
        versions2.update({ chart.get("name"): chart.get("version") })

    # We take the larger of the two version strings.
    versions_final = {}
    for chart in charts1:
        chart_name = chart.get("name")

        # The packaging library supports PEP 440 version strings, which are not
        # 100% compatible with semver. This shouldn't matter for us, though,
        # because we only use basic semver versions for our charts, which are
        # PEP 440-compatible. See:
        # https://packaging.python.org/en/latest/specifications/version-specifiers/#semantic-versioning
        #
        # >The "Major.Minor.Patch" (described in this specification as
        # >"major.minor.micro") aspects of semantic versioning (clauses 1-8 in
        # >the 2.0.0 specification) are fully compatible with the version scheme
        # >defined in this specification, and abiding by these aspects is
        # >encouraged.
        try:
            v = chart.get("version")
            v1 = Version(v)
        except TypeError as e:
            print(f"Bad version for {chart_name} in {args.file1}: {e}, got: {v}. Skipping.", file=sys.stderr)
            continue

        try:
            v = versions2.get(chart_name)
            v2 = Version(v)
        except TypeError as e:
            print(f"Bad version for {chart_name} in {args.file2}: {e}, got: {v}. Skipping.", file=sys.stderr)
            continue

        if v2 > v1:
            chart["version"] = str(v2)

    print(yaml.dump(f1yaml, sort_keys=False))

if __name__ == "__main__":
    main()
