defmodule Mix.Tasks.Nerves.Install.Docs do
  @moduledoc false

  def short_doc do
    "A short description of your task"
  end

  def example do
    "mix nerves.install --example arg"
  end

  def long_doc do
    """
    #{short_doc()}

    Longer explanation of your task

    ## Example

    ```bash
    #{example()}
    ```

    ## Options

    * `--example-option` or `-e` - Docs for your option
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Nerves.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        # Groups allow for overlapping arguments for tasks by the same author
        # See the generators guide for more.
        group: :nerves,
        dep_opts: [runtime: false],
        # A list of environments that this should be installed in.
        only: nil,
        # *other* dependencies to add
        # i.e `{:foo, "~> 2.0"}`
        adds_deps: [],
        # *other* dependencies to add and call their associated installers, if they exist
        # i.e `{:foo, "~> 2.0"}`
        installs: [
          {:igniter, "~> 0.6", only: [:dev, :test], override: true},
          {:shoehorn, "~> 0.9.1"},
          # TODO: Toolshed needs an installer to modify rootfs_overlay/etc/iex.exs
          {:toolshed, "~> 0.4.0"},
          # Old nerves_pack deps
          # TODO: nerves_ssh could have an installer for the some default config and authorized keys
          {:nerves_ssh, "> 0.0.0"},
          {:nerves_runtime,
           github: "nerves-project/nerves_runtime",
           branch: "igniter-installer",
           targets: [],
           override: true},
          {:nerves_time, github: "PJUllrich/nerves_time", branch: "add-igniter-install-task"},
          {:nerves_motd, "> 0.0.0"},
          {:ring_logger, github: "nerves-project/ring_logger", branch: "igniter-installer"},
          {:vintage_net, github: "maennchen/vintage_net", branch: "igniter", override: true},
          {:vintage_net_direct, "> 0.0.0"},
          {:vintage_net_ethernet, github: "maennchen/vintage_net_ethernet", branch: "jm/igniter"},
          {:vintage_net_wifi, github: "maennchen/vintage_net_wifi", branch: "jm/igniter"},
          {:mdns_lite, github: "wln/mdns_lite", branch: "igniter-warning-type-issue"}
        ],
        # An example invocation
        example: __MODULE__.Docs.example(),
        # a list of positional arguments, i.e `[:file]`
        positional: [],
        # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
        # This ensures your option schema includes options from nested tasks
        composes: [],
        # `OptionParser` schema
        schema: [],
        # Default values for the options in the `schema`
        defaults: [],
        # CLI aliases
        aliases: [],
        # A list of options in the schema that are required
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      # Do your work here and return an updated igniter
      igniter
      |> Igniter.add_warning("mix nerves.install is not yet implemented")
    end
  end
else
  defmodule Mix.Tasks.Nerves.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'nerves.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
