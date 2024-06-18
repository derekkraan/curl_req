defmodule CurlReq.Plugin do
  require Logger

  @moduledoc """
  A collection of steps, usable with Req.

  > #### Info {: .info}
  >
  > This plugin needs to be added behind any other Req.Steps. Steps add headers and change the request, and this all has to be done _before_ converting the request to a curl command.

  ## Examples

      iex> Req.new(url: "https://catfact.ninja/fact")
      ...> |>CurlReq.Plugin.attach()

      iex> Req.new(url: "https://catfact.ninja/fact")
      ...> |> CurlReq.Plugin.attach(log_level: :info, log_metadata: [ansi_color: :blue])

  # Possible improvements

  This module could be improved. PRs are welcome!

  - [ ] configure redaction on a per-header basis

  See also [TeslaCurl](https://hexdocs.pm/tesla_curl/readme.html) for inspiration.
  """

  @doc "Req step: logs the request."
  def log(request) do
    log_level = request.options[:log_level] || :debug
    metadata = request.options[:log_metadata] || []

    Logger.log(log_level, fn -> CurlReq.to_curl(request, run_steps: false) end, metadata)

    request
  end

  @type option :: {:log_level, Logger.level()} | {:log_metadata, any()}

  @doc "Attaches the plugin, main entry point for this module."
  @spec attach(Req.Request.t(), [option()]) :: Req.Request.t()
  def attach(%Req.Request{} = request, options \\ []) do
    request
    |> Req.Request.register_options([:log_level, :log_metadata])
    |> Req.Request.merge_options(options)
    |> Req.Request.append_request_steps(curl_req: &log/1)
  end
end
