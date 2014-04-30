defmodule ExtendUnit.Case do
  defmacro __using__(opts) do
    quote do
      ExtendUnit.ensure_started
      use ExUnit.Case, unquote(opts)
      import ExtendUnit.Case

      setup context do
        {:ok, pid} = ExtendUnit.Case.Worker.start(context)
        Process.put(ExtendUnit.Case.Worker, pid)
        :ok
      end

      teardown context do
        worker = Process.delete(ExtendUnit.Case.Worker)
        all_mocks_called = Enum.all? :gen_server.call(worker, :get_validations), &(&1.())
        :gen_server.call(worker, :teardown)
        assert all_mocks_called
        :ok
      end
    end
  end

  defmacro mock(call, instead, opts \\ []) do
    {module, meck_expect_arg, meck_validation_arg} = case instead do
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

    meck_expect_arg = quote do: fn -> :meck.expect(unquote_splicing(meck_expect_arg)) end

    meck_validation_arg = if Keyword.get(opts, :optional, false) do
      quote do: nil
    else
      quote do: fn -> :meck.called(unquote_splicing(meck_validation_arg)) end
    end

    module = Macro.expand(module, __CALLER__)
    expect_args = [module, meck_expect_arg, meck_validation_arg]
    quote do
      :ok = :gen_server.call(Process.get(ExtendUnit.Case.Worker), {:expect, unquote_splicing(expect_args)})
    end
  end

  defmodule Worker do
    use GenServer.Behaviour

    def start(context, tries \\ 1) do
      case :gen_server.start({:local, __MODULE__}, __MODULE__, [context, self()], []) do
        {:ok, pid} -> {:ok, pid}
        error = {:error, {:already_started, pid}} ->
          if tries < 6 do
            :timer.sleep(100)
            start(context, tries + 1)
          else
            error
          end
      end
    end

    def init([context, test_case_pid]) do
      Process.monitor(test_case_pid)
      {:ok, %{test_case_pid: test_case_pid, context: context, mocked_modules: HashSet.new, validations: []}}
    end

    def handle_call({:expect, module, meck_fun, validation}, _from, state) do
      unless Enum.member?(state.mocked_modules, module) do
        :meck.new(module, [:non_strict, :passthrough])
        state = %{state | mocked_modules: Set.put(state.mocked_modules, module)}
      end

      meck_fun.()

      if validation do
        state = %{state | validations: [validation | state.validations]}
      end

      {:reply, :ok, state}
    end

    def handle_call(:get_validations, _from, state) do
      {:reply, state.validations, state}
    end

    def handle_call(:teardown, _from, state) do
      perform_cleanup(state)
      {:stop, :normal, :ok, state}
    end

    def handle_info({:DOWN, _ref, :process, test_case_pid, _reason}, state = %{test_case_pid: test_case_pid}) do
      perform_cleanup(state)
      {:stop, :normal, state}
    end

    def perform_cleanup(state) do
      Enum.each state.mocked_modules, fn module ->
        try do
          :meck_proc.stop(module)
          bytecode = ExtendUnit.get_object_code(module)
          {:module, ^module} = :code.load_binary(module, '', bytecode)
        rescue
          value -> IO.puts "ExtendUnit teardown for #{inspect state.context} failed: #{value}"
        end
      end
    end

    def terminate(_reason, _state), do: :ok
  end
end
