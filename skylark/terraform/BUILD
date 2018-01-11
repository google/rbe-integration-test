package(default_visibility = ["//visibility:public"])

load(
    ":tf_sut_tests.bzl",
    "terraform_sut_component_test_suite",
)

terraform_sut_component_test_suite()

exports_files([
    "tf_setup.sh",
    "tf_teardown.sh",
])
