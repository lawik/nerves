# Don't include the igniter utilities in production usage
if Code.ensure_loaded?(Igniter) do
  defmodule Nerves.Igniter do

  end
end
