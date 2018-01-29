"""Unit tests for integration_tests.bzl."""

load(
    ":integration_tests.bzl",
    "INTEGRATION_TEST_CONFIG_ENV_VAR",
    "INTEGRATION_TEST_TYPE_ENV_VAR",
    "IntegrationTestInfoForTest",
    "SutComponentInfo",
    "external_sut_component",
    "integration_test",
    "sut_component",
)
load(":unittest.bzl", "asserts", "unittest")

# sut_component_defaults_test tests the sut_component Rule for the most simple
# case. The case where the setup and teardown scripts are not provided, and
# there are no transitive dependencies.
def _sut_component_defaults_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(env, depset([]), provider.data)
  asserts.set_equals(
      env,
      depset(["name: \"//skylark:sut_component_defaults_subject\" " +
              "num_requested_ports: 1"]),
      provider.sut_protos)
  asserts.set_equals(env, depset([]), provider.teardowns)
  asserts.set_equals(env, depset([]), provider.setups)
  unittest.end(env)

sut_component_defaults_test = unittest.make(
    _sut_component_defaults_test_impl,
    attrs = {"dep": attr.label()},
)

def test_sut_component_defaults():
  sut_component(name = "sut_component_defaults_subject")
  sut_component_defaults_test(name = "sut_component_defaults",
                              dep = "sut_component_defaults_subject")

# set_component_with_docker_image tests the sut_component rule when there is
# a docker_image specified in the rule.
def _sut_component_with_docker_image_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(env, depset([]), provider.data)
  asserts.set_equals(
      env,
      depset(["name: \"//skylark:sut_component_with_docker_image_subject\" " +
              "docker_image: \"fakedocker:latest\" " +
              "num_requested_ports: 1"]),
      provider.sut_protos)
  unittest.end(env)

sut_component_with_docker_image_test = unittest.make(
    _sut_component_with_docker_image_test_impl,
    attrs = {"dep": attr.label()},
)

def test_sut_component_with_docker_image():
  sut_component(name = "sut_component_with_docker_image_subject",
                docker_image="fakedocker:latest")
  sut_component_with_docker_image_test(
      name = "sut_component_with_docker_image",
      dep = "sut_component_with_docker_image_subject")

# set_component_with_num_requested_ports tests the sut_component rule when there is
# a number of requested ports in the rule.
def _sut_component_with_num_requested_ports_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(env, depset([]), provider.data)
  asserts.set_equals(
      env,
      depset(["name: \"//skylark:sut_component_with_num_requested_ports_subject\" " +
              "num_requested_ports: 3"]),
      provider.sut_protos)
  unittest.end(env)

sut_component_with_num_requested_ports_test = unittest.make(
    _sut_component_with_num_requested_ports_test_impl,
    attrs = {"dep": attr.label()},
)

def test_sut_component_with_num_requested_ports():
  sut_component(name = "sut_component_with_num_requested_ports_subject",
                num_requested_ports = 3)
  sut_component_with_num_requested_ports_test(
      name = "sut_component_with_num_requested_ports",
      dep = "sut_component_with_num_requested_ports_subject")

# sut_component_with_output_properties tests the sut_component rule when there
# is a set of expected output_properties in the rule.
def _sut_component_with_output_properties_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(env, depset([]), provider.data)
  asserts.set_equals(
      env,
      depset(["name: \"//skylark:sut_component_with_output_properties_subject\" " +
              "setups {" +
                "file: \"skylark/testdata/test_setup_script.sh\" " +
                "output_properties {key: \"key_one\"}" +
              "} " +
              "num_requested_ports: 1"]),
      provider.sut_protos)
  unittest.end(env)

sut_component_with_output_properties_test = unittest.make(
    _sut_component_with_output_properties_test_impl,
    attrs = {"dep": attr.label()},
)

def test_sut_component_with_output_properties():
  sut_component(name = "sut_component_with_output_properties_subject",
                setups = [{
                    "program" : "testdata/test_setup_script.sh",
                    "output_properties" : ["key_one"],
                }])

  sut_component_with_output_properties_test(
      name = "sut_component_with_output_properties",
      dep = "sut_component_with_output_properties_subject")

