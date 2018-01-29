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

USAGE="Usage: $0 --base_image=base_image --directory=directory --files=file1,file2,... --new_image=new_image"

# Parse arguments. Expect key and value to appear as a single argument with an
# equal sign. So "--key=value" and not "--key value".
parse_args() {
  for i in "$@"; do
    case $i in
        --base_image=*)
        BASE_IMAGE="${i#*=}"
        shift
        ;;
        --directory=*)
        DIRECTORY="${i#*=}"
        shift
        ;;
        --files=*)
        FILES_CSV="${i#*=}"
        shift
        ;;
        --new_image=*)
        NEW_IMAGE="${i#*=}"
        shift
        ;;
        *)
        echo "Unsupported option $i"
        return 1
        ;;
    esac
  done
  if [[ "$BASE_IMAGE" == "" ]]; then
    echo "Missing base_image"
    return 1
  fi
  if [[ "$DIRECTORY" == "" ]]; then
    echo "Missing directory"
    return 1
  fi
  if [[ "$FILES_CSV" == "" ]]; then
    echo "Missing files"
    return 1
  fi
  if [[ "$NEW_IMAGE" == "" ]]; then
    echo "Missing banew_imagese_image"
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
DOCKER_BIN="docker"

echo "Checking that files exist ..."
IFS=, read -r -a FILES <<<"$FILES_CSV"
for FILE in "${FILES[@]}"; do
  if [ ! -f "$FILE" ]; then
    echo "File $FILE does not exist"
    exit 1
  fi
done

echo "Creating temp directory ..."
CONETXT_DIR=$(mktemp -d)
FILES_DIR=${CONETXT_DIR}/files
mkdir $FILES_DIR

# Copy files to $FILES_DIR. We lose the full path of these files and retain
# only the file name. The files are assumed to have distinct file names after
# peeling off the path name (we don't verify this here).
echo "Copying files to context directory ..."
for FILE in "${FILES[@]}"; do
  cp $FILE $FILES_DIR
done

# Create a dockerfile.
echo "Creating Dockerfile ..."
DOCKER_FILE="${CONETXT_DIR}/Dockerfile"
echo "FROM $BASE_IMAGE" > $DOCKER_FILE
echo "COPY files/* $DIRECTORY" >> $DOCKER_FILE

# Build the docker file
echo "Building docker image ..."
$DOCKER_BIN build -t $NEW_IMAGE $CONETXT_DIR \
  || { echo "Failed to build docker image from Dockerfile."; exit 1; }

# Push the docker image
echo "pushing docker image ..."
PUSH_OUTPUT=${CONETXT_DIR}/push.out
$GCLOUD_BIN docker -- push $NEW_IMAGE | tee $PUSH_OUTPUT

# Get the sha key
SHA_KEY="$(grep -o "sha256:[0-9a-f]\{64\}" $PUSH_OUTPUT)"
if [[ "$SHA_KEY" = "" ]]; then
  echo "Failed to get SHA key of uploaded image."
  exit 1
fi

echo "Uploaded ${NEW_IMAGE}@${SHA_KEY}"
echo "image=${NEW_IMAGE}@${SHA_KEY}" >> "$_SETUP_OUTPUT"
touch "$_SETUP_DONE"
