defmodule ExtendUnit.ModuleSources do
  use GenServer.Behaviour

  def start_link do
    :gen_server.start_link({:local, __MODULE__}, __MODULE__, [], [])
  end

  def register_module(env, bytecode) do
    :gen_server.cast(__MODULE__, {:register_module, env.module, bytecode})
  end

  def get_object_code(module) do
    case :code.get_object_code(module) do
      {_, bytecode, _ } -> bytecode
      _ ->
        case :ets.lookup(__MODULE__, module) do
          [{^module, bytecode}] -> bytecode
          [] -> throw {:object_code_not_found, module}
        end
    end
  end

  # gen_server handler

  def init([]) do
    __MODULE__ = :ets.new(__MODULE__, [:protected, :set, :named_table])
    {:ok, []}
  end

  def handle_cast({:register_module, module, bytecode}, state) do
    :ets.insert(__MODULE__, {module, bytecode})
    {:noreply, state}
  end
end
