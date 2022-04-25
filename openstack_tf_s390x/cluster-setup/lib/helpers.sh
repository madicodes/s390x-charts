# Helper functions used by tests

is_caasp() { which skuba 2>/dev/null || return $?; }

# Safe version of vaiting for pods
# Handles kube-api disconnects during upgrade
wait_all_pods() {
    local i
    for i in {1..90}; do
        output=$(kubectl get pods --no-headers -n kube-system -o wide | grep -vw Completed || echo 'Fail')
        grep -vE '([0-9]+)/\1 +Running' <<< $output || break
        [ $i -ne 90 ] && sleep 30 || { error "Godot: pods not running"; false; }
    done

    is_caasp && wait_cilium

    # Wait for metrics api if present, more info https://github.com/helm/helm/issues/6361#issuecomment-550503455
    if kubectl get deploy -n kube-system metrics-server; then
        kubectl wait -n kube-system --for=condition=Available --timeout=10m apiservices/v1beta1.metrics.k8s.io
    fi
}

# Safe version of vaiting for nodes
# Handles kube-api disconnects during upgrade
wait_all_nodes() {
    local i
    for i in {1..30}; do
        output=$(kubectl get nodes --no-headers || echo 'Fail')
        grep -vE '\bReady\b' <<< $output || break
        [ $i -ne 30 ] && sleep 30 || { error "Godot: nodes not running"; false; }
    done
}

