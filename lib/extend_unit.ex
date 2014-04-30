defmodule ExtendUnit do
  use Application.Behaviour
  defdelegate get_object_code(module), to: ExtendUnit.ModuleSources

  def ensure_started do
    {:ok, _} = :application.ensure_all_started(:extend_unit)
  end

  # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
  # for more information on OTP Applications
  def start(_type, _args) do
    ExtendUnit.Supervisor.start_link
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
        @after_compile { ExtendUnit.ModuleSources, :register_module }
        unquote(block)
      end
    end
  end
end
