defmodule CurlReq.Macro do
  @moduledoc false

  def parse(string, acc \\ []) do
    case do_parse(string) do
      {out, rest} -> parse(rest, [out | acc])
      out -> [out | acc] |> Enum.filter(& &1) |> Enum.reverse()
    end
  end

  def do_parse(string, state \\ :nothing, accumulator \\ "")

  #
  # TODO handle newlines
  #
  # def do_parse("\n" <> rest, state, acc) do
  #   do_parse(rest, state, acc)
  # end
  #

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

  #
  # TODO support -b (cookies)
  #
  # results in header `Cookie` with subsequent cookies separated by `; `
  #

  @doc false
  def to_req(["curl" | rest]) do
    to_req(rest, %Req.Request{})
  end

  @doc false
  def to_req([option, header | rest], req) when option in ["-H", "--header"] do
    [key, value] = String.split(header, ":", parts: 2)
    new_req = Req.Request.put_header(req, String.trim(key), String.trim(value))
    to_req(rest, new_req)
  end

  def to_req([option, method | rest], req) when option in ["-X", "--request"] do
    new_req = Req.merge(req, method: method)
    to_req(rest, new_req)
  end

  #
  # TODO support multiple -d
  #
  def to_req([option, body | rest], req) when option in ["-d", "--body"] do
    new_req = Req.merge(req, body: body)
    to_req(rest, new_req)
  end

  def to_req([url | rest], req) do
    new_req = Req.merge(req, url: url)
    to_req(rest, new_req)
  end

  def to_req([], req), do: req
end
