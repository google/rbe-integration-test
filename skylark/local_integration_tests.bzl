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

"""
   Skylark BUILD extensions for Integration Test

"""

# Provider for Executable Proto messages, for passing along to the sut_component
# rule and the integration_test rule.
# pylint: disable=invalid-name
ItExecutableInfo = provider(
    fields = [
        "program",
        "program_file",
        "data",
        "output_properties",
        "output_files",
        "executable_proto",
    ],
)

def _integration_test_executable_impl(ctx):
  # Create an Executable proto message from ctx.attr.program, ctx.attr.args and
  # ctx.attr.input_files. This proto message is from system_under_test.proto.
  executable_proto = "file: \"%s\"%s%s%s%s" % (
      ctx.executable.program.short_path,
      "".join([" args: \"%s\"" % ctx.expand_location(arg) for arg in ctx.attr.args]),
      "".join([" input_files {filename: \"%s\"}" % fname for fname in ctx.attr.input_files]),
      "".join([" output_properties {key: \"%s\"}" % fname for fname in ctx.attr.output_properties]),
      "".join([" output_files {filename: \"%s\"}" % fname for fname in ctx.attr.output_files]))

  return [ItExecutableInfo(program = ctx.attr.program,
                           program_file = ctx.executable.program,
                           data = depset(ctx.files.data),
                           output_properties = ctx.attr.output_properties,
                           output_files = ctx.attr.output_files,
                           executable_proto = executable_proto)]

# Private rule to be used only from the sut_component macro.
_integration_test_executable = rule(
    attrs = {
        "program": attr.label(
            mandatory = True,
            allow_files = True,
            executable = True,
            cfg = "target",
        ),
        "args": attr.string_list(),
        "input_files": attr.string_list(),
        "data": attr.label_list(allow_files = True),
        "deps": attr.label_list(allow_files = True),
        "output_properties": attr.string_list(),
        "output_files": attr.string_list(),
    },
    implementation = _integration_test_executable_impl,
)

# Provider for Sut Component Proto files, for passing along to the
# integration_test rule.
# pylint: disable=invalid-name
SutComponentInfo = provider(fields =
    [
        "sut_protos",
        "setups",
        "teardowns",
        "data",
    ],
 )
# Provider to help testing integration_test.
# pylint: disable=invalid-name
IntegrationTestInfoForTestInfo = provider(fields =
    [
        "environment",
    ]
)
PREPARE_PHASE_SUFFIX = "_prepare"
INTEGRATION_TEST_CONFIG_ENV_VAR = "IntegrationTestConfig"
INTEGRATION_TEST_TYPE_ENV_VAR = "IntegrationTestType"

def _get_transitive_sutcs(required_sut_components):
  trans_sut_proto = depset()
  trans_setup = depset()
  trans_teardown = depset()
  trans_data = depset()
  for sutc in required_sut_components:
    trans_sut_proto += sutc[SutComponentInfo].sut_protos
    trans_setup += sutc[SutComponentInfo].setups
    trans_teardown += sutc[SutComponentInfo].teardowns
    trans_data += sutc[SutComponentInfo].data
  return struct(sut_protos = trans_sut_proto,
                setups = trans_setup,
                teardowns = trans_teardown,
                data = trans_data)

