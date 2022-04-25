#!/usr/bin/env python3

import os
import argparse
import requests
from time import sleep
from urllib3.exceptions import InsecureRequestWarning
from urllib import request

# Suppress only the single warning from urllib3 needed
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

# For request.urlretrieve insecure https
import ssl
ssl._create_default_https_context = ssl._create_unverified_context

# from http.client import HTTPConnection
# HTTPConnection.debuglevel = 1

URL = os.getenv("RANCHER_URL") or "" # https://10.161.129.12.nip.io

# Create session and login
def login():
	global s

	# === Setup session
	s = requests.Session()
	s.verify = False
	s.headers = {"Accept": "application/json", "Content-Type": "application/json"}

	# === Login
	loginData = {'username' : 'admin', 'password' :  'sa', 'responseType' : 'cookie'}
	r = s.post(f'{URL}/v3-public/localProviders/local?action=login', json = loginData)

# select local cluster and go to Storage/Secrets, create Opaque secret with keys accessKey and secretKey and their values for used AWS account (s3), name the secret aws-credentials
# Install Rancher Backups app on local cluster from Apps & Marketplace

# Install Rancher Backups
def action_install(mode='pv'):
	ver = '2.1.1+up2.1.1-rc1'
	if (mode == 'pv'):
		payload = '{"charts":[{"chartName":"rancher-backup-crd","version":"'+ver+'","releaseName":"rancher-backup-crd","annotations":{"catalog.cattle.io/ui-source-repo-type":"cluster","catalog.cattle.io/ui-source-repo":"rancher-charts"}},{"chartName":"rancher-backup","version":"'+ver+'","releaseName":"rancher-backup","annotations":{"catalog.cattle.io/ui-source-repo-type":"cluster","catalog.cattle.io/ui-source-repo":"rancher-charts"},"values":{"persistence":{"enabled":true,"volumeName":"task-pv-volume"}}}],"noHooks":false,"timeout":"600s","wait":true,"namespace":"cattle-resources-system","disableOpenAPIValidation":false,"skipCRDs":false}'
	elif (mode == 'aws'):
		payload = 'TODO'
	r = s.post(f'{URL}/v1/catalog.cattle.io.clusterrepos/rancher-charts?action=install', data = payload)

# Perform backup
def action_backup():
	payload = '{"type":"resources.cattle.io.backup","metadata":{"name":"thebackup"},"spec":{"retentionCount":10,"resourceSetName":"rancher-resource-set"}}'
	r = s.post(f'{URL}/v1/resources.cattle.io.backups', data=payload)

# Perform restore
def action_restore():
	# find backup
	r = s.get(f'{URL}/v1/resources.cattle.io.backups/thebackup')
	backupFile = r.json()["status"]["filename"]

	# restore
	payload = '{"type":"resources.cattle.io.restore","metadata":{"generateName":"restore-"},"spec":{"prune":true,"deleteTimeoutSeconds":10,"backupFilename":"' + backupFile + '"}}'
	r = s.post(f'{URL}/v1/resources.cattle.io.restores', data=payload)


""" Main entry point of the app """
def main(args):
	login()
	if args.action == 'install': action_install()
	elif args.action == 'backup': action_backup()
	else: exit(2)


if __name__ == "__main__":
	# Input parameters
	parser = argparse.ArgumentParser()
	parser.add_argument("-a", "--action", help="Rancher action to execute [install|backup|restore]", required=True)
	args = parser.parse_args()
	main(args)