# sut_component_with_output_files tests the sut_component rule when there is
# a set of expected output_files in the rule.
def _sut_component_with_output_files_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(env, depset([]), provider.data)
  asserts.set_equals(
      env,
      depset(["name: \"//skylark:sut_component_with_output_files_subject\" " +
              "setups {" +
                "file: \"skylark/testdata/test_setup_script.sh\" " +
                "output_files {filename: \"file_one\"}" +
              "} " +
              "num_requested_ports: 1"]),
      provider.sut_protos)
  unittest.end(env)

sut_component_with_output_files_test = unittest.make(
    _sut_component_with_output_files_test_impl,
    attrs = {"dep": attr.label()},
)

def test_sut_component_with_output_files():
  sut_component(name = "sut_component_with_output_files_subject",
                setups = [{
                    "program" : "testdata/test_setup_script.sh",
                    "output_files" : ["file_one"],
                }])
  sut_component_with_output_files_test(
      name = "sut_component_with_output_files",
      dep = "sut_component_with_output_files_subject")

# sut_component_transitive_with_scripts_test tests the sut_component Rule for
# the case where the setup and teardown scripts are provided, and there is one
# transitive dependency.
def _sut_component_transitive_with_scripts_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(env, depset(ctx.files.data_deps), provider.data)
  asserts.set_equals(
      env,
      depset([
          # Proto corresponding to sut_leaf_component
          "name: \"//skylark:sut_leaf_component\" " +
          "setups {file: \"skylark/testdata/test_setup_script.sh\"} " +
          "num_requested_ports: 1",
          # Proto corresponding to sut_component_transitive_with_scripts_subject
          "name: \"//skylark:sut_component_transitive_with_scripts_subject\" " +
          "setups {file: \"skylark/testdata/test_setup2_script.sh\"} " +
          "teardowns {file: \"skylark/testdata/test_teardown_script.sh\"} " +
          "sut_component_alias {target: \"//skylark:sut_leaf_component\" local_alias: \"slc\"} " +
          "num_requested_ports: 1"]),
      provider.sut_protos)
  asserts.set_equals(
      env,
      depset(ctx.files.teardowns),
      provider.teardowns)
  asserts.set_equals(
      env,
      depset(ctx.files.setups),
      provider.setups)
  unittest.end(env)

sut_component_transitive_with_scripts_test = unittest.make(
    _sut_component_transitive_with_scripts_test_impl,
    attrs = {
        "dep": attr.label(),
        "setups": attr.label_list(allow_files = True),
        "teardowns": attr.label_list(allow_files = True),
        "data_deps": attr.label_list(allow_files = True),
    },
)

def test_sut_component_transitive_with_scripts():
  """Generates subject and test rules for a sut_component unit test."""
  sut_component(name = "sut_leaf_component",
                setups = [{
                    "program" : "testdata/test_setup_script.sh",
                    "data" : ["testdata/data.txt"],
                }])
  sut_component(name = "sut_component_transitive_with_scripts_subject",
                required_sut_components = {":sut_leaf_component": "slc"},
                setups = ["testdata/test_setup2_script.sh"],
                teardowns = ["testdata/test_teardown_script.sh"],
               )
  sut_component_transitive_with_scripts_test(
      name = "sut_component_transitive_with_scripts",
      dep = "sut_component_transitive_with_scripts_subject",
      setups = ["testdata/test_setup_script.sh", "testdata/test_setup2_script.sh"],
      teardowns = ["testdata/test_teardown_script.sh"],
      data_deps = ["testdata/data.txt"])

# sut_component_diamond_test tests the sut_component rule for
# the diamond dependency case:
# SUT1 depends on SUT2 and SUT3, and SUT2 and SUT3 both depend on SUT4.
def _sut_component_diamond_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(
      env,
      depset([
          # Leaf component.
          "name: \"//skylark:sut_diamond_leaf_component\" " +
          "num_requested_ports: 1",
          # Left component.
          "name: \"//skylark:sut_diamond_left_component\" " +
          "sut_component_alias {" +
            "target: \"//skylark:sut_diamond_leaf_component\" " +
            "local_alias: \"leaf\"" +
          "} " +
          "num_requested_ports: 1",
          # Right component.
          "name: \"//skylark:sut_diamond_right_component\" " +
          "sut_component_alias {" +
            "target: \"//skylark:sut_diamond_leaf_component\" " +
            "local_alias: \"leaf\"" +
          "} " +
          "num_requested_ports: 1",
          # Top component.
          "name: \"//skylark:sut_component_diamond_subject\" " +
          "sut_component_alias {" +
            "target: \"//skylark:sut_diamond_left_component\" " +
            "local_alias: \"left\"" +
          "} " +
          "sut_component_alias {" +
            "target: \"//skylark:sut_diamond_right_component\" " +
            "local_alias: \"right\"" +
          "} " +
          "num_requested_ports: 1"]),
      provider.sut_protos)
  unittest.end(env)

