#
# MIT License
#
# (C) Copyright 2022-2024 Hewlett Packard Enterprise Development LP
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
from collections import defaultdict
import csv
import fileinput
import json
import logging
from pathlib import Path
import statistics

ROOTDIR = Path(__file__).resolve().parent.parent

logger = logging.getLogger()


def main(args=None):
    from argparse import ArgumentParser
    import pandas as pd
    import sys

    parser = ArgumentParser('Aggregate Snyk results into Excel spreadsheet')
    parser.add_argument('-o', '--output', metavar='XLSX', default='-', help='Output Excel spreadsheet')
    parser.add_argument('--sheet-name', metavar='NAME', default="Snyk results", help="Name of sheet")
    parser.add_argument('--helm-chart-map', 
                        metavar='CHARTMAP', 
                        default=None, 
                        help="CSV containing Loftsman manifest name, Helm chart, and image" )
    parser.add_argument('files', metavar='FILE', nargs='*', help='files to read, if empty, stdin is used')
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)

    charts = None
    if args.helm_chart_map is not None:
        with open(args.helm_chart_map, 'r') as csvfile:
            charts = list(csv.DictReader(csvfile,delimiter=","))

    df = pd.DataFrame()
    for line in fileinput.input(files=args.files):
        logger.debug(f"Processing {line.strip()}")
        with open(line.strip()) as f:
            results = json.load(f)
            parse_image_metadata(results)
            add_chart_info(results, charts)
            aggregate_vulnerabilities(results)
            aggregate_licenses_policy(results)
            df = pd.concat([df, pd.json_normalize(results)], ignore_index=True)
    if args.output == '-':
        args.output = sys.stdout.buffer
    create_spreadsheet(df, filename=args.output, sheet_name=args.sheet_name)


def parse_image_metadata(results):
    """Parse container image metadata from Snyk results."""
    # Parse image and digest
    results['image'] = results['docker']['image']['logicalRef']
    results['digest'] = results['docker']['image']['physicalRef'].split('@', 1)[-1]

    # Add URL to detailed results
    try:
        results['url'] = f"https://app.snyk.io/org/{results['org']}/project/{results['projectId']}/"
    except KeyError:
        # Some results are missing projectId?
        results['url'] = None

def add_chart_info(results, charts):

    if charts is None:
        results['charts'] = None
    else:
        found = set()
        for r in charts:
            if r['image'] == results['image']:
                found.add(r['manifest'] + "->" + r["chart"])
        found = ' '.join(found)
        results['charts'] = found

def aggregate_vulnerabilities(results):
    """Aggregates vulnerability metrics (e.g., severity, CVSS score, number
    fixable) and sets other image metadata.
    """

    # Aggregate vulnerabilities
    vuln = results.pop('vulnerabilities', [])

    cvssScores = list(filter(None, (v.get('cvssScore') for v in vuln)))
    if cvssScores:
        results['cvssScore'] = {
            'max': max(cvssScores),
            'min': min(cvssScores),
            'avg': statistics.mean(cvssScores),
        }

    severity = defaultdict(set)
    fixable = defaultdict(int)
    auto_patchable = defaultdict(int)
    results['fixableCount'] = 0

    for v in vuln:
        # The unique key for severity counts consists of all identifiers
        key = [v['id']]
        for identifiers in v['identifiers'].values():
            key.extend(identifiers)
        key = ' '.join(sorted(map(str, key)))
        severity[v['severity']].add(key)
        # Map/count fixable issues
        # https://snyk.docs.apiary.io/#introduction/api-url
        if v.get('isUpgradable', False) or v.get('nearestFixedInVersion', None) is not None:
            fixable[key] += 1
        if v.get('isPatchable', False):
            auto_patchable[key] += 1

    # Add keys in the event the scan subset didn't 
    # have a population of them (expected in report)
    for s in ('critical','high','medium','low'):
        for c in ('severity','fixableCount'):
                k = c + '.' + s
                if k not in results.keys():
                    results[k] = 0

    results['severity'] = {k: len(v) for k, v in severity.items()}
    results['identifiers'] = '\n'.join('\n'.join(k for k in keys) for keys in severity.values())
    results['identifiers'] = ' '.join(sorted(set(results['identifiers'].split())))

    # Add fixable count overall and by severity
    for k in severity.keys():
            results['fixableCount.' + k] = len([f for f in fixable.keys() if f in severity[k]])
            results['fixableCount'] += results['fixableCount.' + k]
    results['autopatchable'] = len(auto_patchable)
    #print(json.dumps(results,indent=3,sort_keys=True))

    # Accumulate results
    logger.info(f"Snyk found {results['uniqueCount']} issues "
                f"with {results['path']}, "
                f"vulnerabilities: {sum(results['severity'].values())} "
                f"total {results['severity']}, fixable: {results['fixableCount']}")


def aggregate_licenses_policy(results):
    # TODO Aggregate licenses policy
    licenses = results.pop('licensesPolicy', [])

def create_spreadsheet(df, filename='snyk-results.xlsx', sheet_name='Snyk results'):
    columns = [ 'image', 
                'digest', 
                'charts',
                'uniqueCount', 
                'severity.critical', 
                'severity.high', 
                'severity.medium', 
                'severity.low', 
                'fixableCount',
                'fixableCount.critical',
                'fixableCount.high',
                'fixableCount.medium',
                'fixableCount.low',
                'cvssScore.max', 
                'cvssScore.min', 
                'cvssScore.avg', 
                'url', 
                'identifiers' ]
    columns.extend(sorted([c for c in df.columns if c not in columns]))
    df.to_excel(filename, sheet_name=sheet_name, index=False, columns=columns)


if __name__ == '__main__':
    main()
