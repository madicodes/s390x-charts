# https://bugzilla.suse.com/show_bug.cgi?id=1145489
step "Sonobuoy"

info 'Run sonobuoy'
sonobuoy run --wait --wait-output=progress \
	--mode=certified-conformance \
	--e2e-skip "Ingress API should support creating Ingress API operations"


info 'Check results'
results=$(sonobuoy retrieve $LOGPATH)
sonobuoy results -p e2e $results | tee -a "$OUTPUT" | grep 'Failed: 0'

# info 'Cleanup'
# sonobuoy delete --all --wait
