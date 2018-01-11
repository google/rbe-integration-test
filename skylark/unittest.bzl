"""Unit testing support.

Unlike most Skylib files, this exports two modules: `unittest` which contains
functions to declare and define unit tests, and `asserts` which contains the
assertions used to within tests.
"""

load(":sets.bzl", "sets")


def _make(impl, attrs=None):
  """Creates a unit test rule from its implementation function.

  Each unit test is defined in an implementation function that must then be
  associated with a rule so that a target can be built. This function handles
  the boilerplate to create and return a test rule and captures the
  implementation function's name so that it can be printed in test feedback.

  The optional `attrs` argument can be used to define dependencies for this
  test, in order to form unit tests of rules.

  An example of a unit test:

  ```
  def _your_test(ctx):
    env = unittest.begin(ctx)

    # Assert statements go here

    unittest.end(env)

  your_test = unittest.make(_your_test)
  ```

  Recall that names of test rules must end in `_test`.

  Args:
    impl: The implementation function of the unit test.
    attrs: An optional dictionary to supplement the attrs passed to the
        unit test's `rule()` constructor.
  Returns:
    A rule definition that should be stored in a global whose name ends in
    `_test`.
  """

  # Derive the name of the implementation function for better test feedback.
  # Skylark currently stringifies a function as "<function NAME>", so we use
  # that knowledge to parse the "NAME" portion out. If this behavior ever
  # changes, we'll need to update this.

  impl_name = str(impl)
  impl_name = impl_name.partition("<function ")[-1]
  impl_name = impl_name.rpartition(">")[0]

  attrs = dict(attrs) if attrs else {}
  attrs["_impl_name"] = attr.string(default=impl_name)

  return rule(
      impl,
      attrs=attrs,
      _skylark_testable=True,
      test=True,
  )


def _suite(name, *test_rules):
  """Defines a `test_suite` target that contains multiple tests.

  After defining your test rules in a `.bzl` file, you need to create targets
  from those rules so that `blaze test` can execute them. Doing this manually
  in a BUILD file would consist of listing each test in your `load` statement
  and then creating each target one by one. To reduce duplication, we recommend
  writing a macro in your `.bzl` file to instantiate all targets, and calling
  that macro from your BUILD file so you only have to load one symbol.

  For the case where your unit tests do not take any (non-default) attributes --
  i.e., if your unit tests do not test rules -- you can use this function to
  create the targets and wrap them in a single test_suite target. In your
  `.bzl` file, write:

  ```
  def your_test_suite():
    unittest.suite(
        "your_test_suite",
        your_test,
        your_other_test,
        yet_another_test,
    )
  ```

  Then, in your `BUILD` file, simply load the macro and invoke it to have all
  of the targets created:

  ```
  load("//path/to/your/package:tests.bzl", "your_test_suite")
  your_test_suite()
  ```

  If you pass _N_ unit test rules to `unittest.suite`, _N_ + 1 targets will be
  created: a `test_suite` target named `${name}` (where `${name}` is the name
  argument passed in here) and targets named `${name}_test_${i}`, where `${i}`
  is the index of the test in the `test_rules` list, which is used to uniquely
  name each target.

  Args:
    name: The name of the `test_suite` target, and the prefix of all the test
        target names.
    *test_rules: A list of test rules defines by `unittest.test`.
  """
  test_names = []
  for index, test_rule in enumerate(test_rules):
    test_name = "%s_test_%d" % (name, index)
    test_rule(name=test_name)
    test_names.append(test_name)

  native.test_suite(
      name=name,
      tests=[":%s" % t for t in test_names]
  )


def _begin(ctx):
  """Begins a unit test.

  This should be the first function called in a unit test implementation
  function. It initializes a "test environment" that is used to collect
  assertion failures so that they can be reported and logged at the end of the
  test.

  Args:
    ctx: The Skylark context. Pass the implementation function's `ctx` argument
        in verbatim.
  Returns:
    A test environment struct that must be passed to assertions and finally to
    `unittest.end`. Do not rely on internal details about the fields in this
    struct as it may change.
  """
  return struct(ctx=ctx, failures=[])


