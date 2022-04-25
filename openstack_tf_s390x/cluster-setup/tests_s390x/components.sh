step 'Component versions'

kubectl version --short=true | sed -r 's/(\w+) Version/Kubernetes \1/'

cri=$(ssh "${IP_MASTERS[0]}" crictl -r unix:///run/k3s/containerd/containerd.sock images | grep -v ^IMAGE)
printf "\n# Containers: %s\n" $(echo "$cri" | cut -d'/' -f1,2 | uniq)
printf "%-15s | %s\n" $(echo "$cri" | sed -r 's:.*/([^ ]+) +([^ ]+).*:\1 \2:')
