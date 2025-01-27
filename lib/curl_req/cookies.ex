defmodule CurlReq.Cookies do
  @moduledoc false

  # Vendored from https://github.com/elixir-plug/plug/blob/main/lib/plug/conn/cookies.ex

  @doc """
  Decodes the given cookies as given in either a request or response header.

  If a cookie is invalid, it is automatically discarded from the result.

  ## Examples

      iex> decode("key1=value1;key2=value2")
      %{"key1" => "value1", "key2" => "value2"}

  """
  def decode(cookie) when is_binary(cookie) do
    Map.new(decode_kv(cookie, []))
  end

  defp decode_kv("", acc), do: acc
  defp decode_kv(<<h, t::binary>>, acc) when h in [?\s, ?\t], do: decode_kv(t, acc)
  defp decode_kv(kv, acc) when is_binary(kv), do: decode_key(kv, "", acc)

  defp decode_key(<<h, t::binary>>, _key, acc) when h in [?\s, ?\t, ?\r, ?\n, ?\v, ?\f],
    do: skip_until_cc(t, acc)

  defp decode_key(<<?;, t::binary>>, _key, acc), do: decode_kv(t, acc)
  defp decode_key(<<?=, t::binary>>, "", acc), do: skip_until_cc(t, acc)
  defp decode_key(<<?=, t::binary>>, key, acc), do: decode_value(t, "", 0, key, acc)
  defp decode_key(<<h, t::binary>>, key, acc), do: decode_key(t, <<key::binary, h>>, acc)
  defp decode_key(<<>>, _key, acc), do: acc

  defp decode_value(<<?;, t::binary>>, value, spaces, key, acc),
    do: decode_kv(t, [{key, trim_spaces(value, spaces)} | acc])

  defp decode_value(<<?\s, t::binary>>, value, spaces, key, acc),
    do: decode_value(t, <<value::binary, ?\s>>, spaces + 1, key, acc)

  defp decode_value(<<h, t::binary>>, _value, _spaces, _key, acc)
       when h in [?\t, ?\r, ?\n, ?\v, ?\f],
       do: skip_until_cc(t, acc)

  defp decode_value(<<h, t::binary>>, value, _spaces, key, acc),
    do: decode_value(t, <<value::binary, h>>, 0, key, acc)

  defp decode_value(<<>>, value, spaces, key, acc),
    do: [{key, trim_spaces(value, spaces)} | acc]

  defp skip_until_cc(<<?;, t::binary>>, acc), do: decode_kv(t, acc)
  defp skip_until_cc(<<_, t::binary>>, acc), do: skip_until_cc(t, acc)
  defp skip_until_cc(<<>>, acc), do: acc

  defp trim_spaces(value, 0), do: value
  defp trim_spaces(value, spaces), do: binary_part(value, 0, byte_size(value) - spaces)
end