sut_component_diamond_test = unittest.make(
    _sut_component_diamond_test_impl,
    attrs = {"dep": attr.label()},
)

def test_sut_component_diamond():
  """Generates subject and test rules for a sut_component unit test."""
  sut_component(name = "sut_diamond_leaf_component")
  sut_component(name = "sut_diamond_left_component",
                required_sut_components = {
                    ":sut_diamond_leaf_component": "leaf",
                })
  sut_component(name = "sut_diamond_right_component",
                required_sut_components = {
                    ":sut_diamond_leaf_component": "leaf",
                })
  sut_component(name = "sut_component_diamond_subject",
                # Does not depend directly on the leaf.
                required_sut_components = {
                    ":sut_diamond_left_component": "left",
                    ":sut_diamond_right_component": "right",
                })
  sut_component_diamond_test(
      name = "sut_component_diamond",
      dep = "sut_component_diamond_subject")

# sut_component_with_rules_test tests the sut_component rule for the case where
# the setup and teardown are provided as rules rather than as an executable
# script file.
def _sut_component_with_rules_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]

  # There should be 2 files: The original script and a copy created by the rule.
  # Is the order within the files lists deterministic?
  # I assume here that it is, but if that proves not to be the case, then this
  # code should be replaced.
  asserts.equals(env,
                 ["skylark/testdata/test_setup_script.sh",
                  "skylark/setup"],
                 [filename.short_path for filename in ctx.files.setup_files])

  asserts.equals(env,
                 ["skylark/testdata/test_teardown_script.sh",
                  "skylark/teardown"],
                 [filename.short_path for filename in ctx.files.teardown_files])
  setup = ctx.files.setup_files[1]
  teardown = ctx.files.teardown_files[1]

  asserts.set_equals(
      env,
      depset([ctx.file.data] +
             ctx.files.setup_files +
             ctx.files.teardown_files),
      provider.data)

  asserts.set_equals(
      env,
      depset([
          "name: \"//skylark:sut_component_with_rules_subject\" " +
          "setups {file: \"skylark/setup\"} " +
          "teardowns {file: \"skylark/teardown\"} " +
          "num_requested_ports: 1"]),
      provider.sut_protos)

  asserts.set_equals(env, depset([setup]), provider.setups)
  asserts.set_equals(env, depset([teardown]), provider.teardowns)
  unittest.end(env)

sut_component_with_rules_test = unittest.make(
    _sut_component_with_rules_test_impl,
    attrs = {
        "dep": attr.label(),
        "data": attr.label(allow_single_file = True),
        "setup_files": attr.label(allow_files = True),
        "teardown_files": attr.label(allow_files = True),
    },
)

###
# SUT Component Test with Rules
###
def test_sut_component_with_rules():
  """Generates subject and test rules for a sut_component unit test."""

  native.sh_binary(name = "setup",
                   srcs = ["testdata/test_setup_script.sh"],
                   data = ["testdata/data.txt"])
  native.sh_binary(name = "teardown",
                   srcs = ["testdata/test_teardown_script.sh"])
  sut_component(name = "sut_component_with_rules_subject",
                setups = [":setup"],
                teardowns = [":teardown"])

  sut_component_with_rules_test(
      name = "sut_component_with_rules",
      dep = "sut_component_with_rules_subject",
      data = "testdata/data.txt",
      # Providing the rule name in setup_files/teardown_files will set both
      # the original script (testdata/test_setup_script.sh or
      # testdata/test_teardown_script.sh) and the link to that script which
      # receives the rule name (setup or teardown).
      setup_files = "setup",
      teardown_files = "teardown")