def _sut_component_rule_impl(ctx):
  out_proto_list = ["name: \"%s\"" % (ctx.label)]

  trans_data = depset([])
  trans_setup = depset([])
  for setup in ctx.attr.setups:
    out_proto_list.append("setups {%s}" % setup[ItExecutableInfo].executable_proto)
    trans_setup += depset([setup[ItExecutableInfo].program_file])
    # Add the data files specified in the setup ItExecutableInfo and in its
    # target.
    trans_data += setup[ItExecutableInfo].data
    trans_data += setup[ItExecutableInfo].program[DefaultInfo].data_runfiles.files

  trans_teardown = depset([])
  for teardown in ctx.attr.teardowns:
    out_proto_list.append("teardowns {%s}" % teardown[ItExecutableInfo].executable_proto)
    trans_teardown += depset([teardown[ItExecutableInfo].program_file])
    # Add the data files specified in the teardown ItExecutableInfo and in its
    # target.
    trans_data += teardown[ItExecutableInfo].data
    trans_data += teardown[ItExecutableInfo].program[DefaultInfo].data_runfiles.files

  if ctx.attr.docker_image:
    out_proto_list.append(
        "docker_image: \"%s\"" % ctx.attr.docker_image)

  for sutc_key in ctx.attr.required_sut_components:
    out_proto_list.append("sut_component_alias {target: \"%s\" local_alias: \"%s\"}"
                          % (sutc_key.label, ctx.attr.required_sut_components[sutc_key]))

  out_proto_list.append("num_requested_ports: %d" % ctx.attr.num_requested_ports)

  trans_sut_proto = depset([" ".join(out_proto_list)])

  trans_sutcs = _get_transitive_sutcs(ctx.attr.required_sut_components)
  trans_sut_proto += trans_sutcs.sut_protos
  trans_data += trans_sutcs.data
  trans_setup += trans_sutcs.setups
  trans_teardown += trans_sutcs.teardowns

  return [SutComponentInfo(sut_protos = trans_sut_proto,
                           setups = trans_setup,
                           teardowns = trans_teardown,
                           data = trans_data)]

# An internal rule to be used only from the sut_component macro.
_sut_component = rule(
    attrs = {
        "setups": attr.label_list(providers = [ItExecutableInfo]),
        "teardowns": attr.label_list(providers = [ItExecutableInfo]),
        "docker_image": attr.string(),
        "required_sut_components": attr.label_keyed_string_dict(
            providers = [SutComponentInfo],
            cfg = "target"),
        "num_requested_ports": attr.int(default=1),
    },
    implementation = _sut_component_rule_impl,
)

def _create_integration_test_executable(
    orig_target_name,
    target_suffix,
    executable):
  """Create _integration_test_executable rule and return its names.

  Args:
    orig_target_name: The name given to the sut_component or the
      integration_test.
    target_suffix: A suffix to append to the orig_target_name to make a unique
      target name for the _integration_test_executable.
    executable: Can be either a string, which is interpretted as a program,
      or a dictionary that has a mandatory "program" field (whose value is a
      string), and some optional fields.

  Returns:
    The target name of the _integration_test_executable rule.

  """

  # Create a target name for the _integration_test_executable rule.
  target_name = "_%s_%s" % (orig_target_name, target_suffix)

  # isinstance is not supported in skylark
  # pylint: disable=unidiomatic-typecheck
  if type(executable) == "string":
    _integration_test_executable(
        name = target_name,
        program = executable,
    )
    return target_name

  # Validate that executable is a valid dictionary.

  # isinstance is not supported in skylark
  # pylint: disable=unidiomatic-typecheck
  if type(executable) != "dict":
    fail("Error in target %s: %s is neither a string nor a dictionary." % (orig_target_name, target_suffix))

  for key in executable:
    if key not in ["program", "args", "input_files", "data", "deps", "output_properties", "output_files"]:
      fail("Error in target %s: %s has an invalid key %s." % (orig_target_name, target_suffix, key))

  _integration_test_executable(
      name = target_name,
      program = executable.get("program"),
      args = executable.get("args"),
      input_files = executable.get("input_files"),
      data = executable.get("data"),
      deps = executable.get("deps"),
      output_properties = executable.get("output_properties"),
      output_files = executable.get("output_files"),
  )
  return target_name

def _create_integration_test_executables(
    orig_target_name,
    executable_type,
    executables):
  """Create _integration_test_executable rules and return their names.

  Args:
    orig_target_name: The name given to the sut_component.
    executable_type: "setup", "teardown" or "pretest".
    executables: An array of executables.

  Returns:
    A list of the target names of the _integration_test_executable rules.
  """

  if executables == None:
    return []

  # isinstance is not supported in skylark
  # pylint: disable=unidiomatic-typecheck
  if type(executables) != "list":
    fail("Error in target %s: %ss is not a list." % (orig_target_name, executable_type))

  targets = []
  i = 0
  for e in executables:
    targets.append(_create_integration_test_executable(
        orig_target_name, "%s_%d" % (executable_type, i), e))
    i += 1

  return targets

