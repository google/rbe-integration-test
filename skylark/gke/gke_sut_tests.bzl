"""Unit tests for gke_sut.bzl."""

load(
    "//skylark:integration_tests.bzl",
    "sut_component",
    "SutComponentInfo"
)
load(
    ":gke_sut.bzl",
    "gke_sut_component",
)
load("//skylark:sets.bzl", "sets")
load("//skylark:unittest.bzl", "asserts", "unittest")
load("//skylark:toolchains.bzl", "toolchain_container_images")

# gke_sut_component_basic_test tests the gke_sut_component rule and makes sure
# that it converts correctly into an underlying sut_component by examining the
# SutComponentInfo output of the rule.
def _gke_sut_component_basic_test_impl(ctx):
  env = unittest.begin(ctx)
  provider = ctx.attr.dep[SutComponentInfo]
  expected_yaml_files = ",".join(ctx.attr.yaml_files)
  asserts.set_equals(
      env,
      depset([
          "name: \"" + ctx.attr.rule_name + "_prepare\" " +
          "setups {" +
            "file: \"skylark/gke/create_random_sequence.sh\" " +
            "output_properties {key: \"rand\"}" +
          "} " +
          "output_properties {key: \"rand\"} " +
          "teardowns {" +
            "file: \"skylark/gke/gke_teardown.sh\" " +
            "args: \"--project=" + ctx.attr.gcp_project + "\" " +
            "args: \"--zone=" + ctx.attr.gcp_zone + "\" " +
            "args: \"--cluster_name=" + ctx.attr.cluster_name + ("-{rand}" if ctx.attr.ephemeral_cluster else "") + "\" " +
            "args: \"--namespace={rand}\"" +
            (" args: \"--ephemeral_cluster\"" if ctx.attr.ephemeral_cluster else "") +
          "} " +
          "docker_image: \"" + toolchain_container_images()["rbe-integration-test"] + "\" " +
          "num_requested_ports: 0",

          "name: \"" + ctx.attr.rule_name + "\" " +
          "setups {" +
            "file: \"skylark/gke/gke_setup.sh\" " +
            "args: \"--yaml_files=" + expected_yaml_files + "\" " +
            "args: \"--load_balancers=" + ",".join([lb for lb in ctx.attr.load_balancers]) + "\" " +
            "args: \"--project=" + ctx.attr.gcp_project + "\" " +
            "args: \"--zone=" + ctx.attr.gcp_zone + "\" " +
            "args: \"--cluster_name=" + ctx.attr.cluster_name + ("-{prep#rand}" if ctx.attr.ephemeral_cluster else "") + "\" " +
            "args: \"--namespace={prep#rand}\" " +
            ("args: \"--ephemeral_cluster\" " if ctx.attr.ephemeral_cluster else "") +
            ("args: \"--create_cluster_if_necessary\" " if ctx.attr.create_cluster_if_necessary else "") +
            "args: \"--\" " +
            "".join(["args: \"%s\" " % ccf for ccf in ctx.attr.cluster_create_flags]) +

            "output_properties {key: \"cluster_name\"} " +
            "output_properties {key: \"namespace\"} " +
            "output_properties {key: \"ips\"}" +
            "".join([" output_properties {key: \"ip_%s\"}" % lb for lb in ctx.attr.load_balancers]) +
          "} " +
          "output_properties {key: \"cluster_name\"} " +
          "output_properties {key: \"namespace\"} " +
          "output_properties {key: \"ips\"} " +
          "".join(["output_properties {key: \"ip_%s\"} " % lb for lb in ctx.attr.load_balancers]) +
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

gke_sut_component_basic_test = unittest.make(
    _gke_sut_component_basic_test_impl,
    attrs={"dep": attr.label(),
           "rule_name" : attr.string(),
           "prepare": attr.label(allow_single_file = True),
           "setup": attr.label(allow_single_file = True),
           "teardown": attr.label(allow_single_file = True),
           "cluster_name": attr.string(),
           "ephemeral_cluster": attr.bool(default=False),
           "create_cluster_if_necessary": attr.bool(default=True),
           "data": attr.label_list(allow_files = True),
           "yaml_files": attr.string_list(),
           "load_balancers": attr.string_list(),
           "cluster_create_flags": attr.string_list(),
           "gcp_project": attr.string(),
           "gcp_zone": attr.string()}
)

def test_gke_sut_component_epheremal():
  """Generates an ephemeral gke_sut_component."""

  cluster_name = "cluster-name-prefix"
  load_balancers = ["lb1", "lb2", "lb3"]
  cluster_create_flags = ["--aaa=1", "--bbb=2"]
  gcp_project = "dummy_proj"
  gcp_zone = "us-east1-d"

  gke_sut_component(
      name = "gke_sut_component_epheremal_subject",
      cluster_name = cluster_name,
      ephemeral_cluster = True,
      k8s_yaml_files = [
          "testdata/test.yaml",
          "testdata/test2.yaml",
      ],
      load_balancers = load_balancers,
      cluster_create_flags = cluster_create_flags,
      gcp_project = gcp_project,
      gcp_zone = gcp_zone,
  )

  gke_sut_component_basic_test(name = "gke_sut_component_epheremal",
                               dep = "gke_sut_component_epheremal_subject",
                               rule_name = "//skylark/gke:gke_sut_component_epheremal_subject",
                               prepare = "create_random_sequence.sh",
                               setup = "gke_setup.sh",
                               teardown = "gke_teardown.sh",
                               cluster_name = cluster_name,
                               data = [
                                   "testdata/test.yaml",
                                   "testdata/test2.yaml",
                               ],
                               yaml_files = [
                                   "skylark/gke/testdata/test.yaml",
                                   "skylark/gke/testdata/test2.yaml",
                               ],
                               load_balancers = load_balancers,
                               cluster_create_flags = cluster_create_flags,
                               gcp_project = gcp_project,
                               gcp_zone = gcp_zone,
                               ephemeral_cluster= True)

def test_gke_sut_component_non_epheremal():
  """Generates a non-ephemeral gke_sut_component."""

  cluster_name = "cluster-name"
  load_balancers = ["lb"]
  gcp_project = "dummy_proj"
  gcp_zone = "us-east1-d"

  gke_sut_component(
      name = "gke_sut_component_non_epheremal_subject",
      cluster_name = cluster_name,
      ephemeral_cluster = False,
      create_cluster_if_necessary = False,
      k8s_yaml_files = [
          "testdata/test.yaml",
      ],
      load_balancers = load_balancers,
      gcp_project = gcp_project,
      gcp_zone = gcp_zone,
  )

  gke_sut_component_basic_test(name = "gke_sut_component_non_epheremal",
                               dep = "gke_sut_component_non_epheremal_subject",
                               rule_name = "//skylark/gke:gke_sut_component_non_epheremal_subject",
                               prepare = "create_random_sequence.sh",
                               setup = "gke_setup.sh",
                               teardown = "gke_teardown.sh",
                               cluster_name = cluster_name,
                               data = [
                                   "testdata/test.yaml",
                               ],
                               yaml_files = [
                                   "skylark/gke/testdata/test.yaml",
                               ],
                               load_balancers = load_balancers,
                               gcp_project = gcp_project,
                               gcp_zone = gcp_zone,
                               ephemeral_cluster= False,
                               create_cluster_if_necessary = False,
                               )

def test_gke_sut_component_non_epheremal_with_create():
  """Generates a non-ephemeral gke_sut_component with create_cluster_if_necessary."""

  cluster_name = "cluster-name"
  load_balancers = ["lb"]
  gcp_project = "dummy_proj"
  gcp_zone = "us-east1-d"

  gke_sut_component(
      name = "gke_sut_component_non_epheremal_with_create_subject",
      cluster_name = cluster_name,
      ephemeral_cluster = False,
      create_cluster_if_necessary = True,
      k8s_yaml_files = [
          "testdata/test.yaml",
      ],
      load_balancers = load_balancers,
      gcp_project = gcp_project,
      gcp_zone = gcp_zone,
  )

  gke_sut_component_basic_test(name = "gke_sut_component_non_epheremal_with_create",
                               dep = "gke_sut_component_non_epheremal_with_create_subject",
                               rule_name = "//skylark/gke:gke_sut_component_non_epheremal_with_create_subject",
                               prepare = "create_random_sequence.sh",
                               setup = "gke_setup.sh",
                               teardown = "gke_teardown.sh",
                               cluster_name = cluster_name,
                               data = [
                                   "testdata/test.yaml",
                               ],
                               yaml_files = [
                                   "skylark/gke/testdata/test.yaml",
                               ],
                               load_balancers = load_balancers,
                               gcp_project = gcp_project,
                               gcp_zone = gcp_zone,
                               ephemeral_cluster= False,
                               create_cluster_if_necessary = True,
                               )

def gke_sut_component_test_suite():
  test_gke_sut_component_epheremal()
  test_gke_sut_component_non_epheremal()
  test_gke_sut_component_non_epheremal_with_create()

  native.test_suite(
      name = "gke_sut_component_test",
      tests = [
          "gke_sut_component_epheremal",
          "gke_sut_component_non_epheremal",
          "gke_sut_component_non_epheremal_with_create",
      ],
  )
