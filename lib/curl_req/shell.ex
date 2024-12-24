defmodule CurlReq.Shell do
  @moduledoc false

  # https://www.baeldung.com/linux/bash-escape-characters

  @escaped [
    {"\\", ~S(\\)},
    {~S($), ~S(\$)},
    {~S(`), ~S(\`)},
    {~S("), ~S(\")},
    {~S(!), ~S(\!)},
    {~S(~), ~S(\~)}
  ]

  @no_quotes ~r/^[a-zA-Z-,._+:@%\/]*$/

  @doc ~S"""
  Examples:
    iex> CurlReq.Shell.escape(~s(abc def))
    ~s("abc def")

    iex> CurlReq.Shell.escape(~s({"json":"is_cool"}))
    ~S("{\"json\":\"is_cool\"}")
  """
  def escape(arg) do
    if String.match?(arg, @no_quotes) do
      arg
    else
      arg =
        Enum.reduce(@escaped, arg, fn {from, to}, str ->
          String.replace(str, from, to)
        end)

      ~s("#{arg}")
    end
  end
end
