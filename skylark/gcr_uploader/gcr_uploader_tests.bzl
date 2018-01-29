"""Unit tests for gcr_uploader.bzl."""

load(
    "//skylark:integration_tests.bzl",
    "SutComponentInfo"
)
load(
    ":gcr_uploader.bzl",
    "gcr_uploader_sut_component",
)
load("//skylark:unittest.bzl", "asserts", "unittest")
load("//skylark:toolchains.bzl", "toolchain_container_images")

# gcr_uploader_sut_component_basic_test tests the gcr_uploader_sut_component rule and makes sure
# that it converts correctly into an underlying sut_component by examining the
# SutComponentInfo output of the rule.
def _gcr_uploader_sut_component_basic_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  expected_files = ",".join(ctx.attr.files)
  asserts.set_equals(
      env,
      depset([
          "name: \"" + ctx.attr.rule_name + "_prepare\" " +
          "setups {" +
            "file: \"skylark/gcr_uploader/generate_image_name.sh\" " +
            "args: \"--project_id=" + ctx.attr.project_id + "\" " +
            "args: \"--image_name=" + ctx.attr.image_name + "\" " +
            "output_properties {key: \"image\"}" +
          "} " +
          "teardowns {" +
            "file: \"skylark/gcr_uploader/delete_image.sh\" " +
            "args: \"{image}\"" +
          "} " +
          "docker_image: \"" + toolchain_container_images()["rbe-integration-test"] + "\" " +
          "num_requested_ports: 0",

          "name: \"" + ctx.attr.rule_name + "\" " +
          "setups {" +
            "file: \"skylark/gcr_uploader/create_and_upload_image.sh\" " +
            "args: \"--base_image=" + ctx.attr.base_image + "\" " +
            "args: \"--directory=" + ctx.attr.directory + "\" " +
            "args: \"--files=" + expected_files + "\" " +
            "args: \"--new_image={prep#image}\" " +
            "output_properties {key: \"image\"}" +
          "} " +
          "docker_image: \"" + toolchain_container_images()["rbe-integration-test"] + "\" " +
          "sut_component_alias {" +
            "target: \"" + ctx.attr.rule_name + "_prepare\" " +
            "local_alias: \"prep\"" +
          "} " +
          "num_requested_ports: 1"
      ]),
      provider.sut_protos)
  asserts.set_equals(
      env,
      depset([ctx.file.prepare, ctx.file.setup]),
      provider.setups)
  asserts.set_equals(
      env,
      depset([ctx.file.teardown]),
      provider.teardowns)
  asserts.set_equals(env,
                     depset(ctx.files.data),
                     provider.data)
  unittest.end(env)

gcr_uploader_sut_component_basic_test = unittest.make(
    _gcr_uploader_sut_component_basic_test_impl,
    attrs={"dep": attr.label(),
           "rule_name" : attr.string(),
           "prepare": attr.label(allow_single_file = True),
           "setup": attr.label(allow_single_file = True),
           "teardown": attr.label(allow_single_file = True),
           "base_image": attr.string(),
           "directory": attr.string(),
           "data": attr.label_list(allow_files = True),
           "files": attr.string_list(),
           "project_id": attr.string(),
           "image_name": attr.string()}
)

def test_gcr_uploader_sut_component_basic():
  """Generates a basic gcr_uploader_sut_component."""

  base_image = "gcr.io/base_project/img"
  directory = "/path/to/dir/in/container"
  project_id = "dummy_proj"
  image_name = "gcr.io/new_project/prefix_of_new_image"

  gcr_uploader_sut_component(
      name = "gcr_uploader_sut_component_basic_subject",
      base_image = base_image,
      directory = directory,
      files = [
        "testdata/file1.txt",
        "testdata/file2.txt",
      ],
      project_id = project_id,
      image_name = image_name
  )

  gcr_uploader_sut_component_basic_test(
      name = "gcr_uploader_sut_component_basic",
      dep = "gcr_uploader_sut_component_basic_subject",
      rule_name = "//skylark/gcr_uploader:gcr_uploader_sut_component_basic_subject",
      prepare = "generate_image_name.sh",
      setup = "create_and_upload_image.sh",
      teardown = "delete_image.sh",
      base_image = base_image,
      directory = directory,
      data = [
          "testdata/file1.txt",
          "testdata/file2.txt",
      ],
      files = [
          "skylark/gcr_uploader/testdata/file1.txt",
          "skylark/gcr_uploader/testdata/file2.txt",
      ],
      project_id = project_id,
      image_name = image_name)

def gcr_uploader_sut_component_test_suite():
  test_gcr_uploader_sut_component_basic()

  native.test_suite(
      name = "gcr_uploader_sut_component_test",
      tests = [
          "gcr_uploader_sut_component_basic",
      ],
  )
