# Tests kubeconf (download & use) for tests/auth/*

function test_auth() {
    kubectl create rolebinding italiansrb --clusterrole=admin --group=Italians # Tesla is italian
    kubectl create rolebinding curierb --clusterrole=view --user=curie@suse.com
    kubectl create rolebinding eulerrb --clusterrole=edit --user=euler@suse.com

    test_skuba_auth_user
    [ "$1" != "staticpw" ] && test_skuba_auth_group
    test_selenium_auth_user

    kubectl delete rolebinding italiansrb curierb eulerrb
}

function test_skuba_auth_group() {
    substep "Authentication user from group with CLI"

    info 'CLI kubeconfig (group access)'
    skuba auth login -u tesla@suse.com -p password -s https://$IP_LB:32000 -r "$WORKDIR/cluster/pki/ca.crt" -c tesla.conf
    kubectl --kubeconfig=tesla.conf auth can-i get rolebindings | grep -x yes

    rm tesla.conf
}

function test_skuba_auth_user() {
    substep "Authentication users with CLI"

    info 'CLI kubeconfig (skuba auth) with VIEW role '
    skuba auth login -u curie@suse.com -p password -s https://$IP_LB:32000 -r "$WORKDIR/cluster/pki/ca.crt" -c curie.conf
    kubectl --kubeconfig=curie.conf auth can-i list pods | grep -x yes
    (kubectl --kubeconfig=curie.conf auth can-i delete pods || :) | grep -x no

    info 'CLI kubeconfig (skuba auth) with EDIT role'
    skuba auth login -u euler@suse.com -p password -s https://"$IP_LB":32000 -k -c euler.conf
    kubectl --kubeconfig=euler.conf auth can-i delete pods | grep -x yes
    (kubectl --kubeconfig=euler.conf auth can-i get rolebindings || :) | grep -x no
    (kubectl --kubeconfig=euler.conf get rolebindings || :) |& grep Forbidden

    rm curie.conf euler.conf
}

function test_selenium_auth_user() {
    substep "Authentication users with selenium"

    info 'WebUI kubeconfig (gangway) with VIEW role'
    $TESTDIR/selenium-auth.py -i $IP_LB -u curie@suse.com
    selenium_download kubeconf curie.conf
    kubectl --kubeconfig=curie.conf auth can-i list pods | grep -x yes
    (kubectl --kubeconfig=curie.conf auth can-i delete pods || :) | grep -x no

    info 'WebUI kubeconfig (gangway) with EDIT role'
    $TESTDIR/selenium-auth.py -i $IP_LB -u euler@suse.com
    selenium_download kubeconf euler.conf
    kubectl --kubeconfig=euler.conf auth can-i delete pods | grep -x yes
    (kubectl --kubeconfig=euler.conf auth can-i get rolebindings || :) | grep -x no
    (kubectl --kubeconfig=euler.conf get rolebindings || :) |& grep Forbidden

    rm curie.conf euler.conf
}