# sut_component macro
def sut_component(
    name,
    setups = None,
    teardowns = None,
    docker_image = "",
    required_sut_components = {}, num_requested_ports = 1):
  """Macro definition that expresses an sut_component.

  Behind the scenes, it creates _integration_test_executable rules for setup and
  teardown, and a _sut_component rule.

  Args:
    name: The name of the _sut_component target.
    setups: An array of setup executables (see executables in
      _create_integration_test_executables)
    teardowns: An array of teardown executables (see executables in
      _create_integration_test_executables)
    docker_image: The setup and teardown will be run inside this docker image.
    required_sut_components: Dictionary mapping names of dependent SUTs to their
      aliases.
    num_requested_ports: The number of ports requested for inter-SUT
      communication.
  """

  # Create integration_test_executable rules for setup and teardown.
  setup_targets = _create_integration_test_executables(
      name, "setup", setups)
  teardown_targets = _create_integration_test_executables(
      name, "teardown", teardowns)

  _sut_component(
      name = name,
      setups = setup_targets,
      teardowns = teardown_targets,
      docker_image = docker_image,
      required_sut_components = required_sut_components,
      num_requested_ports = num_requested_ports
  )


def external_sut_component(
    name,
    prepares = None,
    setups = None,
    teardowns = None,
    docker_image = "",
    required_sut_components = {}, num_requested_ports = 1):
  """Macro definition that expresses an external_sut_component.

  It expresses external_sut_component as two sut_component bzl targets.
  For more details, see go/ascit-plan-phase.

  Args:
    name: The name of the target. PREPARE_PHASE_SUFFIX will be appended to the
        target corresponding to the prepare phase.
    prepares: The scripts to run during the prepare phase.
    setups: The scripts to run during the setup phase.
    teardowns: The script to run during the teardown phase.
    docker_image: If provided, the SUT will be run inside the docker image.
    required_sut_components: Dictionary mapping names of dependent SUTs to their
        aliases.
    num_requested_ports: The number of ports requested for inter-SUT
        communication.
  """

  # The user cannot map an sut to "prep". We are using that name internally as
  # an alias to the prep sut.
  if "prep" in required_sut_components.values():
    fail("'prep' is an invalid sut alias, please choose a different name.")

  sut_component(
      name = name + PREPARE_PHASE_SUFFIX,
      setups = prepares,
      teardowns = teardowns,
      docker_image = docker_image,
      required_sut_components = required_sut_components,
      num_requested_ports = 0,
  )
  sut_component(
      name = name,
      setups = setups,
      docker_image = docker_image,
      required_sut_components = required_sut_components + {":" + name + PREPARE_PHASE_SUFFIX: "prep"},
      num_requested_ports = num_requested_ports,
  )

