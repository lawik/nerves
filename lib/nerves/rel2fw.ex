defmodule Nerves.Rel2fw do
  @moduledoc false
  def make_squashfs(build_dir, squashfs_priorities) do
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
  end

  defp check_mksquashfs() do
    case System.cmd("command", ["-v", "mksquashfs"]) do
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
    end

    with {:ok, %{type: directory} <- File.stat(Path.join(path, "lib")),
         {:ok, %{type: directory} <- File.stat(Path.join(path, "releases")) do
    else
      {:error, :enoent} ->
        Nerves
    end

  end
end
