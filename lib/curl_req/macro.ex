defmodule CurlReq.Macro do
  @moduledoc false

  # TODO: handle newlines
  # TODO: support -b (cookies)

  def parse(command) do
    command =
      command
      |> String.trim()
      |> String.trim_leading("curl")

    {options, [url], _invalid} =
      command
      |> OptionParser.split()
      |> OptionParser.parse(
        strict: [header: :keep, request: :string, data: :keep],
        aliases: [H: :header, X: :request, d: :data]
      )

    url = String.trim(url)
    %{url: url, options: options}
  end

  @doc false
  def to_req(%{url: url, options: options}) do
    %Req.Request{}
    |> Req.merge(url: url)
    |> add_header(options)
    |> add_method(options)
    |> add_body(options)
  end

  defp add_header(req, options) do
    headers = Keyword.get_values(options, :header)

    for header <- headers, reduce: req do
      req ->
        [key, value] =
          header
          |> String.split(":", parts: 2)

        Req.Request.put_header(req, String.trim(key), String.trim(value))
    end
  end

  defp add_method(req, options) do
    method =
      options
      |> Keyword.get(:request, "GET")
      |> String.downcase()
      |> String.to_existing_atom()

    Req.merge(req, method: method)
  end

  defp add_body(req, options) do
    body =
      case Keyword.get_values(options, :data) do
        [] -> nil
        data -> Enum.join(data, "&")
      end

    Req.merge(req, body: body)
  end
end
