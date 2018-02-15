"""Unit tests for image_uploader.bzl."""

load(
    "//skylark:integration_tests.bzl",
    "SutComponentInfo"
)
load(
    ":image_uploader.bzl",
    "image_uploader_sut_component",
)
load("//skylark:unittest.bzl", "asserts", "unittest")
load("//skylark:toolchains.bzl", "toolchain_container_images")

# image_uploader_sut_component_basic_test tests the image_uploader_sut_component
# rule and makes sure that it converts correctly into an underlying
# sut_component by examining the SutComponentInfo output of the rule.
def _image_uploader_sut_component_basic_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(
      env,
      depset([
          "name: \"" + ctx.attr.rule_name + "_prepare\" " +
          "setups {" +
            "file: \"skylark/image_uploader/generate_image_name.sh\" " +
            "timeout_seconds: 3 " +
            "args: \"--registry\" args: \"" + ctx.attr.registry + "\" " +
            "args: \"--repository\" args: \"" + ctx.attr.repository + "\" " +
            "output_properties {key: \"image\"}" +
          "} " +
          "teardowns {" +
            "file: \"skylark/image_uploader/delete_image.sh\" " +
            "timeout_seconds: 60 " +
            "args: \"{image}\"" +
          "} " +
          "docker_image: \"" + toolchain_container_images()["rbe-integration-test"] + "\" " +
          "num_requested_ports: 0",

          "name: \"" + ctx.attr.rule_name + "\" " +
          "setups {" +
            "file: \"skylark/image_uploader/create_and_upload_image.sh\" " +
            "timeout_seconds: 600 " +
            "args: \"--base_image\" args: \"" + ctx.attr.base_image + "\" " +
            "args: \"--directory\" args: \"" + ctx.attr.directory + "\" " +
            "".join(["args: \"--file\" args: \"%s\" " % f for f in ctx.attr.files]) +
            "args: \"--new_image\" args: \"{prep#image}\" " +
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

image_uploader_sut_component_basic_test = unittest.make(
    _image_uploader_sut_component_basic_test_impl,
    attrs={"dep": attr.label(),
           "rule_name" : attr.string(),
           "prepare": attr.label(allow_single_file = True),
           "setup": attr.label(allow_single_file = True),
           "teardown": attr.label(allow_single_file = True),
           "base_image": attr.string(),
           "directory": attr.string(),
           "data": attr.label_list(allow_files = True),
           "files": attr.string_list(),
           "registry": attr.string(),
           "repository": attr.string()}
)

def test_image_uploader_sut_component_basic():
  """Generates a basic image_uploader_sut_component."""

  base_image = "gcr.io/base_project/img"
  directory = "/path/to/dir/in/container/"
  registry = "gcr.io"
  repository = "new_project/prefix_of_new_image"

  image_uploader_sut_component(
      name = "image_uploader_sut_component_basic_subject",
      base_image = base_image,
      directory = directory,
      files = [
        "testdata/file1.txt",
        "testdata/file2.txt",
      ],
      registry = registry,
      repository = repository
  )

  image_uploader_sut_component_basic_test(
      name = "image_uploader_sut_component_basic",
      dep = "image_uploader_sut_component_basic_subject",
      rule_name = "//skylark/image_uploader:image_uploader_sut_component_basic_subject",
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
          "skylark/image_uploader/testdata/file1.txt",
          "skylark/image_uploader/testdata/file2.txt",
      ],
      registry = registry,
      repository = repository)

def image_uploader_sut_component_test_suite():
  test_image_uploader_sut_component_basic()

  native.test_suite(
      name = "image_uploader_sut_component_test",
      tests = [
          "image_uploader_sut_component_basic",
      ],
  )
