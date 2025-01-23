defmodule Nerves.Steps do
  @moduledoc """
  Mix Release steps for Nerves.

  Allows composing and decomposing Nerves builds.
  """

  @switches [verbose: :boolean, output: :string]
  @default_mksquashfs_flags ["-no-xattrs", "-quiet"]

  import Mix.Nerves.Utils

  require Logger

  def build(%Mix.Release{} = release) do
    %{
      release
      | steps: release.steps ++ [&make_squashfs/1, &create_firmware/1]
    }
  end

  def make_squashfs(%Mix.Release{} = release) do
    system_path = check_nerves_system_is_set!()
    config = Mix.Project.config()
    fw_out = Nerves.Env.firmware_path(config)
    otp_app = config[:app]
    firmware_config = Application.get_env(:nerves, :firmware)
    mksquashfs_flags = firmware_config[:mksquashfs_flags] || @default_mksquashfs_flags
    set_mksquashfs_flags(mksquashfs_flags)

    rootfs_priorities =
      Nerves.Env.package(:nerves_system_br)
      |> rootfs_priorities()

    if firmware_config[:rootfs_additions] do
      Mix.shell().error(
        "The :rootfs_additions configuration option has been deprecated. Please use :rootfs_overlay instead."
      )
    end

    build_rootfs_overlay = Path.join([Mix.Project.build_path(), "nerves", "rootfs_overlay"])
    File.mkdir_p!(build_rootfs_overlay)

    write_erlinit_config(build_rootfs_overlay)

    project_rootfs_overlay =
      case firmware_config[:rootfs_overlay] || firmware_config[:rootfs_additions] do
        nil ->
          []

        overlays when is_list(overlays) ->
          overlays

        overlay ->
          [Path.expand(overlay)]
      end

    prevent_overlay_overwrites!(project_rootfs_overlay)

    rootfs_overlays =
      [build_rootfs_overlay | project_rootfs_overlay]
      |> List.flatten()

    release_path = Path.join(Mix.Project.build_path(), "rel/#{otp_app}")

    set_provisioning(firmware_config[:provisioning])

    config
    |> Nerves.Env.images_path()
    |> File.mkdir_p!()

    Nerves.Rel2fw.make_squashfs(
      build_dir(),
      project_dir(),
    )
    Logger.error("make_squashfs not fully implemented")
    release
  end

  defp build_dir() do
    System.get_env("MIX_BUILD_PATH", Path.join(File.cwd!(), "_build"))
  end

  defp project_dir() do
    Path.basename(File.cwd!())
  end

  def create_firmware(%Mix.Release{} = release) do
    Logger.error("create_firmware not implemented")
    release
  end

  defp write_erlinit_config(build_overlay) do
    with user_opts <- Application.get_env(:nerves, :erlinit, []),
         {:ok, system_config_file} <- Nerves.Erlinit.system_config_file(Nerves.Env.system()),
         {:ok, system_config_file} <- File.read(system_config_file),
         system_opts <- Nerves.Erlinit.decode_config(system_config_file),
         erlinit_opts <- Nerves.Erlinit.merge_opts(system_opts, user_opts),
         erlinit_config <- Nerves.Erlinit.encode_config(erlinit_opts) do
      erlinit_config_file = Path.join(build_overlay, "etc/erlinit.config")

      Path.dirname(erlinit_config_file)
      |> File.mkdir_p!()

      header = erlinit_config_header(user_opts)

      File.write!(erlinit_config_file, header <> erlinit_config)
    else
      {:error, :no_config} ->
        Nerves.Utils.Shell.warn("There was no system erlinit.config found")
        :ok

      e ->
        Nerves.Utils.Shell.warn("Error constructing  erlinit.config: #{inspect(e)}")
        :ok
    end
  end

  defp set_mksquashfs_flags(flags) when is_list(flags) do
    System.put_env("NERVES_MKSQUASHFS_FLAGS", Enum.join(flags, " "))
  end

  @restricted_fs ["data", "root", "tmp", "dev", "sys", "proc"]
  defp prevent_overlay_overwrites!(overlay_dirs) do
    shadow_mounts =
      for dir <- overlay_dirs,
          p <- Path.wildcard([dir, "/*"]),
          fs_dir = Path.relative_to(p, dir),
          fs_dir in @restricted_fs,
          Path.wildcard([p, "/*"]) != [],
          do: Path.relative_to_cwd(p)

    if length(shadow_mounts) > 0 do
      Mix.raise("""
      The firmware contains overlay files which reference directories that are
      mounted as file systems on the device. The filesystem mount will completely
      overwrite the overlay and these files will be lost.

      Remove the following overlay directories and build the firmware again:

      #{for dir <- shadow_mounts, do: "  * #{dir}\n"}
      #{IO.ANSI.reset()}https://hexdocs.pm/nerves/advanced-configuration.html#root-filesystem-overlays
      """)
    end
  end

  # Need to check min version for nerves_system_br to check if passing the
  # rootfs priorities option is supported. This was added in the 1.7.1 release
  # https://github.com/nerves-project/nerves_system_br/releases/tag/v1.7.1
  defp rootfs_priorities(%Nerves.Package{app: :nerves_system_br, version: vsn}) do
    case Version.compare(vsn, "1.7.1") do
      r when r in [:gt, :eq] ->
        rootfs_priorities_file =
          Path.join([Mix.Project.build_path(), "nerves", "rootfs.priorities"])

        if File.exists?(rootfs_priorities_file) do
          ["-p", rootfs_priorities_file]
        else
          []
        end

      _ ->
        []
    end
  end

  defp rootfs_priorities(_), do: []

  @doc false
  @spec erlinit_config_header(Keyword.t()) :: String.t()
  def erlinit_config_header(opts) do
    """
    # Generated from rootfs_overlay/etc/erlinit.config
    """ <>
      if opts != [] do
        """
        # with overrides from the application config
        """
      else
        """
        """
      end
  end
end
