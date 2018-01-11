"""Defintions for commonly used images.

Please use these to guarantee pinning to well supported versions of
AS-Toolchains provided containers.
Contact alphasource-toolchains@ for issues.
"""

def toolchain_container_images():
  """Store the docker image location."""
  return {
      'nosla-debian8-clang-fl':'docker://gcr.io/asci-toolchain/nosla-debian8-clang-fl@' + toolchain_container_sha256s()['nosla-debian8-clang-fl'],
      'tensorflow':'docker://gcr.io/tensorflow-testing/ascit_image@' + toolchain_container_sha256s()['tensorflow'],
      # rbe-integration-test is the image used for gke and terraform. It
      # contains, among other things, gcloud, kubectl and terraform.
      'rbe-integration-test':'docker://gcr.io/ascit-gke-testing/integration-testing@' + toolchain_container_sha256s()['rbe-integration-test'],
  }

def toolchain_container_sha256s():
  """Store the image sha strings."""
  return {
      'nosla-debian8-clang-fl':'sha256:e79e367aab94c6f18a0b39950fe4f160fda07ee01e3c32604c5f8472afa7c1f0',
      'tensorflow':'sha256:a563a84de997e3df9d4370687454849a87114efa057e22ba77056f3592ca4c8a',
      'rbe-integration-test':'sha256:1efa016034cfca0ba32f61859d724722cbac75698e27a98e305be1b22f211e13',
  }
