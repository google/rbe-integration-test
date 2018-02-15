package(default_visibility = ["//visibility:public"])

exports_files([
    "generate_image_name.sh",
    "create_and_upload_image.sh",
    "delete_image.sh",
])

load(
    ":image_uploader_tests.bzl",
    "image_uploader_sut_component_test_suite",
)

image_uploader_sut_component_test_suite()
