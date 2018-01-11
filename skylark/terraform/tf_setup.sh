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

USAGE="Usage: $0 --tf_files=file1.tf[,file2.tf...]"

# Parse arguments. Expect key and value to appear as a single argument with an
# equal sign. So "--key=value" and not "--key value".
parse_args() {
  for i in "$@"; do
    case $i in
        --tf_files=*)
        TF_FILES_CSV="${i#*=}"
        shift
        ;;
        *)
        echo "Unsupported option $i"
        return 1
        ;;
    esac
  done
  if [[ "$TF_FILES_CSV" == "" ]]; then
    echo "Missing tf_files"
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

TF_BIN="terraform"
OUTPUT_FILE="terraform.tfplan"
# All GCP provisioned resources will be tagged with this id.
SUT_ID=$(head -200 /dev/urandom | cksum | cut -f1 -d " ")
echo "terraform setup started!"

TF_DIR="/tmp/terraform_$SUT_ID/"  # terraform dedicated directory.
TF_PLAN_FILE="tf_plan"  # terraform plan output file, will be used by apply.

mkdir -p "$TF_DIR"
for tf_file in $(echo "$TF_FILES_CSV" | sed "s/,/ /g")
do
  echo -n "Copying $tf_file to $TF_DIR ... "
  cp "$tf_file" "$TF_DIR"
  echo "Done."
done

# Change to terraform directory to run terraform there.
pushd "$TF_DIR"

echo "Running terraform init..."
$TF_BIN init -no-color -input=false ./ \
  || { echo "terraform init failed."; exit 1; }

echo "Running terraform plan..."
$TF_BIN plan -no-color -input=false -out="./${TF_PLAN_FILE}" -var "sut_id=$SUT_ID" ./ \
  || { echo "terraform plan failed."; exit 1; }


echo "Prepare terraform state + downloaded plugings as output file to send to teardown stage"
tar -zcvf "$_SETUP_OUTPUT_DIR/$OUTPUT_FILE" ./

if [ $? != 0 ]; then
  echo "Was not able to copy the output file: $_SETUP_OUTPUT_DIR/$OUTPUT_FILE"
  exit 1
fi


echo "Attempting to start server with sut_id=$SUT_ID"
$TF_BIN apply -no-color -input=false "./${TF_PLAN_FILE}" \
  || { echo "terraform apply failed."; exit 1; }

ADDRESS=$(terraform output url)
echo "Server address is $ADDRESS"

# Go back to working directory
popd

# Prepare output properties
echo "sut_id=$SUT_ID" > "$_SETUP_OUTPUT"
echo "address=$ADDRESS" >> "$_SETUP_OUTPUT"

touch "$_SETUP_DONE"
exit 0