def _end(env):
  """Ends a unit test and logs the results.

  This must be called before the end of a unit test implementation function so
  that the results are reported.

  Args:
    env: The test environment returned by `unittest.begin`.
  """
  cmd = "\n".join([
      "cat << EOF",
      "\n".join(env.failures),
      "EOF",
      "exit %d" % len(env.failures),
  ])
  env.ctx.file_action(
      output=env.ctx.outputs.executable,
      content=cmd,
      executable=True,
  )


def _fail(env, assert_msg, test_msg):
  """Unconditionally causes the current test to fail.

  Args:
    env: The test environment returned by `unittest.begin`.
    assert_msg: Message prepared by _assert, contains expected vs actual values.
    test_msg: Message send by unit test, prepended to assert_msg if not empty.
  """
  if test_msg:
    err_msg = "%s (%s)" % (test_msg, assert_msg)
  else:
    err_msg = assert_msg
  full_msg = "In test %s: %s" % (env.ctx.attr._impl_name, err_msg)
  print(full_msg)
  env.failures.append(full_msg)


def _assert_true(env,
                 condition,
                 msg="Expected condition to be true, but was false."):
  """Asserts that the given `condition` is true.

  Args:
    env: The test environment returned by `unittest.begin`.
    condition: A value that will be evaluated in a Boolean context.
    msg: An optional message that will be printed that describes the failure.
  """
  if not condition:
    _fail(env, msg, None)


def _assert_false(env,
                  condition,
                  msg="Expected condition to be false, but was true."):
  """Asserts that the given `condition` is false.

  Args:
    env: The test environment returned by `unittest.begin`.
    condition: A value that will be evaluated in a Boolean context.
    msg: An optional message that will be printed that describes the failure.
  """
  if condition:
    _fail(env, msg, None)


def _assert_equals(env, expected, actual, msg=None):
  """Asserts that the given `expected` and `actual` values are equal.

  Args:
    env: The test environment returned by `unittest.begin`.
    expected: The expected value of some computation.
    actual: The actual value returned by some computation.
    msg: An optional message that will be printed that describes the failure.
  """
  if expected != actual:
    expectation_msg = 'Expected "%s", but got "%s"' % (expected, actual)
    _fail(env, expectation_msg, msg)


def _assert_set_equals(env, expected, actual, msg=None):
  """Asserts that the given `expected` and `actual` sets are equal.

  Args:
    env: The test environment returned by `unittest.begin`.
    expected: The expected set resulting from some computation.
    actual: The actual set returned by some computation.
    msg: An optional message that will be printed that describes the failure.
  """
  if type(actual) != type(depset()) or not sets.is_equal(expected, actual):
    expectation_msg = "Expected %r, but got %r" % (expected, actual)
    _fail(env, expectation_msg, msg)


def _assert_set_subsets(env, expected, actual, msg=None):
  """Asserts that the given `expected` is a subset of `actual` set.

  Args:
    env: The test environment returned by `unittest.begin`.
    expected: The expected set resulting from some computation.
    actual: The actual set returned by some computation.
    msg: An optional message that will be printed that describes the failure.
  """
  if type(actual) != type(depset()) or not sets.is_subset(expected, actual):
    expectation_msg = "Expected %r, to be a subsest of %r" % (expected, actual)
    _fail(env, expectation_msg, msg)


asserts = struct(
    equals=_assert_equals,
    false=_assert_false,
    set_equals=_assert_set_equals,
    set_subsets=_assert_set_subsets,
    true=_assert_true,
)

unittest = struct(
    make=_make,
    suite=_suite,
    begin=_begin,
    end=_end,
    fail=_fail,
)
