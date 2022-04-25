# https://documentation.suse.com/sles/15-SP2/single-html/SLES-tuning/#sec-util-multi-sar
# https://www.thegeekstuff.com/2011/03/sar-examples/
step "Deploy sar"

# enable
nodes_run 'zypper -n in cron sysstat'
nodes_run 'systemctl enable --now cron'
nodes_run 'systemctl enable --now sysstat'


# stats for current day
sar -u
# data files to export
ls /var/log/sa/

# Export logs
# nodes_run 'tar -czf sar-logs-$(hostname).tgz /var/log/sa/'
# scp ${IP_MASTERS[0]}:/root/sar-logs-rke2-master-mkravec-0.tgz .
# k get nodes -o wide > k-get-nodes.log
# k get pods -o wide -A > k-get-pods.log
# k top pods -A --sort-by cpu > k-top-pods.log
# k top nodes > k-top-nodes.log
