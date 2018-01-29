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

USAGE="Usage: $0 --project_id=project_id --image_name=image_name"

# Parse arguments. Expect key and value to appear as a single argument with an
# equal sign. So "--key=value" and not "--key value".
parse_args() {
  for i in "$@"; do
    case $i in
        --project_id=*)
        PROJECT_ID="${i#*=}"
        shift
        ;;
        --image_name=*)
        IMAGE_NAME="${i#*=}"
        shift
        ;;
        *)
        echo "Unsupported option $i"
        return 1
        ;;
    esac
  done
  if [[ "$PROJECT_ID" == "" ]]; then
    echo "Missing project_id"
    return 1
  fi
  if [[ "$IMAGE_NAME" == "" ]]; then
    echo "Missing image_name"
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

RAND=$(head -200 /dev/urandom | cksum | cut -f1 -d " ")
echo "image=gcr.io/${PROJECT_ID}/${IMAGE_NAME}_${RAND}" >> "$_SETUP_OUTPUT"
touch "$_SETUP_DONE"
