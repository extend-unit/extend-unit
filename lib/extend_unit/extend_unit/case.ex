defmodule ExtendUnit.Case do
  defmacro __using__(opts) do
    quote do
      ExtendUnit.ensure_started
      use ExUnit.Case, unquote(opts)
      import ExtendUnit.Case

      setup context do
        {:ok, pid} = ExtendUnit.Case.Worker.start_link(context)
        Process.put(ExtendUnit.Case.Worker, pid)
        :ok
      end

      teardown context do
        worker = Process.delete(ExtendUnit.Case.Worker)
        all_mocks_called = Enum.all? :gen_server.call(worker, :get_expectations), &(&1.())
        :gen_server.call(worker, :teardown)
        assert all_mocks_called
        :ok
      end
    end
  end

  defmacro mock(call, instead, opts \\ []) do
    {module, meck_expect_args, meck_validation_arg} = case instead do
      {:fn, _, _} ->
        case Macro.decompose_call(call) do
          {module, function, []} ->
            {module, [module, function, instead], [module, function, :_]}
          _ -> raise("invalid mock")
        end
      _ ->
        case Macro.decompose_call(call) do
          {module, function, args} ->
            args = Enum.map args, fn
              {:_, _, nil} -> :_
              arg -> arg
            end
            {module, [module, function, args, instead], [module, function, args]}
          _ -> raise("invalid mock")
        end
    end

    meck_validation_arg = if Keyword.get(opts, :optional, false) do
      meck_validation_arg = quote do: nil
    else
      meck_validation_arg = quote do: fn -> :meck.called(unquote_splicing(meck_validation_arg)) end
    end

    module = Macro.expand(module, __CALLER__)
    quote do
      worker = Process.get(ExtendUnit.Case.Worker)
      :ok = :gen_server.call(worker, {:expect, unquote(module), unquote(meck_validation_arg)})
      :meck.expect(unquote_splicing(meck_expect_args))
    end
  end

  defmodule Worker do
    use GenServer.Behaviour

    def start_link(context) do
      :gen_server.start_link(__MODULE__, context, [])
    end

    def init(context) do
      {:ok, %{context: context, mocked_modules: HashSet.new, expectations: []}}
    end

    def handle_call({:expect, module, new_expectation}, _from, state) do
      unless Enum.member?(state.mocked_modules, module) do
        :meck.new(module, [:non_strict, :passthrough])
        state = %{state | mocked_modules: Set.put(state.mocked_modules, module)}
      end
      if new_expectation do
        state = %{state | expectations: [new_expectation | state.expectations]}
      end
      {:reply, :ok, state}
    end

    def handle_call(:get_expectations, _from, state) do
      {:reply, state.expectations, state}
    end

    def handle_call(:teardown, _from, state) do
      Enum.each state.mocked_modules, fn module ->
        try do
          :meck_proc.stop(module)
          bytecode = ExtendUnit.get_object_code(module)
          {:module, ^module} = :erlang.load_module(module, bytecode)
        rescue
          value -> IO.puts "ExtendUnit teardown for #{inspect state.context} failed: #{value}"
        end
      end
      {:reply, :ok, state}
    end
  end
end
