defmodule Nerves.Rel2fw do
  @moduledoc false
  def make_squashfs(build_dir, squashfs_priorities, release_path, rootfs_overlays) do
    tmp_dir = Path.join(build_dir, "_nerves-tmp")
    File.rm_rf(tmp_dir)
    File.mkdir_p(tmp_dir)

    # Create a base priority file
    #
    # Seed it with erlinit being the highest priority since we know those
    # files are guaranteed to be in the filesystem and accessed first on
    # boot.
    tmp_dir
    |> Path.join("squashfs.priority")
    |> File.write!("""
    sbin/init 32764
    etc/erlinit.config 32763
    """)

    mksquash_fs_path = check_mksquashfs()
    check_release_dir(release_path)
    # Update the file system bundle
    Nerves.Utils.Shell.info("Updating base firmware image with Erlang release...")

    # Construct the proper path for the Erlang/OTP release
    erlang_path = Path.join(tmp_dir, "rootfs_overlay/srv/erlang")
    File.mkdir_p!(erlang_path)
    File.cp_r!(release_path, erlang_path, on_conflict: fn _, _ -> true end)

    # TODO: unfurl this scrubber code into Elixir as well?
    # Clean up the Erlang release of all the files that we don't need.
    scrub_script = Path.join(System.get_env("NERVES_SYSTEM"), "scripts/scrub-otp-release.sh")
    {output, status} = System.shell("#{scrub_script} #{erlang_path}")
    if status > 0 do
      Nerves.Utils.Shell.error("Failed to scrub OTP release:\n#{output}")
    end

    # Copy over any rootfs overlays from the user
    # IMPORTANT: This must be the final step before the merge so that the user can
    #            override anything.
    dbg(rootfs_overlays)
  end

  defp check_mksquashfs() do
    case System.shell("command -v mksquashfs") do
      {path, 0} ->
        String.trim(path)

      _ ->
        Nerves.Utils.Shell.error("""
        Please install mksquashfs first

        For example:
          sudo apt-get install squashfs-tools
          brew install squashfs
        """)

        System.halt(1)
    end
  end

  defp check_release_dir(path) do
    case File.stat(path) do
      {:ok, %{type: :directory}} ->
        :ok

      {:error, :enoent} ->
        Nerves.Utils.Shell.error("Missing erlang release directory: #{path}")
        System.halt(1)
    end

    with {:ok, %{type: directory}} <- File.stat(Path.join(path, "lib")),
         {:ok, %{type: directory}} <- File.stat(Path.join(path, "releases")) do
    else
      {:error, :enoent} ->
        Nerves.Utils.Shell.error("Expecting #{path} to contain 'lib' and 'releases' subdirectories")
        System.halt(1)
    end

  end
end