# sut_component_with_args_test tests the sut_component rule for the case where
# the setup and teardown scripts have arguments.
def _sut_component_with_args_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(
      env,
      depset([
          "name: \"//skylark:sut_component_with_args_subject\" " +
          "setups {file: \"skylark/testdata/test_setup_script.sh\" " +
          "args: \"setup_arg1\" args: \"skylark/testdata/data.txt\"} " +
          "teardowns {file: \"skylark/testdata/test_teardown_script.sh\" " +
          "args: \"teardown_arg1\"} " +
          "num_requested_ports: 1"]),
      provider.sut_protos)
  asserts.set_equals(
      env,
      depset([ctx.file.teardown]),
      provider.teardowns)
  asserts.set_equals(
      env,
      depset([ctx.file.setup]),
      provider.setups)
  unittest.end(env)

sut_component_with_args_test = unittest.make(
    _sut_component_with_args_test_impl,
    attrs = {
        "dep": attr.label(),
        "setup": attr.label(allow_single_file = True),
        "teardown": attr.label(allow_single_file = True),
    },
)

def test_sut_component_with_args():
  """Generates subject and test rules for a sut_component unit test."""

  sut_component(name = "sut_component_with_args_subject",
                setups = [{
                    "program" : "testdata/test_setup_script.sh",
                    "args" : ["setup_arg1", "$(location testdata/data.txt)"],
                    "data" : ["testdata/data.txt"],
                    "deps" : ["testdata/data.txt"],
                }],
                teardowns = [{
                    "program" : "testdata/test_teardown_script.sh",
                    "args" : ["teardown_arg1"],
                }],
               )

  sut_component_with_args_test(name = "sut_component_with_args",
                               dep = "sut_component_with_args_subject",
                               setup = "testdata/test_setup_script.sh",
                               teardown = "testdata/test_teardown_script.sh")

# sut_component_with_input_files_test tests the sut_component rule for the
# case where setup and teardown scripts have input files.
def _sut_component_with_input_files_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(
      env,
      depset([
          "name: \"//skylark:sut_component_with_input_files_subject\" " +
          "setups {" +
            "file: \"skylark/testdata/test_setup_script.sh\" " +
            "args: \"setup_arg1\" args: \"skylark/testdata/data.txt\" " +
            "input_files {filename: \"file1\"} " +
            "input_files {filename: \"file2\"} " +
            "output_files {filename: \"file1\"} " +
            "output_files {filename: \"file2\"} " +
            "output_files {filename: \"file3\"} " +
            "output_files {filename: \"file4\"}" +
          "} " +
          "teardowns {file: \"skylark/testdata/test_teardown_script.sh\" " +
          "args: \"teardown_arg1\" " +
          "input_files {filename: \"file2\"} input_files {filename: \"file3\"}" +
          "} " +
          "num_requested_ports: 1"
      ]), provider.sut_protos)
  asserts.set_equals(env, depset([ctx.file.teardown]), provider.teardowns)
  asserts.set_equals(env, depset([ctx.file.setup]), provider.setups)
  unittest.end(env)

sut_component_with_input_files_test = unittest.make(
    _sut_component_with_input_files_test_impl,
    attrs = {
        "dep": attr.label(),
        "setup": attr.label(allow_single_file = True),
        "teardown": attr.label(allow_single_file = True),
    },
)

def test_sut_component_with_input_files():
  """Generates subject and test rules for a sut_component unit test."""

  sut_component(
      name="sut_component_with_input_files_subject",
      setups=[{
          "program" : "testdata/test_setup_script.sh",
          "args" : ["setup_arg1", "$(location testdata/data.txt)"],
          "input_files" : ["file1", "file2"],
          "data" : ["testdata/data.txt"],
          "deps" : ["testdata/data.txt"],
          "output_files" : ["file1", "file2", "file3", "file4"],
      }],
      teardowns=[{
          "program" : "testdata/test_teardown_script.sh",
          "args" : ["teardown_arg1"],
          "input_files" : ["file2", "file3"],
      }],
  )

  sut_component_with_input_files_test(
      name="sut_component_with_input_files",
      dep="sut_component_with_input_files_subject",
      setup="testdata/test_setup_script.sh",
      teardown="testdata/test_teardown_script.sh")

