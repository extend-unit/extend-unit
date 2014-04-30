use ExtendUnit

defmodule ExtendUnit.CaseTest do
  use ExtendUnit.Case
  defmodule Demo do
    def foo do
      "foo"
    end

    def foo(1, 2) do
      "foo 1, 2"
    end

    def passed_through do
      "unchanged"
    end
  end

  test "mocks using fn" do
    mock Demo.foo, fn -> "bar" end
    mock Demo.foo, fn(i, 2) -> "bar #{i}" end
    assert Demo.foo == "bar"
    assert Demo.foo(1, 2) == "bar 1"
  end

  test "mocks using args" do
    assert Demo.foo == "foo"
    assert Demo.foo(1, 2) == "foo 1, 2"

    mock Demo.foo, "bar"
    mock Demo.foo(_, 2), "bar 1, 2"
    mock Demo.passed_through, "bar", optional: true

    assert Demo.foo == "bar"
    assert Demo.foo(1, 2) == "bar 1, 2"
  end

  test "correctly unmocks between tests" do
    assert Demo.foo == "foo"
  end

  test "allows passthrough" do
    assert Demo.foo == "foo"
    mock Demo.foo, "bar"
    assert Demo.foo == "bar"

    assert Demo.passed_through == "unchanged"
  end
end