wait_pods   () { [ $# -gt 0 ] && kubectl wait pods --for=condition=ready --timeout=10m "$@" || wait_all_pods; }
wait_nodes  () { [ $# -gt 0 ] && kubectl wait nodes --for=condition=ready --timeout=10m "$@" || wait_all_nodes; }
wait_deploy () { kubectl wait deployment --for=condition=available --timeout=5m "$@"; }
wait_podname() { kubectl wait pods --for=condition=ready --timeout=15m "$@" -o name | tail -1 | cut -d'/' -f2; }

wait_cluster() {
    retry "kubectl cluster-info" 20 30
    wait_nodes
    wait_pods
}

wait_cilium() {
  node_count=$(kubectl get --no-headers nodes | wc -l)
  cilium_pod=$(wait_podname -l k8s-app=cilium -n kube-system)
  cilium_status="-n kube-system exec $cilium_pod -- cilium status"
  kubectl $cilium_status | tee -a $OUTPUT | grep -E "^Controller Status:\s+([0-9]+)/\1 healthy" > /dev/null || error "Controller unhealthy"
  for i in {1..30}; do
      kubectl $cilium_status | grep -E "^Cluster health:\s+($node_count)/\1 reachable" && break
      [ $i -ne 30 ] && sleep 10 || error "Nodes unreachable bsc#??????"
  done
}

retry() {
    local cmd=$1
    local tries=${2:-10}
    local delay=${3:-30}
    local i
    for ((i=1; i<=tries; i++)); do
        timeout 25 bash -c "$cmd" && break || echo "RETRY #$i: $cmd"
        [ $i -ne $tries ] && sleep $delay || { error "Godot: $cmd"; false; }
    done
}

# Get file from selenium container
selenium_download() {
    local selenium_pod=$(wait_podname -l app=selenium)
    kubectl cp $selenium_pod:/home/seluser/Downloads/$1 ${2:-$1}
    kubectl exec $selenium_pod rm /home/seluser/Downloads/$1
}

# Execute command on all nodes
nodes_run() {
    local vm
    for vm in "${IP_NODES[@]}"; do
        ssh -i ~/.ssh/id_shared  $vm "$@" || { error "ssh -i ~/.ssh/id_shared $vm $@"; false; }
    done
}

# Upload file to all nodes
nodes_scp() {
    local vm
    for vm in "${IP_NODES[@]}"; do
        scp $1 $vm:/tmp/
        ssh -i ~/.ssh/id_shared $vm "sudo mv /tmp/$(basename $1) ${2:-.}"
    done
}

# Execute (long running) task on nodes in parallel
nodes_run_parallel() {
    unit="run-$(date +%s)"
    nodes_run "sudo systemd-run -r --unit $unit -- $1 2>&1"
    local vm
    for vm in "${IP_NODES[@]}"; do
        retry "ssh $ssh_opts $vm 'systemctl show -p SubState --value $unit | grep -vx running'" 30 60
        ssh $vm "sudo journalctl -u $unit"
        ssh $vm "systemctl show -p Result --value $unit | grep -qx success"
        ssh $vm "sudo systemctl stop $unit"
    done
}

collect_supportconfigs() {
    info 'collect supportconfigs'
    set +e
    nodes_run_parallel 'supportconfig -b -B supconfig -ipsuse_caasp'
    nodes_run 'sudo chmod +r /var/log/scc_supconfig.txz'

    local i
    for ((i=0; i<${#IP_MASTERS[@]}; i++)); do
        scp "${IP_MASTERS[i]}:/var/log/scc_supconfig.txz" "$LOGPATH/supportconfig-master-$i.txz"
    done
    for ((i=0; i<${#IP_WORKERS[@]}; i++)); do
        scp "${IP_WORKERS[i]}:/var/log/scc_supconfig.txz" "$LOGPATH/supportconfig-worker-$i.txz"
    done
    set -e
}

# ==================================================================================================
# Helpers for cluster upgrades

# Wait until all kubelet versions are the same
wait_same_versions () {
    local tries=${1:-10}
    local delay=${2:-30}
    local i
    local count
    for ((i=1; i<=tries; i++)); do
        count=$(kubectl get nodes -o json | jq -r '.items[].status.nodeInfo.kubeletVersion' | sort | uniq | wc -l)
        [ $count -eq 1 ] && break || echo "RETRY #$i: kubeletVersions are not the same"
        [ $i -ne $tries ] && sleep $delay || { error "Fail: kubeletVersions differs"; false; }
    done
}

# Configure private-registry to prevent docker rate limiting
add_fallback_reg() {
    step "Adding fallback registries"
    if [ ! -f "$LOGPATH/registries.conf" ]; then
        cp "$DATADIR/registries.conf.tpl" "$LOGPATH/registries.conf"
        nodes_run 'sudo mkdir -p /etc/containers'
        nodes_scp "$LOGPATH/registries.conf" '/etc/containers/'
        # Not needed to restart crio at this point, it is not even installed
    else
        info "Already there, skipping"
    fi
}

add_incident_rpm() {
    sudo cp "$DATADIR/vendors.conf" /etc/zypp/vendors.d/
    nodes_scp "$DATADIR/vendors.conf" '/etc/zypp/vendors.d/'
    iter=1
    for incident in ${INCIDENT_RPM//,/ }; do
        info "repo${iter}: $incident"
        sudo zypper ar -fG $incident INCIDENT${iter}
        nodes_run "sudo zypper ar -fG $incident INCIDENT${iter}"
        let iter++
    done
}

# Pull images from INCIDENT, use registry.suse.com as backup
add_incident_reg() {
    cp "$DATADIR/registries.conf.tpl" "$LOGPATH/registries.conf"
    for reg in ${INCIDENT_REG//,/ }; do
        info "registry: $reg"
        echo -e "\n[[registry.mirror]]\nlocation = \"${reg}\"\ninsecure = true\n" >> "$LOGPATH/registries.conf"
    done
    nodes_run 'sudo mkdir -p /etc/containers'
    nodes_scp "$LOGPATH/registries.conf" '/etc/containers/'

    # restart cri-o if cluster already exists
    curl $IP_LB:6443 > /dev/null && nodes_run 'sudo systemctl restart crio' ||:
}

# Turn kured on|off or set custom check interval
kured_config() {
    case $1 in
        on)  kubectl -n kube-system annotate ds kured weave.works/kured-node-lock-;;
        off) kubectl -n kube-system annotate ds kured weave.works/kured-node-lock='{"nodeID":"manual"}';;
        *) jq -n '{spec:{template:{spec:{containers:[{name:"kured",command:["/usr/bin/kured",$ARGS.positional[]]}]}}}}' --args -- "$@" |\
            kubectl -n kube-system patch ds kured -p "$(cat)";;
    esac
}

# Run skuba-update on nodes and reboot if necessary
# Watch reboots: for vmx in "${IP_NODES[@]}"; do nc -zvw3 $vmx 22; done
skuba_update_nodes() {
    # wait for running skuba-update to finish
    for vm in "${IP_NODES[@]}"; do
        retry "ssh $ssh_opts $vm '! systemctl is-active skuba-update'" 30 60
    done

    # trigger skuba-update if it was not running
    nodes_run_parallel 'skuba-update'

    # wait for kured reboots
    kured_config 'on'
    kured_config '--period=1m'
    for vm in "${IP_NODES[@]}"; do
        retry "ssh $ssh_opts $vm 'test ! -f /var/run/reboot-needed' 2>/dev/null" $((10 * NODE_COUNT)) 60
    done
    wait_cluster
    kured_config 'off'
}

skuba_addon_upgrade() {
    skuba addon refresh localconfig
    skuba addon upgrade plan
    skuba addon upgrade apply
    wait_pods
}

tf_plugins_check() {
    [ -d "$WORKDIR/terraform" ] || return 0 # skip on bare-metal
    jq -r 'to_entries[] | "/usr/bin/terraform-provider-\(.key) \(.value)"' "$WORKDIR/terraform/.terraform/plugins/linux_amd64/lock.json" |\
    {
      while read PLUGIN_BIN SHA256HASH; do
        # compare hash generated from binary with value from lock.json
        if [ $(sha256sum $PLUGIN_BIN | awk '{print $1}') != "$SHA256HASH" ]; then
          warn "$PLUGIN_BIN changed, terraform init needed"
          TF_PLUGINS_UPDATED=1
        fi
      done

      if [ -v TF_PLUGINS_UPDATED ]; then
        info "Terraform init (plugins changed)"
        pushd .
        cd "$WORKDIR/terraform"
        terraform init -get-plugins=false
        popd
      fi
    }
    # running the block above as a subshell will make TF_PLUGINS_UPDATED var visible for the rest of this block
}

# Kubernetes platform upgrade
skuba_cluster_upgrade() {
    local i
    skuba cluster upgrade plan
    for ((i=0; i<${#IP_MASTERS[@]}; i++)); do
        info "upgrade master #$i"
        skuba node upgrade plan caasp-master-$SUFFIX-$i
        skuba node upgrade apply -t ${IP_MASTERS[i]} -u sles -s
        wait_cluster # apiserver is restarted
    done

    # IP_LB:6443: connect: connection refused
    sleep 60
    wait_cluster

    for ((i=0; i<${#IP_WORKERS[@]}; i++)); do
        info "upgrade worker #$i"
        skuba node upgrade plan caasp-worker-$SUFFIX-$i
        skuba node upgrade apply -t ${IP_WORKERS[i]} -u sles -s
        sleep 60 # Unable to plan node upgrade: could not parse "Unknown" as version a-g#1169
    done
    wait_pods

    # Unable to plan addon upgrade: Not all nodes match clusterVersion 1.16.2
    wait_same_versions
}