# sut_component_with_multiple_scripts_test tests sut_component for the case
# where setups and teardowns (in the plural) are provided instead of setup and
# teardown.
def _sut_component_with_multiple_scripts_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(
      env,
      depset([
          "name: \"//skylark:sut_component_with_multiple_scripts_subject\" " +
          "setups {file: \"skylark/testdata/test_setup_script.sh\" " +
          "args: \"setup_arg1\" args: \"skylark/testdata/data.txt\" " +
          "input_files {filename: \"file1\"} input_files {filename: \"file2\"}" +
          "} " +
          "setups {file: \"skylark/testdata/test_setup2_script.sh\"} " +
          "teardowns {file: \"skylark/testdata/test_teardown_script.sh\" " +
          "args: \"teardown_arg1\"} " +
          "num_requested_ports: 1"
      ]), provider.sut_protos)
  asserts.set_equals(env, depset(ctx.files.teardowns), provider.teardowns)
  asserts.set_equals(env, depset(ctx.files.setups), provider.setups)
  asserts.set_equals(env, depset(ctx.files.data_deps), provider.data)
  unittest.end(env)

sut_component_with_multiple_scripts_test = unittest.make(
    _sut_component_with_multiple_scripts_test_impl,
    attrs = {
        "dep": attr.label(),
        "setups": attr.label_list(allow_files = True),
        "teardowns": attr.label_list(allow_files = True),
        "data_deps": attr.label_list(allow_files = True),
    },
)

def test_sut_component_with_multiple_scripts():
  """Generates an sut_component with multiple setups."""

  sut_component(
      name="sut_component_with_multiple_scripts_subject",
      # Two setup scripts one in the dict format and one as a simple script
      # with no args/files/data
      setups=[
          {
              "program" : "testdata/test_setup_script.sh",
              "args" : ["setup_arg1", "$(location testdata/data.txt)"],
              "input_files" : ["file1", "file2"],
              "data" : ["testdata/data.txt"],
              "deps" : ["testdata/data.txt"],
          },
          "testdata/test_setup2_script.sh",
      ],
      # A single teardown script in an array format.
      teardowns=[
          {
              "program" : "testdata/test_teardown_script.sh",
              "args" : ["teardown_arg1"],
          },
      ],
  )

  sut_component_with_multiple_scripts_test(
      name="sut_component_with_multiple_scripts",
      dep="sut_component_with_multiple_scripts_subject",
      setups=["testdata/test_setup_script.sh","testdata/test_setup2_script.sh"],
      teardowns=["testdata/test_teardown_script.sh"],
      data_deps=["testdata/data.txt"],
  )

def _external_sut_component_default_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(env, depset([]), provider.data)
  asserts.set_equals(
      env,
      depset(["name: \"//skylark:external_sut_component_default_subject_prepare\" num_requested_ports: 0",
              "name: \"//skylark:external_sut_component_default_subject\" sut_component_alias " +
              "{target: \"//skylark:external_sut_component_default_subject_prepare\" local_alias: \"prep\"} " +
              "num_requested_ports: 1"]),
      provider.sut_protos)
  asserts.set_equals(env, depset([]), provider.teardowns)
  asserts.set_equals(env, depset([]), provider.setups)
  unittest.end(env)

external_sut_component_default_test = unittest.make(
    _external_sut_component_default_test_impl,
    attrs = {"dep": attr.label()},
)

def test_external_sut_component_default():
  external_sut_component(name = "external_sut_component_default_subject")
  external_sut_component_default_test(
      name = "external_sut_component_default",
      dep = "external_sut_component_default_subject")

