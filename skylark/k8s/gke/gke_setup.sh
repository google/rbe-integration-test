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

USAGE="Usage: $0 [--yaml_file yaml_file [--substitute orig replacement]...]... [--load_balancer load_balancer]... --project gcp_project_name --zone zone --cluster_name cluster_name --namespace namespace [--ephemeral_cluster] [--create_cluster_if_necessary] -- <extra flags to gcloud container clusters create>"
print_help() {
  echo "$USAGE"
  echo
  echo "Set up a k8s cluster and optionally an underlying gke cluster."
  echo
  echo "FLAGS:"
  echo "  --yaml_file"
  echo "      A k8s yaml file to deploy. Multiple --yaml_file flags may be"
  echo "      specified."
  echo "  --substitute"
  echo "      This flag is followed by two arguments, a from string and a to"
  echo "      string. It specifies that a substitution is to be performed on"
  echo "      the last yaml_file specified before the --substitute flag. There"
  echo "      can be multiple --substitute flags per yaml file, in which case,"
  echo "      the substitutions are performed in the specified order."
  echo "  --load_balancer"
  echo "      Specify a load balancer whose external ip the setup process"
  echo "      should wait for. For multiple load balancers, multiple"
  echo "      --load_balancer flags may be specified. The setup will output the"
  echo "      ips of these load balancers in output properties of the form"
  echo "      \"ip_{lb_name}\", as well as an \"ips\" output property which"
  echo "      contains a JSON string with all the load balancers."
  echo "  --project"
  echo "      The GCP project where the GKE cluster is located."
  echo "  --zone"
  echo "      The GCP zone where the GKE cluster is located."
  echo "  --cluster_name"
  echo "      The name of the GKE cluster to be created, or to be used,"
  echo "      depending on the values of --ephemeral_cluster and"
  echo "      --create_cluster_if_necessary."
  echo "  --namespace"
  echo "      The k8s namespace to be used."
  echo "  --ephemeral_cluster"
  echo "      If set, a GKE cluster is created at setup. If unset (default) the"
  echo "      setup tries to connect to a pre-existing GKE cluster."
  echo "  --create_cluster_if_necessary"
  echo "      Relevant only if --ephemeral_cluster is unset. Controls the"
  echo "      behavior in case setup fails to find a pre-existing GKE cluster."
  echo "      If the flag is true, setup tries to create a GKE cluster."
  echo "      Otherwise, the setup fails."
  echo "  --"
  echo "      Any flags following the -- arguments are passed to the command"
  echo "      that creates the GKE cluster, \"gcloud container clusters create\""
  echo "      This is only relevant if --ephemeral_cluster is true or if"
  echo "      --create_cluster_if_necessary is true."
}

# YAML_FILES is a two dimensional array.
# There is a row for every yaml file, and NUM_OF_YAML_FILES will end up being
# the number of such rows.
# The first element in each row is the yaml file name.
# The following elements in each row are pairs of <from_string, to_string> for
# substitution.
#
# So for example, this row:
# ["/path/to/file.yaml", "abc", "def", "123", "456"]
# means that we want to deploy a yaml file which is based on
# "/path/to/file.yaml" but has every instance of string "abc" replaced with
# "def" and every instance of string "123" replaced with "456".
#
# The replacements are performed in the order in which they are specified.
#
# Both the from_string and to_string must be single line.
declare -A YAML_FILES
NUM_OF_YAML_FILES=0

# Parse arguments. Expect key and value to appear as a separate arguments.
# So "--key" "value" and not "--key=value".
parse_args() {
  while [[ $# > 0 ]]; do
    i="$1"
    case $i in
        --yaml_file)
        shift
        YAML_FILES[$NUM_OF_YAML_FILES,0]="$1"
        NUM_OF_SUBSTITUTIONS[$NUM_OF_YAML_FILES]=0
        let "NUM_OF_YAML_FILES++"
        shift
        ;;
        --substitute)
        shift
        # --substitute is followed by two args (orig and replacement) and always
        # refers to the last yaml file specified.
        if [[ $NUM_OF_YAML_FILES == 0 ]]; then
          echo "--substitute must appear after --yaml_file and refer to that yaml file."
          return 1
        fi
        YAML_FILE_INDEX=$(($NUM_OF_YAML_FILES - 1))
        YAML_FILES[$YAML_FILE_INDEX,$((2*${NUM_OF_SUBSTITUTIONS[$YAML_FILE_INDEX]}+1))]="$1"
        YAML_FILES[$YAML_FILE_INDEX,$((2*${NUM_OF_SUBSTITUTIONS[$YAML_FILE_INDEX]}+2))]="$2"
        let "NUM_OF_SUBSTITUTIONS[$YAML_FILE_INDEX]++"
        shift
        shift
        ;;
        --load_balancer)
        shift
        LOAD_BALANCERS+=("$1")
        shift
        ;;
        --project)
        shift
        GCLOUD_PROJECT_NAME="$1"
        shift
        ;;
        --zone)
        shift
        ZONE="$1"
        shift
        ;;
        --cluster_name)
        shift
        CLUSTER_NAME="$1"
        shift
        ;;
        --namespace)
        shift
        NAMESPACE="$1"
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
  print_help
  exit 1
fi

# Create, from the two dimensional YAML_FILES array, two simple arrays:
# ORIG_YAML_FILES and RESOLVED_YAML_FILES. The resolved yaml files are the yaml
# files with the replacements. Both arrays are of length NUM_OF_YAML_FILES.
for ((I=0; I<$NUM_OF_YAML_FILES; I++)); do
  YAML_FILE_TEMPLATE=${YAML_FILES[$I,0]}
  # Verify the existence of the yaml files.
  if [ ! -f "$YAML_FILE_TEMPLATE" ]; then
    echo "File $YAML_FILE_TEMPLATE does not exist"
    exit 1
  fi
  ORIG_YAML_FILES+=($YAML_FILE_TEMPLATE)
  if [[ ${NUM_OF_SUBSTITUTIONS[$I]} == 0 ]]; then
    RESOLVED_YAML_FILES+=($YAML_FILE_TEMPLATE)
  else
    RESOLVED_FILE=$(mktemp)
    cp $YAML_FILE_TEMPLATE $RESOLVED_FILE
    RESOLVED_YAML_FILES+=($RESOLVED_FILE)
    # Loop through substitutions and apply sed on RESOLVED_FILE.
    for ((J=0; J<${NUM_OF_SUBSTITUTIONS[$I]}; J++)); do
      # Substitute using sed.
      # FROM and TO have "/", "\\" and "&" escaped so that they can be used in sed.
      FROM=$(echo ${YAML_FILES[$I,$(($J*2+1))]} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')
      TO=$(echo ${YAML_FILES[$I,$(($J*2+2))]} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')
      sed -i "s/${FROM}/${TO}/g" $RESOLVED_YAML_FILES
    done
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

for ((I=0; I<$NUM_OF_YAML_FILES; I++)); do
  echo "Creating cluster from yaml file ${ORIG_YAML_FILES[$I]}..."
  $KUBECTL_BIN create -f "${RESOLVED_YAML_FILES[$I]}" \
    || { echo "Failed creating cluster from yaml file ${ORIG_YAML_FILES[$I]}."; exit 1; }
done

# Wait for external IP of load balancers to become available
echo "Waiting for load balancers to externalize their ips..."
TIME_COUNTER=0 # In seconds
SLEEP_TIME=5   # In seconds
TIMEOUT=180    # 3 minutes in seconds
declare -A LB_IPS
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
