# Copyright 2021 Hewlett Packard Enterprise Development LP

from collections import defaultdict
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
    parser.add_argument('files', metavar='FILE', nargs='*', help='files to read, if empty, stdin is used')
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)

    df = pd.DataFrame()
    for line in fileinput.input(files=args.files):
        logger.debug(f"Processing {line.strip()}")
        with open(line.strip()) as f:
            results = json.load(f)
        parse_image_metadata(results)
        aggregate_vulnerabilities(results)
        aggregate_licenses_policy(results)
        df = df.append(pd.json_normalize(results), ignore_index=True)
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
        pass

    return results

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
    for v in vuln:
        # The unique key for severity counts consists of all identifiers
        key = [v['id']]
        for identifiers in v['identifiers'].values():
            key.extend(identifiers)
        key = ' '.join(sorted(map(str, key)))
        severity[v['severity']].add(key)
        # Count fixables
        is_fixable = v.get('isUpgradable', False) or v.get('isPatchable', False) or v.get('nearestFixedInVersion', None)
        if is_fixable:
            fixable[key] += 1
    results['severity'] = {k: len(v) for k, v in severity.items()}
    results['identifiers'] = '\n'.join('\n'.join(k for k in keys) for keys in severity.values())
    results['identifiers'] = ' '.join(sorted(set(results['identifiers'].split())))
    results['fixableCount'] = len(fixable)

    # Accumulate results
    logger.info(f"Snyk found {results['uniqueCount']} issues with {results['path']}, vulnerabilities: {sum(results['severity'].values())} total {results['severity']}, fixable: {results['fixableCount']}")
    return results


def aggregate_licenses_policy(results):
    # TODO Aggregate licenses policy
    licenses = results.pop('licensesPolicy', [])
    return results


def create_spreadsheet(df, filename='snyk-results.xlsx', sheet_name='Snyk results'):
    columns = ['image', 'digest', 'uniqueCount', 'severity.critical', 'severity.high', 'severity.medium', 'severity.low', 'cvssScore.max', 'cvssScore.min', 'cvssScore.avg', 'url', 'fixableCount', 'identifiers']
    columns.extend([c for c in df.columns if c not in columns])
    df.to_excel(filename, sheet_name=sheet_name, index=False, columns=columns)


if __name__ == '__main__':
    main()