def _external_sut_component_with_all_features_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(env, depset([ctx.file.data]), provider.data)
  asserts.set_equals(
      env,
      depset([
          # deps
          "name: \"//skylark:sut_node_component\" num_requested_ports: 1",
          # Prepare
          "name: \"//skylark:external_sut_component_with_all_features_subject_prepare\" " +
          "setups {" +
            "file: \"skylark/testdata/test_prepare_script.sh\" " +
            "args: \"prepare_arg1\" " +
            "output_properties {key: \"prepare_property_one\"} " +
            "output_files {filename: \"prepare_file_one\"}" +
          "} " +
          "teardowns {file: \"skylark/testdata/test_teardown_script.sh\" args: \"teardown_arg1\"} " +
          "docker_image: \"fakedocker:latest\" " +
          "sut_component_alias {target: \"//skylark:sut_node_component\" local_alias: \"slc\"} " +
          "num_requested_ports: 0",
          # Setup
          "name: \"//skylark:external_sut_component_with_all_features_subject\" "+
          "setups {" +
            "file: \"skylark/testdata/test_setup_script.sh\" " +
            "args: \"setup_arg1\" " +
            "output_properties {key: \"output_property_one\"} " +
            "output_files {filename: \"output_file_one\"} " +
            "output_files {filename: \"output_file_two\"}" +
          "} " +
          "docker_image: \"fakedocker:latest\" " +
          "sut_component_alias {target: \"//skylark:external_sut_component_with_all_features_subject_prepare\" local_alias: \"prep\"} " +
          "sut_component_alias {target: \"//skylark:sut_node_component\" local_alias: \"slc\"} num_requested_ports: 3"]),
      provider.sut_protos)
  asserts.set_equals(env, depset([ctx.file.teardown]), provider.teardowns)
  asserts.set_equals(env, depset([ctx.file.setup, ctx.file.prepare]), provider.setups)
  unittest.end(env)

external_sut_component_with_all_features_test = unittest.make(
    _external_sut_component_with_all_features_test_impl,
    attrs = {
        "dep": attr.label(),
        "data": attr.label(allow_single_file = True),
        "prepare": attr.label(allow_single_file = True),
        "setup": attr.label(allow_single_file = True),
        "teardown": attr.label(allow_single_file = True),
    },
)

def  test_external_sut_component_with_all_features():
  """Unit test external_sut_component with non-default values."""
  sut_component(name = "sut_node_component")
  sut_component(name = "sut_component_deps_subject")
  external_sut_component(
      name = "external_sut_component_with_all_features_subject",
      prepares = [{
          "program" : "testdata/test_prepare_script.sh",
          "args" : ["prepare_arg1"],
          "data" : ["testdata/data.txt"],
          "output_properties" : ["prepare_property_one"],
          "output_files" : ["prepare_file_one"],
      }],
      setups = [{
          "program" : "testdata/test_setup_script.sh",
          "args" : ["setup_arg1"],
          "output_properties" : ["output_property_one"],
          "output_files" : ["output_file_one", "output_file_two"],
      }],
      teardowns = [{
          "program" : "testdata/test_teardown_script.sh",
          "args" : ["teardown_arg1"],
      }],
      docker_image = "fakedocker:latest",
      required_sut_components = {":sut_node_component": "slc"},
      num_requested_ports = 3
  )
  external_sut_component_with_all_features_test(
      name = "external_sut_component_with_all_features",
      dep = "external_sut_component_with_all_features_subject",
      data = "testdata/data.txt",
      prepare = "testdata/test_prepare_script.sh",
      setup = "testdata/test_setup_script.sh",
      teardown = "testdata/test_teardown_script.sh"
  )

###
# Shell Integration Test Defaults
###
def _integration_test_test_impl(ctx):
  """Checks that the File Actions and data_runfiles are as expected."""
  env = unittest.begin(ctx)
  actions = ctx.attr.dep[Actions]
  for value in actions.by_file.values():
    if value.content:
      asserts.equals(env,
                     "#!/bin/bash\n" +
                     "/tmp/botexec/.asci-reserved/test_wrapper_script.sh \"$@\"",
                     value.content)

  default_info = ctx.attr.dep[DefaultInfo]
  expected = depset(ctx.files.data_deps)

  asserts.equals(env, len(expected) + 1, len(default_info.data_runfiles.files),
                 "data_runfiles has unexpected number of files.")

  asserts.set_subsets(env, expected, default_info.data_runfiles.files,
                      "Some data files are missing. Actual data files " +
                      "do not have all files from the Expected set." +
                      "<generated file skylark/integration_test_subject> is expected.")


  provider = ctx.attr.dep[IntegrationTestInfoForTest]
  if ctx.attr.config_proto != "":
    asserts.equals(env, ctx.attr.config_proto, provider.environment[INTEGRATION_TEST_CONFIG_ENV_VAR])
  asserts.equals(env, ctx.attr.test_type, provider.environment[INTEGRATION_TEST_TYPE_ENV_VAR])
  unittest.end(env)

