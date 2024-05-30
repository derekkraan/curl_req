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

  @doc """
  This function takes the same arguments as `System.cmd/3`, but returns
  the command in string form instead of running the command.
  """
  @no_quotes ~r/^[a-zA-Z-,._+:@%\/]*$/
  def cmd_to_string(cmd, args) do
    final_args =
      args
      |> Enum.map(&escape/1)
      |> Enum.join(" ")

    "#{cmd} #{final_args}" |> String.trim_trailing()
  end

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
