#!/usr/bin/python3
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
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


def get_bss_data(token, xname):
    """Return BSS data for the specified xname.
    @param token: string. Specify a BSS token.
    @param xname: string. Specify the xname of the current node.
    """
    # import pdb; pdb.set_trace()
    response = None
    bearer_token = "Bearer {}".format(token)
    endpoint = 'https://api-gw-service-nmn.local/apis/bss/boot/v1/bootparameters'
    data = {'name': xname}
    headers = {"Authorization": bearer_token}
    try:
        response = requests.get(endpoint, params=data, headers=headers, verify=False, timeout=5)
        # If BSS is down, check the local cloud-init cache
        if response.ok:
            # BSS response has a different structure than the local cache
            try:
                return response.json()[0]["cloud-init"]["user-data"]
            except KeyError:
                print("Please validate your BSS data.")
                sys.exit(2)
    except:
        print("BSS query failed.  Checking local cache...")
        user_data = get_cache_data(USER_DATA_FILE)
        return user_data


def get_cache_data(filepath):
    """Read the cache file and return the data.
    @param filepath: string. Specify a path to a file to read.
    """
    with open(filepath) as user_data_file:
        user_data = user_data_file.read()
    # user-data.txt is in yml, so convert it to json
    cache_data = yaml.safe_load(user_data)
    return cache_data


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