# Rule and implementation for integration tests as a test rule.
def _integration_test_impl(ctx):

  test_script = ("#!/bin/bash\n" +
                 "/tmp/botexec/.asci-reserved/test_wrapper_script.sh \"$@\"")

  ctx.file_action(
      output = ctx.outputs.executable,
      content = test_script,
      executable = True)

  config_proto_list = ["name: \"%s\"" % (ctx.attr.name)]

  # transitive_data_files is the set of all data dependencies required to run
  # the test, as well as to run all the setups and all the teardowns of all the
  # SUTs that this integration_test transitively depends on.

  transitive_data_files = depset()

  # Collect all the files to pass to foundry, and construct the repeated
  # components field of the IntegrationTestConfiguration proto.
  #
  # Collect the SUT component definition protos in a depset so there are no
  # duplicates.
  sutc_protos = depset()
  for sutc in ctx.attr.suts:
    transitive_data_files += sutc[SutComponentInfo].setups
    transitive_data_files += sutc[SutComponentInfo].teardowns
    transitive_data_files += sutc[SutComponentInfo].data
    for sutc_proto in sutc[SutComponentInfo].sut_protos:
      sutc_protos += ["components {%s}" % sutc_proto]
    config_proto_list.append("sut_component_alias {target: \"%s\" local_alias: \"%s\"}" %
                             (sutc.label, ctx.attr.suts[sutc]))

  for sutc_proto in sutc_protos.to_list():
    config_proto_list.append(sutc_proto)

  if ctx.attr.test_docker_image:
    config_proto_list.append(
        "docker_image: \"%s\"" % ctx.attr.test_docker_image)

  if ctx.attr.test_timeout:
    config_proto_list.append(
        "timeout_seconds: \"%d\"" % ctx.attr.test_timeout)

  # Convert into the enumeration values.
  test_type = "ERROR"
  if ctx.attr.test_type == "MultiMachine":
    test_type = "MULTI_MACHINE"
  if ctx.attr.test_type == "SingleMachine":
    test_type = "SINGLE_MACHINE"
  if test_type == "ERROR":
    fail("test_type must be one of MultiMachine or SingleMachine")
  config_proto_list.append("test_type: %s" % test_type)

  for pretest in ctx.attr.pretests:
    config_proto_list.append("pretest_executables {%s}" % pretest[ItExecutableInfo].executable_proto)
    transitive_data_files += depset([pretest[ItExecutableInfo].program_file])
    # Add the data files specified in the pretest ItExecutableInfo and in its
    # target.
    transitive_data_files += pretest[ItExecutableInfo].data
    transitive_data_files += pretest[ItExecutableInfo].program[DefaultInfo].data_runfiles.files

  # output_properties and output_files are supported for setup, teardown and
  # pretest but not for the test itself since no script can depend on a test and
  # consume its output.
  if ctx.attr.test[ItExecutableInfo].output_properties != []:
    fail("output_properties not supported in test.")
  if ctx.attr.test[ItExecutableInfo].output_files != []:
    fail("output_files not supported in test.")

  config_proto_list.append(
      "test_executable {%s}" %
      ctx.attr.test[ItExecutableInfo].executable_proto)
  transitive_data_files += depset([ctx.attr.test[ItExecutableInfo].program_file])
  transitive_data_files += ctx.attr.test[ItExecutableInfo].data
  transitive_data_files += ctx.attr.test[ItExecutableInfo].program[DefaultInfo].data_runfiles.files

  integration_test_config = " ".join(config_proto_list)


  test_env = testing.TestEnvironment(
      environment = { INTEGRATION_TEST_CONFIG_ENV_VAR: integration_test_config,
                      INTEGRATION_TEST_TYPE_ENV_VAR: test_type }
  )
  integration_test_info_for_test = IntegrationTestInfoForTestInfo(
      environment = { INTEGRATION_TEST_CONFIG_ENV_VAR: integration_test_config,
                      INTEGRATION_TEST_TYPE_ENV_VAR: test_type }
  )

  runfiles = ctx.runfiles(files=transitive_data_files.to_list())
  return [DefaultInfo(runfiles=runfiles), test_env, integration_test_info_for_test]

_integration_test = rule(
    _skylark_testable = True,
    attrs = {
        "pretests": attr.label_list(providers = [ItExecutableInfo]),
        "test": attr.label(
            mandatory=True,
            providers = [ItExecutableInfo],
        ),
        "suts": attr.label_keyed_string_dict(cfg = "target"),

        "test_type": attr.string(
            default = "SingleMachine",
        ),
        "test_docker_image": attr.string(),

        "test_timeout": attr.int(),
    },
    executable = True,
    test = True,
    implementation = _integration_test_impl,
)

def integration_test(
    name,
    test,
    pretests = None,
    suts = None,
    test_type = None,
    test_docker_image = None,
    test_timeout = None,
    tags = None):
  """Macro definition that expresses an integration_test.

  Behind the scenes, it creates a _integration_test_executable rule for the test
  and optionally for the pretests, and a _integration_test rule.

  Args:
    name: The name of the _integration_test target.
    test: A single test executable (see executable in
      _create_integration_test_executable).
    pretests: An array of pretest executables (see executables in
      _create_integration_test_executables)
    suts: Dictionary mapping names of dependent SUTs to their aliases.
    test_type: (to deprecate) "SingleMachine" or "MultiMachine".
    test_docker_image: The pretests and test will be run inside this docker image.
    test_timeout: Timeout of the test.
    tags: inherited from bazel test rule.
  """

  # Create integration_test_executable rules for pretests and test.
  pretest_targets = _create_integration_test_executables(name, "pretest", pretests)
  test_target = _create_integration_test_executable(name, "test", test)

  _integration_test(
      name = name,
      pretests = pretest_targets,
      test = test_target,
      suts = suts,
      test_type = test_type,
      test_docker_image = test_docker_image,
      test_timeout = test_timeout,
      tags = tags,
      timeout = "eternal",
  )
