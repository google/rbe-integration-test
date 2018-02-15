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

USAGE="Usage: $0 --project gcp_project_name --zone zone --cluster_name cluster_name --namespace namespace [--ephemeral_cluster]"

# Parse arguments. Expect key and value to appear as a separate arguments.
# So "--key" "value" and not "--key=value".
parse_args() {
  while [[ $# > 0 ]]; do
    i="$1"
    case $i in
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

GCLOUD_BIN="gcloud"
KUBECTL_BIN="kubectl"

# gcloud creates .config and .kube directories in the $HOME directory, so we
# need to make sure that that this directory exists and that we have write
# permissions there.
HOME=/tmp

echo "Downloading credentials for kubectl access to the cluster..."
$GCLOUD_BIN container clusters get-credentials \
  "$CLUSTER_NAME" \
  "--project=$GCLOUD_PROJECT_NAME" \
  "--zone=$ZONE" \
  || { echo "Failed getting credentials."; exit 1; }

# Use namespace.
echo "Setting namespace in k8s context ..."
$KUBECTL_BIN config set-context \
  "$("$KUBECTL_BIN" config current-context)" "--namespace=$NAMESPACE" \
    || { echo "Failed setting namespace context to $NAMESPACE."; exit 1; }

# Download log files
PODS="$($KUBECTL_BIN get pods -o name)"
for POD in $PODS; do

  echo "Log from $POD"
  echo "=============== START LOG ================"
  $KUBECTL_BIN logs "$POD"
  echo "================ END LOG ================="
done

# Delete namespace. This should delete all kubectl resources.
$KUBECTL_BIN delete namespace $NAMESPACE \
  || { echo "Failed deleting namespace $NAMESPACE."; exit 1; }

if [ "$EPHEMERAL_CLUSTER" = true ]; then
  # Unfortunately, without a delay between the tearing down of the k8s stuff
  # ("kubectl delete ...") and the tearing down of the GKE cluster
  # ("gcloud container clusters delete ...") some GCP elements seem to leak.
  # See b/30538238.
  #
  # Even more unfortunately, the amount of delay required depends on the
  # complexity of the configuration in the yaml file.
  # It seems that in some cases (e.g. tensorflow dist_test with 4 servers and 4
  # load balancers) we need more than a minute delay.
  #
  # It appears that this issue has been raised and people are working on this
  # problem. Hopefully kubectl delete will have a --wait option (see
  # https://github.com/kubernetes/kubernetes/issues/42594). Until then, we add a
  # sleep and hope that it covers all our use cases.
  #


  # The necessary delay time appears to be mostly related to the number of load
  # balancers, so we sleep for a length of time that is heuristically linear
  # with the number of load balancers.
  LBS="$($KUBECTL_BIN get services | grep LoadBalancer | wc -l)"
  let "DELAY = 30 * ${LBS} + 10"
  echo "Sleeping for $DELAY seconds to allow k8s services to shut down before turning down GKE cluster ..."
  sleep $DELAY

  echo "Turning down GKE cluster..."
  $GCLOUD_BIN container clusters delete \
    "$CLUSTER_NAME" \
    "--project=$GCLOUD_PROJECT_NAME" \
    --quiet "--zone=$ZONE" \
    || { echo "Failed deleting GKE cluster."; exit 1; }
fi
