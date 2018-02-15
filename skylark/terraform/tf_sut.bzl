"""Skylark extension for terraform_sut_component."""

load("//skylark:toolchains.bzl", "toolchain_container_images")
load("//skylark:integration_tests.bzl", "sut_component")

def terraform_sut_component(name, tf_files, setup_timeout_seconds=None, teardown_timeout_seconds=None):
  # Create a list of terraform file locations.
  tf_files_loc = ",".join(["$(location %s)" % tf_file for tf_file in tf_files])

  # Creating the underlying sut_component rule.
  sut_component(
      name = name,
      docker_image = toolchain_container_images()["rbe-integration-test"],
      setups = [{
          # The str(Label(...)) is necessary for proper namespace resolution in
          # cases where this repo is imported from another repo.
          "program" : str(Label("//skylark/terraform:tf_setup.sh")),
          "args" : ["--tf_files=%s" % tf_files_loc],
          "data" : tf_files, # for runtime.
          "deps" : tf_files, # for $location extraction in build time.
          "output_properties" : [
              "sut_id",
              "address",
          ],
          "output_files" : [
              "terraform.tfplan",
          ],
          "timeout_seconds" : setup_timeout_seconds,
      }],
      teardowns = [{
          "program" : str(Label("//skylark/terraform:tf_teardown.sh")),
          "args" : [
              "{sut_id}",
          ],
          "input_files" : [
              "{terraform.tfplan}",
          ],
          "timeout_seconds" : teardown_timeout_seconds,
      }],
  )
