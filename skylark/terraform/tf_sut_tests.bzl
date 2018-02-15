"""Unit tests for tf_sut.bzl."""

load(
    "//skylark:integration_tests.bzl",
    "sut_component",
    "SutComponentInfo"
)
load(
    ":tf_sut.bzl",
    "terraform_sut_component",
)
load("//skylark:sets.bzl", "sets")
load("//skylark:unittest.bzl", "asserts", "unittest")
load("//skylark:toolchains.bzl", "toolchain_container_images")

# terraform_sut_component_basic_test tests the terraform_sut_component rule
# and makes sure that it converts correctly into an underlying sut_component by
# examining the SutComponentInfo output of the rule.
def _terraform_sut_component_basic_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(
      env,
      depset([
          "name: \"//skylark/terraform:terraform_sut_component_basic_subject\" " +
          "setups {" +
            "file: \"skylark/terraform/tf_setup.sh\" " +
            "timeout_seconds: 30 " +
            "args: \"--tf_files=skylark/terraform/testdata/main.tf,skylark/terraform/testdata/variables.tf,skylark/terraform/testdata/outputs.tf\" " +
            "output_properties {key: \"sut_id\"} " +
            "output_properties {key: \"address\"} " +
            "output_files {filename: \"terraform.tfplan\"}" +
          "} " +
          "teardowns {" +
            "file: \"skylark/terraform/tf_teardown.sh\" " +
            "timeout_seconds: 30 " +
            "args: \"{sut_id}\" " +
            "input_files {filename: \"{terraform.tfplan}\"}" +
          "} " +
          "docker_image: \"" + toolchain_container_images()["rbe-integration-test"] + "\" " +
          "num_requested_ports: 1"
      ]),
      provider.sut_protos)
  asserts.set_equals(
      env,
      depset([ctx.file.setup]),
      provider.setups)
  asserts.set_equals(
      env,
      depset([ctx.file.teardown]),
      provider.teardowns)
  unittest.end(env)

terraform_sut_component_basic_test = unittest.make(
    _terraform_sut_component_basic_test_impl,
    attrs={"dep": attr.label(),
           "setup": attr.label(allow_single_file = True),
           "teardown": attr.label(allow_single_file = True)}
)

def test_terraform_sut_component_basic():
  """Generates a subject rule for a terraform_sut_component unit test."""

  terraform_sut_component(
      name = "terraform_sut_component_basic_subject",
      tf_files = [
          "testdata/main.tf",
          "testdata/variables.tf",
          "testdata/outputs.tf",
      ],
  )

  terraform_sut_component_basic_test(name = "terraform_sut_component_basic",
                                     dep = "terraform_sut_component_basic_subject",
                                     setup = "tf_setup.sh",
                                     teardown = "tf_teardown.sh")

# terraform_sut_component_with_timeout_test tests the terraform_sut_component
# rule and makes sure that it passes the timeouts correctly.
def _terraform_sut_component_with_timeout_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(
      env,
      depset([
          "name: \"//skylark/terraform:terraform_sut_component_with_timeout_subject\" " +
          "setups {" +
            "file: \"skylark/terraform/tf_setup.sh\" " +
            "timeout_seconds: 90 " +
            "args: \"--tf_files=skylark/terraform/testdata/main.tf,skylark/terraform/testdata/variables.tf,skylark/terraform/testdata/outputs.tf\" " +
            "output_properties {key: \"sut_id\"} " +
            "output_properties {key: \"address\"} " +
            "output_files {filename: \"terraform.tfplan\"}" +
          "} " +
          "teardowns {" +
            "file: \"skylark/terraform/tf_teardown.sh\" " +
            "timeout_seconds: 180 " +
            "args: \"{sut_id}\" " +
            "input_files {filename: \"{terraform.tfplan}\"}" +
          "} " +
          "docker_image: \"" + toolchain_container_images()["rbe-integration-test"] + "\" " +
          "num_requested_ports: 1"
      ]),
      provider.sut_protos)
  asserts.set_equals(
      env,
      depset([ctx.file.setup]),
      provider.setups)
  asserts.set_equals(
      env,
      depset([ctx.file.teardown]),
      provider.teardowns)
  unittest.end(env)

terraform_sut_component_with_timeout_test = unittest.make(
    _terraform_sut_component_with_timeout_test_impl,
    attrs={"dep": attr.label(),
           "setup": attr.label(allow_single_file = True),
           "teardown": attr.label(allow_single_file = True)}
)

def test_terraform_sut_component_with_timeout():
  """Generates a subject rule with a timeout for a terraform_sut_component."""

  terraform_sut_component(
      name = "terraform_sut_component_with_timeout_subject",
      tf_files = [
          "testdata/main.tf",
          "testdata/variables.tf",
          "testdata/outputs.tf",
      ],
      setup_timeout_seconds = 90,
      teardown_timeout_seconds = 180,
  )

  terraform_sut_component_with_timeout_test(
      name = "terraform_sut_component_with_timeout",
      dep = "terraform_sut_component_with_timeout_subject",
      setup = "tf_setup.sh",
      teardown = "tf_teardown.sh"
  )

def terraform_sut_component_test_suite():
  test_terraform_sut_component_basic()
  test_terraform_sut_component_with_timeout()

  native.test_suite(
      name = "terraform_sut_component_test",
      tests = [
          "terraform_sut_component_basic",
          "terraform_sut_component_with_timeout",
      ],
  )
