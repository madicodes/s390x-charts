step "Backup & Restore"

# setup variables
export RANCHER_URL="https://${IP_MASTERS[0]}.nip.io"

# if ! kubectl get pv task-pv-volume 2>/dev/null; then
info 'create persistent volume'
nodes_run 'mkdir -p /mnt/data'
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: task-pv-volume
  labels:
    type: local
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
EOF
wait_pods
kubectl wait --for=jsonpath='{.status.phase}'=Available pv/task-pv-volume || kubectl wait --for=jsonpath='{.status.phase}'=Bound pv/task-pv-volume

info 'install chart'
python3 "$TESTDIR"/backup_restore.py --action=install
# retry: Error from server (NotFound): deployments.apps "rancher-backup" not found
retry 'kubectl -n cattle-resources-system rollout status deploy/rancher-backup' 3 15

info 'create backup'
python3 "$TESTDIR"/backup_restore.py --action=backup


: