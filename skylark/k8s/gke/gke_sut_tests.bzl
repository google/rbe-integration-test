"""Unit tests for gke_sut.bzl."""

load(
    "//skylark:integration_tests.bzl",
    "SutComponentInfo"
)
load(
    "//skylark/k8s:k8s_sut.bzl",
    "k8s_sut_component",
)
load("//skylark:unittest.bzl", "asserts", "unittest")
load("//skylark:toolchains.bzl", "toolchain_container_images")

# gke_k8s_sut_component_basic_test tests the k8s_sut_component rule for GKE and
# makes sure that it converts correctly into an underlying sut_component by
# examining the SutComponentInfo output of the rule.
def _gke_k8s_sut_component_basic_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  asserts.set_equals(
      env,
      depset([
          "name: \"" + ctx.attr.rule_name + "_prepare\" " +
          "setups {" +
            "file: \"skylark/k8s/gke/create_random_sequence.sh\" " +
            "timeout_seconds: 3 " +
            "output_properties {key: \"rand\"}" +
          "} " +
          "teardowns {" +
            "file: \"skylark/k8s/gke/gke_teardown.sh\" " +
            "timeout_seconds: %d " % (600 if ctx.attr.ephemeral_cluster else 50) +
            "args: \"--project\" args: \"" + ctx.attr.gcp_project + "\" " +
            "args: \"--zone\" args: \"" + ctx.attr.gcp_zone + "\" " +
            "args: \"--cluster_name\" " +
            "args: \"" + ctx.attr.cluster_name + ("-{rand}" if ctx.attr.ephemeral_cluster else "") + "\" " +
            "args: \"--namespace\" args: \"{rand}\"" +
            (" args: \"--ephemeral_cluster\"" if ctx.attr.ephemeral_cluster else "") +
          "} " +
          "docker_image: \"" + toolchain_container_images()["rbe-integration-test"] + "\" " +
          "num_requested_ports: 0",

          "name: \"" + ctx.attr.rule_name + "\" " +
          "setups {" +
            "file: \"skylark/k8s/gke/gke_setup.sh\" " +
            "timeout_seconds: %d " % (400 if ctx.attr.ephemeral_cluster or ctx.attr.create_cluster_if_necessary else 50) +
            # ctx.attr.yaml_file_args already includes the --yaml_file and
            # --substitute args so no need to add them here.
            "".join(["args: \"" + a + "\" " for a in ctx.attr.yaml_file_args]) +
            "".join(["args: \"--load_balancer\" args: \"" + lb + "\" " for lb in ctx.attr.load_balancers]) +
            "args: \"--project\" args: \"" + ctx.attr.gcp_project + "\" " +
            "args: \"--zone\" args: \"" + ctx.attr.gcp_zone + "\" " +
            "args: \"--cluster_name\" args: \"" + ctx.attr.cluster_name + ("-{prep#rand}" if ctx.attr.ephemeral_cluster else "") + "\" " +
            "args: \"--namespace\" args: \"{prep#rand}\" " +
            ("args: \"--ephemeral_cluster\" " if ctx.attr.ephemeral_cluster else "") +
            ("args: \"--create_cluster_if_necessary\" " if ctx.attr.create_cluster_if_necessary else "") +
            "args: \"--\" " +
            "".join(["args: \"%s\" " % ccf for ccf in ctx.attr.cluster_create_flags]) +

            "output_properties {key: \"cluster_name\"} " +
            "output_properties {key: \"namespace\"} " +
            "output_properties {key: \"ips\"}" +
            "".join([" output_properties {key: \"ip_%s\"}" % lb for lb in ctx.attr.load_balancers]) +
          "} " +
          "docker_image: \"" + toolchain_container_images()["rbe-integration-test"] + "\" " +
          "sut_component_alias {" +
          "target: \"" + ctx.attr.rule_name + "_prepare\" " +
          "local_alias: \"prep\"} " +
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

gke_k8s_sut_component_basic_test = unittest.make(
    _gke_k8s_sut_component_basic_test_impl,
    attrs={"dep": attr.label(),
           "rule_name" : attr.string(),
           "prepare": attr.label(allow_single_file = True),
           "setup": attr.label(allow_single_file = True),
           "teardown": attr.label(allow_single_file = True),
           "cluster_name": attr.string(),
           "ephemeral_cluster": attr.bool(default=False),
           "create_cluster_if_necessary": attr.bool(default=True),
           "data": attr.label_list(allow_files = True),
           # yaml_file_args include the --yaml_file and --substitute args to
           # gke_setup.sh.
           "yaml_file_args": attr.string_list(),
           "load_balancers": attr.string_list(),
           "cluster_create_flags": attr.string_list(),
           "gcp_project": attr.string(),
           "gcp_zone": attr.string()}
)

def test_gke_k8s_sut_component_ephemeral():
  """Generates an ephemeral GKE k8s_sut_component."""

  cluster_name = "cluster-name-prefix"
  load_balancers = ["lb1", "lb2", "lb3"]
  cluster_create_flags = ["--aaa=1", "--bbb=2"]
  gcp_project = "dummy_proj"
  gcp_zone = "us-east1-d"

  k8s_sut_component(
      name = "gke_k8s_sut_component_ephemeral_subject",
      cluster_type = "GKE",
      cluster_info = {
          "cluster_name": cluster_name,
          "ephemeral_cluster": True,
          "gcp_project": gcp_project,
          "gcp_zone": gcp_zone,
          "cluster_create_flags": cluster_create_flags,
      },
      k8s_yaml_files = [
          "testdata/test.yaml",
          "testdata/test2.yaml",
      ],
      load_balancers = load_balancers,
  )

  gke_k8s_sut_component_basic_test(
      name = "gke_k8s_sut_component_ephemeral",
      dep = "gke_k8s_sut_component_ephemeral_subject",
      rule_name = "//skylark/k8s/gke:gke_k8s_sut_component_ephemeral_subject",
      prepare = "//skylark/k8s/gke:create_random_sequence.sh",
      setup = "//skylark/k8s/gke:gke_setup.sh",
      teardown = "//skylark/k8s/gke:gke_teardown.sh",
      cluster_name = cluster_name,
      data = [
         "testdata/test.yaml",
         "testdata/test2.yaml",
      ],
      yaml_file_args = [
         "--yaml_file", "skylark/k8s/gke/testdata/test.yaml",
         "--yaml_file", "skylark/k8s/gke/testdata/test2.yaml",
      ],
      load_balancers = load_balancers,
      cluster_create_flags = cluster_create_flags,
      gcp_project = gcp_project,
      gcp_zone = gcp_zone,
      ephemeral_cluster= True)

def test_gke_k8s_sut_component_non_ephemeral():
  """Generates a non-ephemeral GKE k8s_sut_component."""

  cluster_name = "cluster-name"
  load_balancers = ["lb"]
  gcp_project = "dummy_proj"
  gcp_zone = "us-east1-d"

  k8s_sut_component(
      name = "gke_k8s_sut_component_non_ephemeral_subject",
      cluster_type = "GKE",
      cluster_info = {
          "cluster_name": cluster_name,
          "ephemeral_cluster": False,
          "create_cluster_if_necessary": False,
          "gcp_project": gcp_project,
          "gcp_zone": gcp_zone,
      },
      k8s_yaml_files = [
          "testdata/test.yaml",
      ],
      load_balancers = load_balancers,
  )

  gke_k8s_sut_component_basic_test(
      name = "gke_k8s_sut_component_non_ephemeral",
      dep = "gke_k8s_sut_component_non_ephemeral_subject",
      rule_name = "//skylark/k8s/gke:gke_k8s_sut_component_non_ephemeral_subject",
      prepare = "//skylark/k8s/gke:create_random_sequence.sh",
      setup = "//skylark/k8s/gke:gke_setup.sh",
      teardown = "//skylark/k8s/gke:gke_teardown.sh",
      cluster_name = cluster_name,
      data = ["testdata/test.yaml"],
      yaml_file_args = [
         "--yaml_file", "skylark/k8s/gke/testdata/test.yaml",
      ],
      load_balancers = load_balancers,
      gcp_project = gcp_project,
      gcp_zone = gcp_zone,
      ephemeral_cluster= False,
      create_cluster_if_necessary = False,
  )

def test_gke_k8s_sut_component_non_ephemeral_with_create():
  """Generates a non-ephemeral GKE k8s_sut_component with create_cluster_if_necessary."""

  cluster_name = "cluster-name"
  load_balancers = ["lb"]
  gcp_project = "dummy_proj"
  gcp_zone = "us-east1-d"

  k8s_sut_component(
      name = "gke_k8s_sut_component_non_ephemeral_with_create_subject",
      cluster_type = "GKE",
      cluster_info = {
          "cluster_name": cluster_name,
          "ephemeral_cluster": False,
          "create_cluster_if_necessary": True,
          "gcp_project": gcp_project,
          "gcp_zone": gcp_zone,
      },
      k8s_yaml_files = [
          "testdata/test.yaml",
      ],
      load_balancers = load_balancers,
  )

  gke_k8s_sut_component_basic_test(
      name = "gke_k8s_sut_component_non_ephemeral_with_create",
      dep = "gke_k8s_sut_component_non_ephemeral_with_create_subject",
      rule_name = "//skylark/k8s/gke:gke_k8s_sut_component_non_ephemeral_with_create_subject",
      prepare = "//skylark/k8s/gke:create_random_sequence.sh",
      setup = "//skylark/k8s/gke:gke_setup.sh",
      teardown = "//skylark/k8s/gke:gke_teardown.sh",
      cluster_name = cluster_name,
      data = ["testdata/test.yaml"],
      yaml_file_args = [
         "--yaml_file", "skylark/k8s/gke/testdata/test.yaml",
      ],
      load_balancers = load_balancers,
      gcp_project = gcp_project,
      gcp_zone = gcp_zone,
      ephemeral_cluster= False,
      create_cluster_if_necessary = True,
  )

def test_gke_k8s_sut_component_with_yaml_substitutions():
  """Generates a GKE k8s_sut_component with yaml substitutions."""

  cluster_name = "cluster-name"
  gcp_project = "dummy_proj"
  gcp_zone = "us-east1-d"

  k8s_sut_component(
      name = "gke_k8s_sut_component_with_yaml_substitutions_subject",
      cluster_type = "GKE",
      cluster_info = {
          "cluster_name": cluster_name,
          "gcp_project": gcp_project,
          "gcp_zone": gcp_zone,
      },
      k8s_yaml_files = [
          {
              "name": "testdata/test.yaml",
              "substitute": [
                  {"aaa": "bbb"},
                  {"ccc": "ddd"},
              ],
          },
          {
              "name": "testdata/test2.yaml",
              "substitute": [
                  {"eee": "fff"},
              ],
          },
      ],
  )

  gke_k8s_sut_component_basic_test(
      name = "gke_k8s_sut_component_with_yaml_substitutions",
      dep = "gke_k8s_sut_component_with_yaml_substitutions_subject",
      rule_name = "//skylark/k8s/gke:gke_k8s_sut_component_with_yaml_substitutions_subject",
      prepare = "//skylark/k8s/gke:create_random_sequence.sh",
      setup = "//skylark/k8s/gke:gke_setup.sh",
      teardown = "//skylark/k8s/gke:gke_teardown.sh",
      cluster_name = cluster_name,
      data = [
         "testdata/test.yaml",
         "testdata/test2.yaml",
      ],
      yaml_file_args = [
         "--yaml_file", "skylark/k8s/gke/testdata/test.yaml",
         "--substitute", "aaa", "bbb",
         "--substitute", "ccc", "ddd",
         "--yaml_file", "skylark/k8s/gke/testdata/test2.yaml",
         "--substitute", "eee", "fff",
      ],
      gcp_project = gcp_project,
      gcp_zone = gcp_zone,
  )

def gke_k8s_sut_component_test_suite():
  """Runs tests for GKE k8s_sut_component."""
  test_gke_k8s_sut_component_ephemeral()
  test_gke_k8s_sut_component_non_ephemeral()
  test_gke_k8s_sut_component_non_ephemeral_with_create()
  test_gke_k8s_sut_component_with_yaml_substitutions()

  native.test_suite(
      name = "gke_k8s_sut_component_test",
      tests = [
          "gke_k8s_sut_component_ephemeral",
          "gke_k8s_sut_component_non_ephemeral",
          "gke_k8s_sut_component_non_ephemeral_with_create",
          "gke_k8s_sut_component_with_yaml_substitutions",
      ],
  )
