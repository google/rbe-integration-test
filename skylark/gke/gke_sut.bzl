"""Skylark extension for gke_sut_component."""

load("//skylark:toolchains.bzl", "toolchain_container_images")
load("//skylark:integration_tests.bzl", "external_sut_component")

def gke_sut_component(
    name,
    gcp_project,
    gcp_zone,
    cluster_name,
    k8s_yaml_files = [],
    load_balancers = [],
    ephemeral_cluster = False,
    create_cluster_if_necessary = True,
    cluster_create_flags=[]):
  """gke_sut_component is a skylark macro that wraps external_sut_component."""

  _verify_params(k8s_yaml_files, load_balancers, cluster_name,
                 ephemeral_cluster, cluster_create_flags)

  # Create comma separated lists for yaml files and load balancers.
  load_balancer_csv = ",".join([load_balancer
                                for load_balancer in load_balancers])

  yaml_file_csv = ",".join(["$(rootpath %s)" % yaml_file
                            for yaml_file in k8s_yaml_files])

  #
  # gke_sut_component has three modes:
  # 1. Ephemeral mode (ephemeral_cluster == True): the GKE cluster is setup
  #    and torn down.
  # 2. Non ephemeral mode with no creation (ephemeral_cluster == False,
  #    create_cluster_if_necessary = False): Use a pre-existing GKE cluster.
  # 3. Non ephemeral mode with possible creation (ephemeral_cluster == False,
  #    create_cluster_if_necessary = True): Use a pre-existing GKE cluster, but
  #    create it if it doesn't exist.
  #
  # The distiction between these modes is done in the gke_setup.sh and
  # gke_teardown.sh scripts.

  # Creating the underlying external_sut_component rule.
  external_sut_component(
      name = name,
      docker_image = toolchain_container_images()["rbe-integration-test"],
      prepares = [{
          # The str(Label(...)) is necessary for proper namespace resolution in
          # cases where this repo is imported from another repo.
          "program" : str(Label("//skylark/gke:create_random_sequence.sh")),
          "output_properties" : ["rand"],
      }],
      setups = [{
          "program" : str(Label("//skylark/gke:gke_setup.sh")),
          "args" : [
              "--yaml_files=%s" % yaml_file_csv,
              "--load_balancers=%s" % load_balancer_csv,
              "--project=%s" % gcp_project,
              "--zone=%s" % gcp_zone,
              # When using ephemeral mode, the cluster name gets a suffix.
              "--cluster_name=%s%s" % (cluster_name, ("-{prep#rand}" if ephemeral_cluster else "")),
              # The "prep" alias is necessary because under the hood,
              # external_sut_component creates two separate sut_components: a prep
              # sut_component which handles prepare and teardown and a second
              # sut_component which handles the setup.
              "--namespace={prep#rand}",
          ] +
          (["--ephemeral_cluster"] if ephemeral_cluster else []) +
          (["--create_cluster_if_necessary"] if create_cluster_if_necessary else []) +
          [
              "--",
              # Any argument coming after "--" are flags to the
              # "gcloud container clusters create" command.
          ] + cluster_create_flags,
          "data" : k8s_yaml_files,
          "deps" : k8s_yaml_files,
          "output_properties" : [
              "cluster_name", # The actual cluster_name (possibly with a suffix)
              "namespace",    # The k8s namespace
              "ips",          # A JSON string with lb->ip mapping.
          ] + [
              # The external ip of each load balancer.
              "ip_" + load_balancer for load_balancer in load_balancers
          ],
      }],
      teardowns = [{
          "program" : str(Label("//skylark/gke:gke_teardown.sh")),
          "args" : [
              "--project=%s" % gcp_project,
              "--zone=%s" % gcp_zone,
              # When using ephemeral mode, the cluster name gets a suffix.
              "--cluster_name=%s%s" % (cluster_name, ("-{rand}" if ephemeral_cluster else "")),
              "--namespace={rand}",
          ] +
          (["--ephemeral_cluster"] if ephemeral_cluster else []),
          "data" : k8s_yaml_files,
          "deps" : k8s_yaml_files,
      }],
  )

def _verify_params(k8s_yaml_files, load_balancers, cluster_name,
                   ephemeral_cluster, cluster_create_flags):
  # Catch configuration errors earlier rather than later and gives informative
  # error messages.
  #
  # In particular, we try to catch any error which would otherwise be caught
  # only on the server side.
  #
  # Since gke_sut_component is a bazel macro (i.e. a python function) and not a
  # bazel rule, there is no type checking. So some of the verifications below
  # are simply type verifications.
  #
  # Note that _verify_params does not try to catch *all* the configuration
  # errors, only the ones which might benefit from an early and informative
  # error message compared to the error (and the resulting error message) that
  # would occur later down stream.

  _verify_yaml_files(k8s_yaml_files)
  _verify_load_balancers(load_balancers)
  _verify_cluster_create_flags(cluster_create_flags)
  _verify_cluster_correctness(cluster_name, ephemeral_cluster)

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

def _verify_cluster_correctness(cluster_name, ephemeral_cluster):
  if ephemeral_cluster:
    # In ephemeral clusters, the actual cluster name is the cluster_name
    # attribute plus a suffix which may be up to 11 characters long.
    _verify_cluster_name(cluster_name, 11)
  else:
    _verify_cluster_name(cluster_name)

def _verify_yaml_files(k8s_yaml_files):
  if not _is_list_of_strings(k8s_yaml_files):
    fail("Error: k8s_yaml_files %s is not a list of strings." % k8s_yaml_files)


def _verify_cluster_name(cluster_name, max_suffix_length=0):
  # Check that cluster_name matches gcloud constraints.
  # It must match regex '(?:[a-z](?:[-a-z0-9]{0,38}[a-z0-9])?)' (only
  # alphanumerics and '-' allowed, must start with a letter and end with an
  # alphanumeric, and must be no longer than 40 characters).
  #
  # In case a suffix is expected, we restrict the length even further.
  #
  # Since regex is not supported in skylark, we do this manually.

  # isinstance is not supported in skylark
  # pylint: disable=unidiomatic-typecheck
  if type(cluster_name) != "string":
    fail("Error: cluster_name must be a string.")
  if not cluster_name:
    fail("Error: cluster_name must not be empty.")

  max_len = 40 - max_suffix_length
  if len(cluster_name) > max_len:
    if max_len <= 0:
      fail("Error: cluster_name %s is too long." % cluster_name)
    else:
      fail("Error: cluster_name %s is too long. Note for ephemeral clusters, a random suffix is appended to produce the actual cluster name." % cluster_name)

  # First character must be a lower case letter.
  if not cluster_name[0].islower():
    fail("Error: cluster_name %s must start with a lower case letter." % cluster_name)
  # All other characters must be lower case or digits or "-".
  for c in cluster_name:
    if not (c.islower() or c.isdigit() or c == "-"):
      fail("Error: cluster_name %s must constist only of characters in [-a-z0-9]." % cluster_name)

def _verify_load_balancers(load_balancers):
  if not _is_list_of_strings(load_balancers):
    fail("Error: load_balancers %s is not a list of strings." % load_balancers)

def _verify_cluster_create_flags(cluster_create_flags):
  if not _is_list_of_strings(cluster_create_flags):
    fail("Error: cluster_create_flags %s is not a list of strings." % cluster_create_flags)