# integration_test_test tests the integration_test rule for the simple case and
# the case where integration_test depends on provided SUTs.
integration_test_test = unittest.make(
    _integration_test_test_impl,
    attrs = {
        "dep": attr.label(),
        "test": attr.label(),
        "data_deps": attr.label_list(
            allow_files = True,
            mandatory = True,
        ),
        "config_proto": attr.string(),
        "test_type": attr.string(default="SINGLE_MACHINE"),
    },
)

def test_integration_test_defaults():
  """Generates subject and test rules for the simplest integration_test unit."""
  integration_test(
      name = "integration_test_defaults_subject",
      test = "testdata/test_script.txt",
      tags = ["manual"],
  )
  integration_test_test(
      name = "integration_test_defaults",
      dep = "integration_test_defaults_subject",
      data_deps = [
          "testdata/test_script.txt",
      ]
  )

def test_integration_test_with_suts():
  """Generates test rules for a integration_test which depends on a SUTC."""
  sut_component(
      name = "integration_test_sut",
      setups = [{
          "program" : "testdata/test_setup_script.sh",
          "output_files" : ["file1", "file2"],
      }],
      teardowns = [{
          "program" : "testdata/test_teardown_script.sh",
          "data" : ["testdata/sutc_data.txt"],
      }],
  )
  integration_test(
      name = "integration_test_subject",
      test = {
          "program" : "testdata/test_script.txt",
          "args" : ["arg1", "arg2"],
          "input_files" : ["file1"],
          "data" : ["testdata/data.txt"],
      },
      suts = {":integration_test_sut": "sits"},
      test_timeout = 10,
      tags = ["manual"],
  )
  integration_test_test(
      name = "integration_test_with_suts",
      dep = "integration_test_subject",
      data_deps = [
          "testdata/test_script.txt",
          "testdata/data.txt",
          "testdata/test_setup_script.sh",
          "testdata/test_teardown_script.sh",
          "testdata/sutc_data.txt",
      ],
      config_proto = (
        "name: \"integration_test_subject\" " +
        "sut_component_alias {" +
          "target: \"//skylark:integration_test_sut\" " +
          "local_alias: \"sits\"" +
        "} " +
        "components {" +
          "name: \"//skylark:integration_test_sut\" " +
          "setups {" +
            "file: \"skylark/testdata/test_setup_script.sh\" " +
            "output_files {filename: \"file1\"} " +
            "output_files {filename: \"file2\"}" +
          "} " +
          "teardowns {file: \"skylark/testdata/test_teardown_script.sh\"} " +
          "num_requested_ports: 1" +
        "} " +
        "timeout_seconds: \"10\" " +
        "test_type: SINGLE_MACHINE " +
        "test_executable {" +
          "file: \"skylark/testdata/test_script.txt\" " +
          "args: \"arg1\" args: \"arg2\" " +
          "input_files {filename: \"file1\"}" +
        "}"
      ),
  )

def test_integration_test_with_pretests():
  """Generates test rules for a integration_test which has pretests."""
  integration_test(
      name = "integration_test_with_pretests_subject",
      pretests = [
          # One pretest is provided as a dict, the second is a string.
          {
            "program" : "testdata/test_setup_script.sh",
            "args" : ["arg1", "arg2"],
            "input_files" : ["file1"],
          },
          "testdata/test_setup2_script.sh",
      ],
      test = "testdata/test_script.txt",
      tags = ["manual"],
  )
  integration_test_test(
      name = "integration_test_with_pretests",
      dep = "integration_test_with_pretests_subject",
      data_deps = [
          "testdata/test_script.txt",
          # Despite the file name, these are actually pretests, not SUT setups.
          "testdata/test_setup_script.sh",
          "testdata/test_setup2_script.sh",
      ],
      config_proto = (
        "name: \"integration_test_with_pretests_subject\" " +
        "test_type: SINGLE_MACHINE " +
        "pretest_executables {" +
          "file: \"skylark/testdata/test_setup_script.sh\" " +
          "args: \"arg1\" args: \"arg2\" " +
          "input_files {filename: \"file1\"}" +
        "} " +
        "pretest_executables {file: \"skylark/testdata/test_setup2_script.sh\"} " +
        "test_executable {file: \"skylark/testdata/test_script.txt\"}"
      ),
  )

