"""Defintions for commonly used images.

Please use these to guarantee pinning to well supported versions of
AS-Toolchains provided containers.
Contact alphasource-toolchains@ for issues.
"""

def toolchain_container_images():
  """Store the docker image location."""
  return {
      'nosla-debian8-clang-fl':'docker://gcr.io/asci-toolchain/nosla-debian8-clang-fl@' + toolchain_container_sha256s()['nosla-debian8-clang-fl'],
      'tensorflow':'docker://gcr.io/asci-toolchain/ascit-tensorflow-test@' + toolchain_container_sha256s()['tensorflow'],
      # rbe-integration-test is the image used for managed systems such as gke
      # terraform and GCR uploader. It contains, among other things, gcloud,
      # kubectl, terraform and docker.
      'rbe-integration-test':'docker://gcr.io/asci-toolchain/ascit-managed-systems@' + toolchain_container_sha256s()['rbe-integration-test'],
  }

def toolchain_container_sha256s():
  """Store the image sha strings."""
  return {
      'nosla-debian8-clang-fl':'sha256:e79e367aab94c6f18a0b39950fe4f160fda07ee01e3c32604c5f8472afa7c1f0',
      'tensorflow':'sha256:a563a84de997e3df9d4370687454849a87114efa057e22ba77056f3592ca4c8a',
      'rbe-integration-test':'sha256:4358d1349cd5e7d22cd170a427d47baf7a45ae2592493371ad99fe8e18307aee',
  }
