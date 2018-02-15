"""Skylark extension for k8s_sut_component."""

load("//skylark:toolchains.bzl", "toolchain_container_images")
load("//skylark:integration_tests.bzl", "external_sut_component")
load("//skylark/k8s:gke/gke_sut.bzl", "gke_sut_component")

def k8s_sut_component(
    name,
    cluster_type,
    cluster_info = {},
    k8s_yaml_files = [],
    load_balancers = [],
    sut_deps = {}):
  """k8s_sut_component is a skylark macro that wraps external_sut_component."""

  _verify_params(k8s_yaml_files, load_balancers)

  if cluster_type == "GKE":
    gke_sut_component(
        name = name,
        gke_cluster_info = cluster_info,
        k8s_yaml_files = k8s_yaml_files,
        load_balancers = load_balancers,
        sut_deps = sut_deps)
  else:
    fail("Error: currently only cluster_type = \"GKE\" is supported.")

def _verify_params(k8s_yaml_files, load_balancers):
  # Catch configuration errors earlier rather than later and gives informative
  # error messages.
  #
  # In particular, we try to catch any error which would otherwise be caught
  # only on the server side.
  #
  # Since k8s_sut_component is a bazel macro (i.e. a python function) and not a
  # bazel rule, there is no type checking. So some of the verifications below
  # are simply type verifications.
  #
  # Note that _verify_params does not try to catch *all* the configuration
  # errors, only the ones which might benefit from an early and informative
  # error message compared to the error (and the resulting error message) that
  # would occur later down stream.

  _verify_yaml_files(k8s_yaml_files)
  _verify_load_balancers(load_balancers)

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

def _verify_yaml_files(k8s_yaml_files):
  # k8s_yaml_files must be an array.
  # Each element of the array must either be a string, or a dictionary of the
  # following format:
  # The dictionary has two fields: name and substitute.
  # The name field is a string.
  # The substitute field is an array of dictionaries each of which has a single
  # key and value.

  # isinstance is not supported in skylark
  # pylint: disable=unidiomatic-typecheck
  if type(k8s_yaml_files) != "list":
    fail("Error: k8s_yaml_files %s is not a list." % k8s_yaml_files)

  for item in k8s_yaml_files:
    # isinstance is not supported in skylark
    # pylint: disable=unidiomatic-typecheck
    if type(item) == "string":
      continue
    if type(item) != "dict":
      fail("Error: k8s_yaml_files %s must be a list of strings and dicts. %s is neither." % (k8s_yaml_files, item))
    if "name" not in item:
      fail("Error: k8s_yaml_files element %s must have a \"name\" field." % item)
    if "substitute" not in item:
      fail("Error: k8s_yaml_files element %s must have a \"substitute\" field." % item)
    # isinstance is not supported in skylark
    # pylint: disable=unidiomatic-typecheck
    if type(item["substitute"]) != "list":
      fail("Error: k8s_yaml_files element %s must have a \"substitute\" field which is a list." % item)

    for sub in item["substitute"]:
      # isinstance is not supported in skylark
      # pylint: disable=unidiomatic-typecheck
      if type(sub) != "dict":
        fail("Error: k8s_yaml_files substitution %s must be a dict." % sub)
      if len(sub.keys()) != 1:
        fail("Error: k8s_yaml_files substitution %s must be a dict with exactly one field." % sub)

def _verify_load_balancers(load_balancers):
  if not _is_list_of_strings(load_balancers):
    fail("Error: load_balancers %s is not a list of strings." % load_balancers)