def test_integration_test_with_diamond_deps():
  """Generates test rules for an integration_test with a diamond dependency."""
  sut_component(name = "integration_test_with_diamond_deps_leaf_sutc")
  sut_component(name = "integration_test_with_diamond_deps_left_sutc",
                required_sut_components = {
                    ":integration_test_with_diamond_deps_leaf_sutc": "leaf",
                })
  sut_component(name = "integration_test_with_diamond_deps_right_sutc",
                required_sut_components = {
                    ":integration_test_with_diamond_deps_leaf_sutc": "leaf",
                })
  integration_test(
      name = "test_integration_test_with_diamond_deps_subject",
      test = "testdata/test_script.txt",
      suts = {
          ":integration_test_with_diamond_deps_left_sutc": "left",
          ":integration_test_with_diamond_deps_right_sutc": "right",
      },
      test_timeout = 10,
      tags = ["manual"],
      test_type = "MultiMachine"
  )
  integration_test_test(
      name = "integration_test_with_diamond_deps",
      dep = "test_integration_test_with_diamond_deps_subject",
      data_deps = [
          "testdata/test_script.txt",
      ],
      config_proto = (
          "name: \"test_integration_test_with_diamond_deps_subject\" " +
          # Test level aliases.
          "sut_component_alias {" +
            "target: \"//skylark:integration_test_with_diamond_deps_left_sutc\" " +
            "local_alias: \"left\"" +
          "} " +
          "sut_component_alias {" +
            "target: \"//skylark:integration_test_with_diamond_deps_right_sutc\" " +
            "local_alias: \"right\"" +
          "} " +
          # Leaf.
          "components {" +
            "name: \"//skylark:integration_test_with_diamond_deps_leaf_sutc\" " +
            "num_requested_ports: 1" +
          "} " +
          # Left.
          "components {" +
            "name: \"//skylark:integration_test_with_diamond_deps_left_sutc\" " +
            "sut_component_alias {" +
              "target: \"//skylark:integration_test_with_diamond_deps_leaf_sutc\" " +
              "local_alias: \"leaf\"" +
            "} " +
            "num_requested_ports: 1" +
          "} " +
          # Right.
          "components {" +
            "name: \"//skylark:integration_test_with_diamond_deps_right_sutc\" " +
            "sut_component_alias {" +
              "target: \"//skylark:integration_test_with_diamond_deps_leaf_sutc\" " +
              "local_alias: \"leaf\"" +
            "} " +
            "num_requested_ports: 1" +
          "} " +
          # Other test fields.
          "timeout_seconds: \"10\" " +
          "test_type: MULTI_MACHINE " +
          "test_executable {" +
            "file: \"skylark/testdata/test_script.txt\"" +
          "}"
      ),
      test_type = "MULTI_MACHINE",
  )

def external_sut_component_test_suite():
  test_external_sut_component_default()
  test_external_sut_component_with_all_features()

  native.test_suite(
      name = "external_sut_component_test",
      tests = [
          "external_sut_component_default",
          "external_sut_component_with_all_features",
      ],
  )

def sut_component_test_suite():
  """Runs all unit tests related to sut_component rule in this file."""
  test_sut_component_defaults()
  test_sut_component_transitive_with_scripts()
  test_sut_component_diamond()
  test_sut_component_with_rules()
  test_sut_component_with_docker_image()
  test_sut_component_with_num_requested_ports()
  test_sut_component_with_args()
  test_sut_component_with_input_files()
  test_sut_component_with_multiple_scripts()
  test_sut_component_with_output_properties()
  test_sut_component_with_output_files()

  native.test_suite(
      name = "sut_component_test",
      tests = [
          "sut_component_defaults",
          "sut_component_transitive_with_scripts",
          "sut_component_diamond",
          "sut_component_with_rules",
          "sut_component_with_docker_image",
          "sut_component_with_num_requested_ports",
          "sut_component_with_args",
          "sut_component_with_input_files",
          "sut_component_with_output_properties",
          "sut_component_with_output_files",
      ],
  )

def integration_test_test_suite():
  """Runs all unit tests related to integration_test rule in this file."""
  test_integration_test_defaults()
  test_integration_test_with_suts()
  test_integration_test_with_pretests()
  test_integration_test_with_diamond_deps()

  native.test_suite(
      name = "integration_test_test",
      tests = [
          "integration_test_defaults",
          "integration_test_with_suts",
      ],
  )
