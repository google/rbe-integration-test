#!/bin/bash

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

if [[ $# -ne 1 ]]; then
  echo "Error - Expecting a single argument."
  echo "Usage: $0 <docker_image>"
  exit 1
fi

IMAGE=$1

GCLOUD_BIN="gcloud"

echo "Deleting image $IMAGE ..."
$GCLOUD_BIN container images delete --quiet --force-delete-tags $IMAGE \
  || { echo "Failed to delete image $IMAGE."; exit 1; }

echo "Image deleted."
