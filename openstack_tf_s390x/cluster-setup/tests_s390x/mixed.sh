step "Mixed checks"

info 'apparmor enabled & running'
ssh "${IP_MASTERS[0]}" systemctl -q is-active apparmor
ssh "${IP_WORKERS[0]}" systemctl -q is-active apparmor
ssh "${IP_MASTERS[0]}" systemctl -q is-enabled apparmor
ssh "${IP_WORKERS[0]}" systemctl -q is-enabled apparmor

# Swap is turned off
[ -z "$(ssh ${IP_MASTERS[0]} sudo swapon --noheadings --show)" ]

info 'check metrics-server functionality'
kubectl rollout status deploy/rke2-metrics-server -n kube-system
kubectl top nodes

: # return 0 instead of $?
