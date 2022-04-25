# Recommended way to deploy and test longhorn with -m coretest
# ./varke run -n 1:2 -t longhorn -e INTEGRATION=1 -e SUFFIX=longhorn-btrfs -e RKE2_VERSION="v1.21.9+rke2r1" -k
step "Deploy longhorn"

info 'install open-iscsi'
nodes_run 'zypper -n in open-iscsi nfs-client'
nodes_run 'systemctl enable --now iscsid'

info 'install longhorn'
warn 'use raulcabello repo'
kubectl apply -f https://raw.githubusercontent.com/raulcabello/longhornz/main/longhorn.yaml

info 'Expose longhorn via Ingress'
kubectl create ingress -n longhorn-system longhorn --rule="longhorn.${IP_MASTERS[0]}.nip.io/*=longhorn-frontend:http"
kubectl annotate ingress longhorn -n longhorn-system nginx.ingress.kubernetes.io/proxy-body-size=10000m

# Deploy snapshot controller and crds needed for test_csi_snapshotter.py
# More info at https://longhorn.io/docs/1.2.3/snapshots-and-backups/csi-snapshot-support/enable-csi-snapshot-support/
# git clone https://github.com/kubernetes-csi/external-snapshotter.git and switch to release-4.0
info 'Deploying csi-external-snapshotter'
kubectl create -f "$LIBDIR"/sub_snapshotter/client/config/crd
kubectl create -f "$LIBDIR"/sub_snapshotter/deploy/kubernetes/snapshot-controller
wait_pods -n default --all

# NOTE this is likely not needed but stated in longhorn docu
#kind: VolumeSnapshotClass
#apiVersion: snapshot.storage.k8s.io/v1beta1
#metadata:
#  name: longhorn
#driver: driver.longhorn.io
#deletionPolicy: Delete

info "Open http://longhorn.${IP_MASTERS[0]}.nip.io/"

if [ -v INTEGRATION ]; then

    step 'Deploying Longhorn integration tests'
    kubectl create -Rf "$LIBDIR"/sub_longhorn/manager/integration/deploy/backupstores/
    wait_pods -n default --all

    kubectl create -f "$LIBDIR"/sub_longhorn/manager/integration/deploy/test.yaml
    wait_pods -llonghorn-test=test-job

    info 'Run "kubectl logs -f longhorn-test" for results'
fi
