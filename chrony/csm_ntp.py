#!/usr/bin/python3
#
# MIT License
#
# (C) Copyright 2022, 2024 Hewlett Packard Enterprise Development LP
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
import glob
import os
import re
import subprocess
import sys

import requests
import time
import urllib3
import yaml

from jinja2 import Environment, FileSystemLoader

# Ignore warnings for local certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def create_chrony_config(allow, confpath, peers, pools, servers, local_hostname):
    """Create a chrony config file with the specified parameters.
    """
    file_loader = FileSystemLoader('/srv/cray/scripts/common/chrony/templates')
    env = Environment(loader=file_loader)
    env.trim_blocks = True
    env.lstrip_blocks = True
    env.rstrip_blocks = True
    template = env.get_template("cray.conf.j2")

    output = template.render(
        allow=allow,
        local_hostname=local_hostname,
        peers=peers,
        pools=pools,
        servers=servers)

    with open(confpath, "w") as conf_file:
        conf_file.write(output)


def get_token():
    """Returns a BSS token.
    """
    # Valid data comes from BSS, so we need to ensure the token is set
    # in order to query it
    try:
        return os.environ["TOKEN"]
    except KeyError:
        print("You must set BSS TOKEN environment variable")
        sys.exit(2)


def get_xname():
    """Returns xname for the current node.
    """
    # BSS uses the xname to identify the node
    with open('/etc/cray/xname') as xname_file:
        xname = xname_file.read()
    return xname.strip()


def query_bss(token, xname):
    """Query BSS for specified xname, with limited retries.

    Call to BSS will be automatically re-attempted every 15 seconds for up to 5 minutes before giving up,
    for cases where the request itself fails (possibly the result of a transient name resolution error) or
    the request gets a response with a 5XX status code (possibly indicating a transient problem with the service).
    """
    time_limit_seconds = 300
    wait_between_attempts_seconds = 15
    bearer_token = "Bearer {}".format(token)
    endpoint = 'https://api-gw-service-nmn.local/apis/bss/boot/v1/bootparameters'
    data = {'name': xname}
    headers = {"Authorization": bearer_token}

    first_attempt=True

    # After this time, we will no longer sleep wait_between_attempts_seconds seconds and retry
    stop_time = time.time() + time_limit_seconds - wait_between_attempts_seconds

    while True:
        if not first_attempt:
            print(f"Waiting {wait_between_attempts_seconds} seconds and retrying BSS request")
            time.sleep(wait_between_attempts_seconds)
        first_attempt = False
        try:
            # rely on BSS data only and ignore the cloud-init cache
            response = requests.get(endpoint, params=data, headers=headers, verify=False, timeout=5)
        except Exception as e:
            print(f"Error making BSS query to {endpoint}. {type(e).__name__}: {e}")
            if time.time() > stop_time:
                sys.exit(2)
            continue
        if response.ok:
            try:
                return response.json()
            except Exception as e:
                print(f"Response from query to {endpoint} indicates success but error decoding its body. {type(e).__name__}: {e}")
                sys.exit(2)
        print(f"BSS query to {endpoint} was not successful. {response.status_code} {response.reason}; {response.text}")
        if (time.time() > stop_time) or (response.status_code < 500) or (response.status_code > 599):
            sys.exit(2)


def get_bss_data(token, xname):
    """Return BSS data for the specified xname.
    @param token: string. Specify a BSS token.
    @param xname: string. Specify the xname of the current node.
    """
    # import pdb; pdb.set_trace()

    bearer_token = "Bearer {}".format(token)
    endpoint = 'https://api-gw-service-nmn.local/apis/bss/boot/v1/bootparameters'
    data = {'name': xname}
    headers = {"Authorization": bearer_token}

    response_json = query_bss(token, xname)
    try:
        return response_json[0]["cloud-init"]["user-data"]
    except Exception as e:
        print(f"BSS query to {endpoint} did not return the expected data. {type(e).__name__}: {e}")
        print("See 'operations/node_management/Configure_NTP_on_NCNs.md#fix-bss-metadata' in the CSM release documentation for steps on validating BSS data.")
        sys.exit(2)


def remove_dist_files(confdir=None):
    """Remove *.dist files from the specified path.
    @param confdir: string. Specify a path to a folder to check for *.dist files.
    """
    if os.path.exists(confdir):
        # find the *.dist files in the given folder
        dist_files = glob.glob(os.path.join(confdir, "*.dist"))
        if dist_files is None:
            print("No *.dist files found to remove")
        for file in dist_files:
            print("Problematic config found: {}".format(file))
            # remove each .dist file
            os.remove(file)


def remove_pool_conf(confdir=None):
    """Delete the pool.conf config, which has unreachable servers in airgap environments.
    @param confdir: string. Specify a path to a folder to check for a pool.conf file.
    """
    pool_conf = os.path.join(confdir, "pool.conf")
    if os.path.exists(pool_conf):
        print("Problematic config found: {}".format(pool_conf))
        os.remove(pool_conf)


def comment_default_pool(confpath=None):
    """Comments out the default pool in the chrony configuration file.
    @param confpath: string. Specify a path to a .conf file
    """
    if os.path.exists(confpath):
        # open the file for reading
        with open(confpath, "r") as config:
            chrony_conf = config.read()
            # only write the file if it is not commented out already
            # add a comment for lines beginning with '! pool'
            nopool = re.sub(
                r'^! pool',
                '# ! pool',
                chrony_conf,
                flags=re.MULTILINE
            )
        with open(confpath, "w") as chrony_conf:
            chrony_conf.write(nopool)


def restart_chrony():
    """Restarts the Chrony service.
    """
    try:
        subprocess.check_output("systemctl restart chronyd", shell=True)
    except subprocess.CalledProcessError as e:
        print("Error restarting Chrony service")


if __name__ == "__main__":
    USER_DATA_FILE = '/var/lib/cloud/instance/user-data.txt'
    DEFAULT_CONF = '/etc/chrony.conf'
    CONF_DIR = '/etc/chrony.d'

    token = get_token()
    xname = get_xname()
    bss_data = get_bss_data(token, xname)
    # get all the ntp keys needed to render the template
    try:
        allow = bss_data["ntp"]["allow"]
        confpath = bss_data["ntp"]["config"]["confpath"]
        template = bss_data["ntp"]["config"]["template"]
        enabled = bss_data["ntp"]["enabled"]
        ntp_client = bss_data["ntp"]["ntp_client"]
        peers = bss_data["ntp"]["peers"]
        # no pools may be defined, so set it to an empty list
        pools = bss_data['ntp'].get('pools', '')
        servers = bss_data["ntp"]["servers"]
        local_hostname = bss_data["local_hostname"]

    except KeyError:
        print("Please validate your BSS data.")
        sys.exit(2)

    create_chrony_config(
        allow=allow,
        confpath=confpath,
        peers=peers,
        pools=pools,
        servers=servers,
        local_hostname=local_hostname)

    print("Chrony configuration created")
    remove_dist_files(confdir=CONF_DIR)
    remove_pool_conf(confdir=CONF_DIR)
    comment_default_pool(confpath=DEFAULT_CONF)
    restart_chrony()
    print("Restarted chronyd")
