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

TF_BIN="terraform"
INPUT_FILE="terraform.tfplan"

if [[ "$#" != "1" ]]; then
  echo "We expect to recieve the sut_id as the only parameter:"
  echo "$@"
  exit 1
fi
SUT_ID=$1

TF_DIR="/tmp/terraform_$SUT_ID/"
mkdir -p "$TF_DIR"
if [ $? != 0 ]; then
    echo "Was not able to create a new directory: $TF_DIR"
    exit 1
fi

# Change to terraform directory to run terraform there.
pushd "$TF_DIR"

# Copy input_file content which contains all plugins and files used by setup.
tar -zxf "$_INPUT_DIR/$INPUT_FILE" ./

if [ $? != 0 ]; then
    echo "Was not able to copy the input file: $_INPUT_DIR/$INPUT_FILE"
    exit 1
fi

# In plan-apply-destroy methodology, tf init is not needed for teardown, the
# entire working directory (example_terraform/) is given as a build artifact.
echo "Attempting to teardown server"
$TF_BIN destroy -no-color -force ./

# Go back to working directory
popd
