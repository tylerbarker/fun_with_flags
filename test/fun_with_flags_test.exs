defmodule FunWithFlagsTest do
  use ExUnit.Case, async: false
  import FunWithFlags.TestUtils
  import Mock

  doctest FunWithFlags

  setup_all do
    on_exit(__MODULE__, fn() -> clear_redis_test_db() end)
    :ok
  end

  describe "enabled?" do
    test "it returns false for non existing feature flags" do
      flag_name = unique_atom()
      assert false == FunWithFlags.enabled?(flag_name)
    end

    test "it returns false for a disabled feature flag" do
      flag_name = unique_atom()
      FunWithFlags.disable(flag_name)
      assert false == FunWithFlags.enabled?(flag_name)
    end

    test "it returns true for an enabled feature flag" do
      flag_name = unique_atom()
      FunWithFlags.enable(flag_name)
      assert true == FunWithFlags.enabled?(flag_name)
    end

    test "if the store returns anything other than {:ok, _}, it returns false" do
      name = unique_atom()
      {:ok, true} = FunWithFlags.enable(name)
      assert true == FunWithFlags.enabled?(name)

      store = FunWithFlags.Config.store_module

      with_mock(store, [], lookup: fn(^name) -> {:error, "mocked"} end) do
        assert false == FunWithFlags.enabled?(name)
      end
    end


    test "if the store raises an error, it lets it bubble up" do
      name = unique_atom()
      store = FunWithFlags.Config.store_module

      with_mock(store, [], lookup: fn(^name) -> raise(RuntimeError, "mocked exception") end) do
        assert_raise RuntimeError, "mocked exception", fn() ->
          FunWithFlags.enabled?(name)
        end
      end
    end
  end


  test "flags can be enabled and disabled" do
    flag_name = unique_atom()
    assert false == FunWithFlags.enabled?(flag_name)
    FunWithFlags.enable(flag_name)
    assert true == FunWithFlags.enabled?(flag_name)
    FunWithFlags.disable(flag_name)
    assert false == FunWithFlags.enabled?(flag_name)
  end


  test "enabling always returns the tuple {:ok, true} on success" do
    flag_name = unique_atom()
    assert {:ok, true} = FunWithFlags.enable(flag_name)
    assert {:ok, true} = FunWithFlags.enable(flag_name)
  end

  test "disabling always returns the tuple {:ok, false} on success" do
    flag_name = unique_atom()
    assert {:ok, false} = FunWithFlags.disable(flag_name)
    assert {:ok, false} = FunWithFlags.disable(flag_name)
  end

  describe "looking up a flag after a delay (indirectly test the cache TTL, if present)" do
    alias FunWithFlags.Config

    test "the flag value is still set even after the TTL of the cache (regardless of the cache being present)" do
      flag_name = unique_atom()

      assert false == FunWithFlags.enabled?(flag_name)
      {:ok, true} = FunWithFlags.enable(flag_name)
      assert true == FunWithFlags.enabled?(flag_name)

      timetravel by: (Config.cache_ttl + 10_000) do
        assert true == FunWithFlags.enabled?(flag_name)
      end
    end
  end
end
