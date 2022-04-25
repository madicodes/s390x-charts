step "Deploy $PLATFORM"

tf_active "${DATADIR}/openstack_tf_s390x/terraform.tfstate" && false

info "Use custom ${DATADIR}/openstack_tf_s390x"
cp -r $DATADIR/openstack_tf_s390x terraform && cd terraform

terraform init -no-color

# https://download.suse.de/ibs/SUSE/Products/SLE-Product-JeOS/15-SP2-QU2/
sed -i '
/^stack_name\b/       s/=.*/= "'"$SUFFIX"'"/
/^authorized_keys\b/ {n;s|""|"'"$SSH_SHARED"'"|}' terraform.tfvars

# longhorn-test doesnt work with default 10GB ext4
# image: Name = 210106-s15s2-jeos-2part-btrfs
# flavor: Name = medium; RAM = 16384; Disk = 40; VCPUs = 4
[[ "$TESTSUITE" =~ longhorn ]] && sed -i '$a\
image_id = "7bccad00-14c9-4570-a7eb-e55d15ac8617"\
flavor_id = "271fe0bc-92c3-4627-b85f-85d0234b680a"' terraform.tfvars

# declare -a repos=()
# if [ -n "${SCC:-}" ]; then
#     info "Use SCC key"
#     sed -i "/^#caasp_registry_code/ c\caasp_registry_code = \"$SCC\"" registration.auto.tfvars
#     if [ "${UPGRADE:-}" = "before" ]; then
#         iter=1
#         for incident in ${INCIDENT_RPM//,/ }; do
#             repos+=("INCIDENT$((iter++)) = \"$incident\",")
#         done
#     fi
# else
#     info "Use IBS repositories"
#     repos=(
#         'sle_server_pool    = "http://download.suse.de/ibs/SUSE/Products/SLE-Product-SLES/15-SP2/x86_64/product/",'
#         'basesystem_pool    = "http://download.suse.de/ibs/SUSE/Products/SLE-Module-Basesystem/15-SP2/x86_64/product/",'
#         'containers_pool    = "http://download.suse.de/ibs/SUSE/Products/SLE-Module-Containers/15-SP2/x86_64/product/",'
#         'sle_server_updates = "http://download.suse.de/ibs/SUSE/Updates/SLE-Product-SLES/15-SP2/x86_64/update/",'
#         'basesystem_updates = "http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Basesystem/15-SP2/x86_64/update/",'
#         'containers_updates = "http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Containers/15-SP2/x86_64/update/",')
# 
#         case $SKUBA_BUILD in
#             development|staging)  # add ca-certificates-suse for registry.suse.de
#                 sed -i '/^packages\b/a "ca-certificates-suse",' terraform.tfvars
#                 repos+=('suse_ca = "http://download.suse.de/ibs/SUSE:/CA/SLE_15_SP2/",') ;;&
#             development)
#                 repos+=('caasp_devel = "https://download.suse.de/ibs/Devel:/CaaSP:/4.5/SLE_15_SP2/",') ;;
#             staging)
#                 false # leftover & wrong repo
#                 repos+=('caasp_staging = "http://download.suse.de/ibs/SUSE:/SLE-15-SP2:/Update:/Products:/CASP40/staging/",') ;;
#             release)
#                 repos+=('caasp_pool    = "http://download.suse.de/ibs/SUSE/Products/SUSE-CAASP/4.5/x86_64/product/",'
#                         'caasp_updates = "http://download.suse.de/ibs/SUSE/Updates/SUSE-CAASP/4.5/x86_64/update/",') ;;
#         esac
# fi

# if [ ${#repos[@]} -gt 0 ]; then
#     sed -i '/^repositories\b/ s|=.*|= {\n '"${repos[*]/,/,\\n}"'}|' terraform.tfvars
# fi

info "Deploy terraform $MASTER_COUNT:$WORKER_COUNT"
sed -i '
/^masters\b/ s/=.*/= '"$MASTER_COUNT"'/
/^workers\b/ s/=.*/= '"$WORKER_COUNT"'/' terraform.tfvars
terraform apply -auto-approve -no-color

info "Check cloud-init status"
for vm in $(terraform output -json | jq '.ip_masters.value,.ip_workers.value | to_entries[0].value // empty' -r); do
    # Wait for reboot when terraform finished
    for i in {1..10}; do
        ssh -q $vm true && break
        [ $i -ne 10 ] && sleep 15 || { error "No ssh: $vm"; false; }
    done
    ssh $vm sudo chmod a+r /var/log/cloud-init.log
    scp $vm:/var/log/cloud-init.log "$LOGPATH/$vm-cloud-init.log"
    scp $vm:/var/log/cloud-init-output.log "$LOGPATH/$vm-cloud-init-output.log"
    ssh $vm cloud-init status | grep 'status: done' > /dev/null
done
