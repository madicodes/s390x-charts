#!/usr/bin/env python3

"""
Test for deploying, triggering and getting results from rancher-cis-benchmark scan.
CIS test is using "rke2-cis-1.6-profile-permissive" profile scan on local RKE2 cluster.
Rancher has to be deployed first. It's using custom images built by thehejik@suse.com on s390x.
"""

import time
from time import sleep
import requests
import os
import urllib3
from http.client import HTTPConnection

# Set the debuglevel value to 1 for having http debug info on stdout
HTTPConnection.debuglevel = 0
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# You may enter your debug cluster url into ""
url = os.getenv("RANCHER_URL") or ""
# Remove trailing slash from url if present
url = url.rstrip("/")
user = "admin"
password = "sa"


def create_admin_token(url, user, password):
    headers = {
        "Accept": "application/json",
        "Connection": "keep-alive",
        "Content-Type": "application/json",
    }

    with requests.Session() as s:
        s.post(
            url + "/v3-public/localProviders/local?action=login",
            json={
                "description": "UI session",
                "responseType": "cookie",
                "username": user,
                "password": password,
            },
            headers=headers,
            verify=False,
        )
        token = s.post(
            url + "/v3/tokens",
            json={
                "type": "token",
                "metadata": {},
                "description": "token-admin-ci",
                "ttl": 0,
            },
            verify=False,
        )
        s.close
    print("Successfully logged into rancher at " + url)
    return token.json()["token"]


def poll(session_self, url, path, token):
    notYetDefined = ""


def install_cis_on_local(url, token):
    payload = '{"charts":[{"chartName":"rancher-cis-benchmark-crd","version":"2.0.3","releaseName":"rancher-cis-benchmark-crd","projectId":null,"values":{"global":{"kubectl":{"repository":"thehejik/kubectl","tag":"latest"},"cattle":{"clusterId":"local","clusterName":"local","systemDefaultRegistry":"","url":"","rkePathPrefix":"","rkeWindowsPathPrefix":""},"systemDefaultRegistry":""}},"annotations":{"catalog.cattle.io/ui-source-repo-type":"cluster","catalog.cattle.io/ui-source-repo":"rancher-charts"}},{"chartName":"rancher-cis-benchmark","version":"2.0.3","releaseName":"rancher-cis-benchmark","annotations":{"catalog.cattle.io/ui-source-repo-type":"cluster","catalog.cattle.io/ui-source-repo":"rancher-charts"},"values":{"global":{"kubectl":{"repository":"thehejik/kubectl","tag":"latest"},"cattle":{"clusterId":"local","clusterName":"local","systemDefaultRegistry":"","url":"","rkePathPrefix":"","rkeWindowsPathPrefix":""},"systemDefaultRegistry":""},"image":{"cisoperator":{"repository":"thehejik/cis-operator","tag":"v1.0.7-s390x"},"securityScan":{"repository":"thehejik/security-scan","tag":"v0.2.6-s390x"},"sonobuoy":{"repository":"sonobuoy/sonobuoy","tag":"v0.55.1"}}}}],"noHooks":false,"timeout":"600s","wait":true,"namespace":"cis-operator-system","projectId":null,"disableOpenAPIValidation":false,"skipCRDs":false}'

    with requests.Session() as s:
        response = s.post(
            url + "/v1/catalog.cattle.io.clusterrepos/rancher-charts?action=install",
            headers={
                "Accept": "application/json",
                "Connection": "keep-alive",
                "Content-Type": "application/json",
                "Authorization": "Bearer " + token,
            },
            data=payload,
            verify=False,
        )
        # Simple polling with timeout for rancher-cis-benchmark app/chart deployment
        # TODO Find a better way how to handle exit codes when a while condition is met
        start_timeout = time.time()
        timeout = 240
        returnCode = 127
        # dump progressbar
        print("CIS Scan installation in progress:", end=" ", flush=True)
        while time.time() < start_timeout + timeout:
            r = s.get(
                url
                + "/v1/catalog.cattle.io.apps/cis-operator-system/rancher-cis-benchmark",
                headers={
                    "Accept": "application/json",
                    "Connection": "keep-alive",
                    "Content-Type": "application/json",
                    "Authorization": "Bearer " + token,
                },
                verify=False,
            )
            sleep(2)  # Don't do DoS

            # print(r.status_code)

            if r.status_code == 200:
                # dump progressbar
                print("done!", flush=True)
                # k8s resources may not be ready yet, should we wait longer?
                sleep(5)
                returnCode = 0
                break
            else:
                # dump progressbar
                print("*", end="", flush=True)
        s.close
        if returnCode != 0:
            exit(returnCode)


def cis_test(url, token):
    payload = '{"type":"cis.cattle.io.clusterscan","metadata":{"generateName":"scan-"},"spec":{"scanProfileName":"rke2-cis-1.6-profile-permissive","scoreWarning":"pass"}}'

    with requests.Session() as s:
        o = s.post(
            url + "/v1/cis.cattle.io.clusterscans",
            headers={
                "Accept": "application/json",
                "Connection": "keep-alive",
                "Content-Type": "application/json",
                "Authorization": "Bearer " + token,
            },
            data=payload,
            verify=False,
        )
        scanItem = o.json()["metadata"]["fields"][0]
        print("CIS Scan triggered as: " + scanItem + " " + str(o.status_code))

        # Simple polling with timeout for getting CIS scan results
        start_timeout = time.time()
        timeout = 240
        returnCode = 129
        # dump progressbar
        print("CIS Scan " + scanItem + " in progress:", end=" ", flush=True)
        while time.time() < start_timeout + timeout:
            r = s.get(
                url + "/apis/cis.cattle.io/v1/clusterscans/" + scanItem,
                headers={
                    "Accept": "application/json",
                    "Connection": "keep-alive",
                    "Content-Type": "application/json",
                    "Authorization": "Bearer " + token,
                },
                verify=False,
            )
            sleep(2)  # Don't do DoS

            # print(r.status_code)
            # print(r.json())
            # print(r.json()["status"]["conditions"])

            # Sometimes the ["status"] node/list is not present yet so we have to try again
            if "status" not in r.json():
                # print("Status not present yet in response: " + str(r.json()))
                continue

            conditions = r.json()["status"]["conditions"]

            for item in range(len(conditions)):
                # print(conditions[item])
                if conditions[item]["type"] == "Complete":
                    returnCode = 0
                    # dump progressbar
                    print("done!", flush=True)
                    break
            else:
                # dump progressbar
                print("*", end="", flush=True)
                continue
            print("CIS Scan results: " + str(r.json()["status"]["summary"]))
            # Check amount of failed tests
            if r.json()["status"]["summary"].get("fail") > 0:
                print("Failed tests! Please investigate in Browser " + url)
                returnCode = 122
            break
        s.close
        if returnCode != 0:
            exit(returnCode)


token = create_admin_token(url, user, password)
install_cis_on_local(url, token)
cis_test(url, token)
