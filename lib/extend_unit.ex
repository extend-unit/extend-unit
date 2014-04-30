defmodule ExtendUnit do
  use Application.Behaviour

  def ensure_started do
    {:ok, _} = :application.ensure_all_started(:extend_unit)
  end

  # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
  # for more information on OTP Applications
  def start(_type, _args) do
    :ets.new(ExtendUnit.ModuleSources, [:public, :set, :named_table])
    ExtendUnit.Supervisor.start_link
  end

  def get_object_code(module) do
    case :code.get_object_code(module) do
      {_, bytecode, _ } -> bytecode
      _ ->
        case :ets.lookup(ExtendUnit.ModuleSources, module) do
          [{^module, bytecode}] -> bytecode
          [] -> throw {:object_code_not_found, module}
        end
    end
  end

  def register_module(env, bytecode) do
    :ets.insert(ExtendUnit.ModuleSources, {env.module, bytecode})
  end

  defmacro __using__(opts) do
    quote do
      import Kernel, except: [defmodule: 2]
      import ExtendUnit, only: [defmodule: 2]
    end
  end

  defmacro defmodule(name, do: block) do
    ExtendUnit.ensure_started
    name = Macro.expand(name, __CALLER__)
    quote do
      Kernel.defmodule unquote(name) do
        @after_compile { ExtendUnit, :register_module }
        unquote(block)
      end
    end
  end
end
