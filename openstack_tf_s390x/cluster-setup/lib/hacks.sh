# https://github.com/SUSE/skuba/pull/638
# https://github.com/SUSE/skuba/pull/649
hack_openstack_lb() {
    warn 'Hack: change load-balancer to avoid random kubectl disconnects'
    sed -i '/^resource "openstack_lb_monitor_v2" "kube_api_monitor"/,/^$/ {
    /delay/ s/3/10/
    /timeout/ s/1/5/
    /max_retries/ s/1/3/
    }' load-balancer.tf
}

# Use faster storage
hack_vmware_datastore() {
    if grep -q vsphere_datastore_cluster variables.tf; then
        sed -i '/^vsphere_datastore\b/d' terraform.tfvars
        echo 'vsphere_datastore_cluster = "LOCAL-DISKS-CLUSTER"' >> terraform.tfvars
    else
        # Keeping for compatibility with GM cluster
        # https://github.com/lcavajani/skuba/commit/2f4e58db951214cb7d4add1220baab4227795191
        [ -f lb-instance.tf ] && lb_file="lb-instance.tf"
        sed -i '/^#/! s/datastore/datastore_cluster/g' variables.tf master-instance.tf worker-instance.tf ${lb_file:-} terraform.tfvars
        sed -i '/^vsphere_datastore_cluster/ s/=.*/= "LOCAL-DISKS-CLUSTER"/' terraform.tfvars
    fi
}
