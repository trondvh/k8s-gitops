#!/bin/bash
REPO_ROOT=$(git rev-parse --show-toplevel)
CLUSTER_ROOT="${REPO_ROOT}/deployments"
SECRETS_ROOT="${REPO_ROOT}/.secrets"
PUB_CERT="${REPO_ROOT}/_setup/sealedsecret-cert.pem"

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "kubectl"
need "envsubst"

# Work-arounds for MacOS
if [ "$(uname)" == "Darwin" ]; then
  # Source secrets.env
  set -a
  . "${SECRETS_ROOT}/cluster-vars.env"
  set +a
else
  . "${SECRETS_ROOT}/cluster-vars.env"
fi

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

while IFS= read -r -d '' file
do
  # Get the path and basename of the txt file
  # e.g. "deployments/default/pihole/pihole"
  secret_path="$(dirname "$file")"

  # Get the secret name
  secret_name=$(basename -s .yaml "$file")

  # Get the relative path of deployment
  deployment=${secret_path#"${SECRETS_ROOT}"}

  # Get the namespace (based on folder path of manifest)
  namespace=$(echo ${deployment} | awk -F/ '{print $2}')

  envsubst < "$file" \
    | \
  sed "s/namespace:.*/namespace: $namespace/" \
    | \
  sed "s/name:.*/name: $secret_name/" \
    |
  kubeseal --format=yaml --cert="${PUB_CERT}" \
    |
  sed '/creationTimestamp: .*/d' > "$CLUSTER_ROOT""$deployment"/sealedsecret-"$secret_name".yaml

done <   <(find "${SECRETS_ROOT}" -name '*.yaml' -print0)

message "all done!"