step 'upgrade rke2'

# without UPGRADETO= will upgrade to next version, can't downgrade
# v run -n 1:1 -v 1.21 -t rke2_upgrade (1.21 -> 1.22)
# v cluster_abc -t rke2_upgrade [-e UPGRADETO=1.22[.XXX]]


# get released version if exists
# v1.22.8-rc6+rke2r1 -> v1.22.8+rke2r1
get_norc_from() {
    local norc=$(echo $1 | sed -E 's/-rc[0-9]+//')
    echo "$RKE_RELEASES" | grep -qF "$norc" && echo $norc || echo $1
}

# get next rke version from current
# v1.22[.8-rc6+rke2r1] -> v1.23.5+rke2r1
get_next_rke() {
    local rke_next=$(echo $RKE_CURRENT | awk -F'.' '{ print "v1." ++$2 }')
    get_latest_from $rke_next
}

if [ -v UPGRADETO ]; then
    # prepend "v" if needed
    UPGRADETO=${UPGRADETO/#1/v1}
    # check that target exists
    echo "$RKE_RELEASES_FULL" | grep -F $UPGRADETO
else
    UPGRADETO=$(get_next_rke)
fi

[[ $UPGRADETO =~ ^v1\.[0-9]+.*+rke2r ]] && rke_target=$UPGRADETO
[[ $UPGRADETO =~ ^v1\.[0-9]+ ]] && rke_target=$(get_latest_from $UPGRADETO)

info "current: $RKE_CURRENT"
info "target: $rke_target"

# Check that upgrade is possible (can't downgrade)
pos_current=$(echo "$RKE_RELEASES_FULL" | grep -n "$RKE_CURRENT" | cut -d: -f1)
pos_target=$(echo "$RKE_RELEASES_FULL" | grep -n "$rke_target" | cut -d: -f1)

# || "$rke_target" == "$(get_norc_from $RKE_CURRENT)"
if [[ $pos_current -ge $pos_target ]]; then
    warn "can't upgrade: $RKE_CURRENT -> $rke_target"
    return 0
fi

if ! kubectl get deploy -n system-upgrade system-upgrade-controller 2>/dev/null; then
    warn 'static v0.9.1'
    kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/v0.9.1/system-upgrade-controller.yaml
    kubectl rollout status -n system-upgrade deploy/system-upgrade-controller

    kubectl label nodes rke2-upgrade=true --all
fi

info "rke2: $RKE_CURRENT -> $rke_target"
sed "s/UPGRADE_TO/${rke_target/+/-}/" $DATADIR/rke2-upgrade-plan.yaml > $WORKDIR/rke2-upgrade-plan.yaml
kubectl apply -f $WORKDIR/rke2-upgrade-plan.yaml

warn 'TODO: wait'
# wait


:
