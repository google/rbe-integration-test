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

"""Skylark extension for GCR image uploading."""

load("//skylark:toolchains.bzl", "toolchain_container_images")
load("//skylark:integration_tests.bzl", "external_sut_component")

def gcr_uploader_sut_component(
    name,
    base_image,
    directory,
    files,
    project_id,
    image_name):
  """SUT that uploads a docker image to GCR and then deletes it.

  gcr_uploader_sut_component is a skylark macro that wraps an
  external_sut_component which uploads a docker image to GCR and deletes it at
  teardown.

  Args:
    name: The name of the SUT.
    base_image: The image that we add files to (must be in GCR).
    directory: A directory that does not exist in base_image. The new files will
               be copied into this directory to create the new image.
    files: Files to be copied to base_image. The files' name (after removing the
           directory names) must be unique.
    project_id: The GCP project.
    image_name: The new image name.
  """

  _verify_files(files)

  file_csv = ",".join(["$(rootpath %s)" % file for file in files])

  bi = base_image[9:] if base_image.startswith("docker://") else base_image
  if not bi.startswith("gcr.io/"):
    fail("Error: base_image %s must start with \"gcr.io\". That is the only repository currently supported." % base_image)

  # Creating the underlying external_sut_component rule.
  # The prepare stage creates an image name which is necessary for guaranteed
  # teardown even in the case where setup pushes an image and crashes.
  external_sut_component(
      name = name,
      docker_image = toolchain_container_images()["rbe-integration-test"],
      prepares = [{
          "program" : str(Label("//skylark/gcr_uploader:generate_image_name.sh")),
          "args" : [
              "--project_id=" + project_id,
              "--image_name=" + image_name,
          ],
          "output_properties" : ["image"],
      }],
      setups = [{
          "program" : str(Label("//skylark/gcr_uploader:create_and_upload_image.sh")),
          "args" : [
              "--base_image=" + bi,
              "--directory=" + directory,
              "--files=" + file_csv,
              "--new_image={prep#image}",
          ],
          "data" : files,
          "deps" : files,
          "output_properties" : [
              "image", # The image we get from prep plus a SHA key.
          ],
      }],
      teardowns = [{
          "program" : str(Label("//skylark/gcr_uploader:delete_image.sh")),
          "args" : ["{image}"],
      }],
  )

def _is_list_of_strings(potential_list):
  # isinstance is not supported in skylark
  # pylint: disable=unidiomatic-typecheck
  if type(potential_list) != "list":
    return False

  for item in potential_list:
    # isinstance is not supported in skylark
    # pylint: disable=unidiomatic-typecheck
    if type(item) != "string":
      return False

  return True


def _verify_files(files):
  if not _is_list_of_strings(files):
    fail("Error: files %s is not a list of strings." % files)

  if len(files) == 0:
    fail("Error: No files were specified.")

  # file names (after peeling off full paths) must not conflict.
  for file1, file2 in [(files[f1], files[f2]) for f1 in range(len(files)) for f2 in range(f1+1,len(files))]:
    if _get_file_name(file1) == _get_file_name(file2):
      fail("Error: File names must be distict. %s and %s have the same file name." % (file1, file2))

def _get_file_name(path):
  p = path[1:] if path.startswith(":") else path
  return p.split("/")[-1]
