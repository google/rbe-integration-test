package(
    default_visibility = ["//skylark/k8s:__pkg__"],
)

load(
    ":gke_sut_tests.bzl",
    "gke_k8s_sut_component_test_suite",
)

gke_k8s_sut_component_test_suite()

exports_files([
    "create_random_sequence.sh",
    "gke_setup.sh",
    "gke_teardown.sh",
])
