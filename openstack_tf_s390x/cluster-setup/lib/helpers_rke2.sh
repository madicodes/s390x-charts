# Helper functions for rke2

#export RKE_RELEASES_FULL=$(curl -sH "Accept: application/vnd.github.v3+json" 'https://api.github.com/repos/rancher/rke2/releases' |\
 #   jq -er '.[] | select(.assets[].name == "rke2.linux-s390x") | .name' | sort -V)

export RKE_RELEASES_FULL="v1.21.11+rke2r1
v1.21.11-rc3+rke2r1
v1.21.11-rc4+rke2r1
v1.21.11-rc5+rke2r1
v1.21.11-rc6+rke2r1
v1.21.12-rc1+rke2r1
v1.21.12-rc2+rke2r1
v1.21.12-rc3+rke2r1
v1.21.12-rc4+rke2r1
v1.22.8+rke2r1
v1.22.8-rc3+rke2r1
v1.22.8-rc4+rke2r1
v1.22.8-rc5+rke2r1
v1.22.8-rc6+rke2r1
v1.22.9-rc1+rke2r1
v1.22.9-rc2+rke2r1
v1.22.9-rc3+rke2r1
v1.22.9-rc4+rke2r1
v1.23.5+rke2r1
v1.23.5-rc2+rke2r1
v1.23.5-rc3+rke2r1
v1.23.5-rc4+rke2r1
v1.23.5-rc5+rke2r1
v1.23.6-rc2+rke2r1
v1.23.6-rc3+rke2r1
v1.23.6-rc4+rke2r1"
# remove -RCs for released ones
export RKE_RELEASES="$RKE_RELEASES_FULL"
for r in $(echo "$RKE_RELEASES" | grep -v -- '-rc[0-9]+'); do
    # grep: v1.22.8 & -rc[0-9]+ & rke2r1
    RKE_RELEASES=$(echo "$RKE_RELEASES" | grep -v "${r%+*}-rc[0-9]+${r#*+}")
done

export RKE_LATEST=$(echo "$RKE_RELEASES" | tail -1)

# get latest (v1.22[.5-rc1+rke2r1] -> v1.22.8-rc6+rke2r1)
get_latest_from() {
    # local ver=$(echo $1 | cut -d'.' -f1,2)
    echo "$RKE_RELEASES" | grep "^$1" | tail -1 | xargs
}
