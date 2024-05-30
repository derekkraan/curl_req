defmodule CurlReq.Macro do
  def parse(string, acc \\ []) do
    case do_parse(string) do
      {out, rest} -> parse(rest, [out | acc])
      out -> [out | acc] |> Enum.filter(& &1) |> Enum.reverse()
    end
  end

  def do_parse(string, state \\ :nothing, accumulator \\ "")

  # def do_parse("\n" <> rest, state, acc) do
  #   do_parse(rest, state, acc)
  # end
  def do_parse(~S(") <> rest, :nothing, acc) do
    do_parse(rest, :double_quote, acc)
  end

  def do_parse(~S(") <> rest, :double_quote, acc) do
    do_parse(rest, :nothing, acc)
  end

  def do_parse(~S(') <> rest, :nothing, acc) do
    do_parse(rest, :single_quote, acc)
  end

  def do_parse(~S(') <> rest, :single_quote, acc) do
    do_parse(rest, :nothing, acc)
  end

  def do_parse(<<"\\", escaped>> <> rest, state, acc) when state in [:double_quote, :nothing] do
    do_parse(rest, state, [escaped | acc])
  end

  def do_parse(" " <> rest, :double_quote, acc) do
    do_parse(rest, :double_quote, [" " | acc])
  end

  def do_parse(" " <> rest, :nothing, acc) do
    emit(acc, rest)
    # do_parse(rest, :nothing, "")
  end

  def do_parse(<<byte, rest::binary>>, state, acc) do
    do_parse(rest, state, [<<byte>> | acc])
  end

  def do_parse("", _state, acc) do
    emit(acc, "")
  end

  def emit(acc, rest) do
    out =
      IO.iodata_to_binary(acc)
      |> String.reverse()

    case {out, rest} do
      {"", ""} -> nil
      {"", rest} -> {nil, rest}
      {out, ""} -> out
      {out, rest} -> {out, rest}
    end
  end
end
