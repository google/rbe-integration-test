#!/bin/bash
#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

USAGE="Usage: $0 [--yaml_files=yaml_file1,yaml_file2...] [--load_balancers=load_balancer1,load_balancer2...] --project=gcp_project_name --zone=zone --cluster_name=cluster_name --namespace=namespace [--ephemeral_cluster] [--create_cluster_if_necessary] -- <extra flags to gcloud container clusters create>"

# Parse arguments. Expect key and value to appear as a single argument with an
# equal sign. So "--key=value" and not "--key value".
parse_args() {
  for i in "$@"; do
    case $i in
        --yaml_files=*)
        YAML_FILES_CSV="${i#*=}"
        shift
        ;;
        --load_balancers=*)
        LOAD_BALANCERS_CSV="${i#*=}"
        shift
        ;;
        --project=*)
        GCLOUD_PROJECT_NAME="${i#*=}"
        shift
        ;;
        --zone=*)
        ZONE="${i#*=}"
        shift
        ;;
        --cluster_name=*)
        CLUSTER_NAME="${i#*=}"
        shift
        ;;
        --namespace=*)
        NAMESPACE="${i#*=}"
        shift
        ;;
        --ephemeral_cluster)
        EPHEMERAL_CLUSTER=true
        shift
        ;;
        --create_cluster_if_necessary)
        CREATE_CLUSTER_IF_NECESSARY=true
        shift
        ;;
        --)
        # The rest of the arguments after "--" are passed directly to
        # "gcloud container clusters create"
        shift
        CLUSTER_CREATE_FLAGS=("$@")
        break;
        ;;
        *)
        echo "Unsupported option $i"
        return 1
        ;;
    esac
  done
  if [[ "$GCLOUD_PROJECT_NAME" == "" ]]; then
    echo "Missing gcp_project_name"
    return 1
  fi
  if [[ "$ZONE" == "" ]]; then
    echo "Missing zone"
    return 1
  fi
  if [[ "$CLUSTER_NAME" == "" ]]; then
    echo "Missing cluster_name"
    return 1
  fi
  if [[ "$NAMESPACE" == "" ]]; then
    echo "Missing namespace"
    return 1
  fi
  return 0
}

parse_args "$@"
# $? is the return value of parse_args.
if [[ $? -ne 0 ]]; then
  echo "Failed to parse arguments:" "$@"
  echo  "$USAGE"
  exit 1
fi

# Verify the existence of the yaml files.
IFS=, read -r -a YAML_FILES <<<"$YAML_FILES_CSV"
for YAML_FILE in "${YAML_FILES[@]}"; do
  if [ ! -f "$YAML_FILE" ]; then
    echo "File $YAML_FILE does not exist"
    exit 1
  fi
done

GCLOUD_BIN="gcloud"
KUBECTL_BIN="kubectl"

echo "Starting GKE setup"

# gcloud creates .config and .kube directories in the $HOME directory, so we
# need to make sure that that this directory exists and that we have write
# permissions there.
HOME=/tmp

create_gke_cluster() {
  echo "Creating GKE cluster..."
  $GCLOUD_BIN container clusters create \
    "$CLUSTER_NAME" \
    "--project=$GCLOUD_PROJECT_NAME" \
    "--zone=$ZONE" \
    "${CLUSTER_CREATE_FLAGS[@]}"
}

connect_to_gke_cluster() {
  echo "Downloading credentials for kubectl access to the GKE cluster..."
  $GCLOUD_BIN container clusters get-credentials \
    "$CLUSTER_NAME" \
    "--project=$GCLOUD_PROJECT_NAME" \
    "--zone=$ZONE"
}

# Create or connect to a GKE cluster
if [ "$EPHEMERAL_CLUSTER" = true ]; then
  create_gke_cluster || { echo "Failed creating GKE cluster."; exit 1; }
else
  if [ "$CREATE_CLUSTER_IF_NECESSARY" = true ]; then
    connect_to_gke_cluster || {
      echo "Cannot connect to GKE cluster. Trying to create it"
      create_gke_cluster || { echo "Failed creating GKE cluster."; exit 1; }
    }
  else
    connect_to_gke_cluster || { echo "Failed connecting to GKE cluster."; exit 1; }
  fi
fi

# Create a namespace and perform all kubectl commands in that namespace.
echo "Creating k8s namespace $NAMESPACE ..."
$KUBECTL_BIN create namespace $NAMESPACE \
  || { echo "Failed creating namespace $NAMESPACE."; exit 1; }
echo "Setting namespace in k8s context ..."
$KUBECTL_BIN config set-context \
  "$("$KUBECTL_BIN" config current-context)" "--namespace=$NAMESPACE" \
    || { echo "Failed setting namespace context to $NAMESPACE."; exit 1; }

for YAML_FILE in "${YAML_FILES[@]}"; do
  echo "Creating cluster from yaml file ${YAML_FILE}..."
  $KUBECTL_BIN create -f "$YAML_FILE" \
    || { echo "Failed creating cluster from yaml file $YAML_FILE."; exit 1; }
done

# Wait for external IP of load balancers to become available
echo "Waiting for load balancers to externalize their ips..."
TIME_COUNTER=0 # In seconds
SLEEP_TIME=5   # In seconds
TIMEOUT=180    # 3 minutes in seconds
declare -A LB_IPS
IFS=, read -r -a LOAD_BALANCERS <<<"$LOAD_BALANCERS_CSV"
while [[ ${#LB_IPS[@]} -lt ${#LOAD_BALANCERS[@]} ]]; do
  sleep $SLEEP_TIME
  let TIME_COUNTER=TIME_COUNTER+SLEEP_TIME
  if [[ "${TIME_COUNTER}" -gt "${TIMEOUT}" ]]; then
    # Timeout is up and we still can't determine all the load balancer ips.
    echo "kubectl get service"
    $KUBECTL_BIN get service
    echo "Failed to determine all the load balancers' external IPs."
    exit 1
  fi
  for LOAD_BALANCER in "${LOAD_BALANCERS[@]}"; do
    EXTERN_IP="$("$KUBECTL_BIN" get svc "$LOAD_BALANCER" --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")"
    if [[ ! -z "$EXTERN_IP" ]]; then
      LB_IPS[$LOAD_BALANCER]=$EXTERN_IP
    fi
  done
done

# Output the load balancer external ips into the setup output file.
# The key of each property is the load balancer name prefixed by "ip_" and the
# value is the external ip.
# In addition to that, output a single "ips" property which includes a JSON
# string containing a mapping of lbs to ips.
IPS_JSON="{"
FIRST_LB=true
for LOAD_BALANCER in "${LOAD_BALANCERS[@]}"; do

  echo "ip_${LOAD_BALANCER}=${LB_IPS[$LOAD_BALANCER]}" >> "$_SETUP_OUTPUT"
  if [[ $FIRST_LB == false ]]; then
    IPS_JSON+=","
  else
    FIRST_LB=false
  fi
  IPS_JSON+="\"${LOAD_BALANCER}\":\"${LB_IPS[$LOAD_BALANCER]}\""
done
IPS_JSON+="}"

echo "ips=${IPS_JSON}" >> "$_SETUP_OUTPUT"
echo "cluster_name=${CLUSTER_NAME}" >> "$_SETUP_OUTPUT"
echo "namespace=${NAMESPACE}" >> "$_SETUP_OUTPUT"

echo "Found external IPs for all load balancers: ${IPS_JSON}"

touch "$_SETUP_DONE"
