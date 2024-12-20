defmodule CurlReq.Curl do
  @type t() :: %__MODULE__{
          flavor: :curl | :req,
          flags: :short | :long,
          headers: [header()],
          cookies: [cookie()],
          user_agent: String.t(),
          method: :get | :head | :put | :post | :delete,
          url: URI.t(),
          compressed: boolean(),
          redirect: boolean(),
          data: boolean(),
          proxy: boolean(),
          proxy_auth: boolean(),
          auth: :none
        }

  @type header() :: %{optional(String.t()) => [String.t()]}
  @type cookie() :: {String.t(), String.t()}
  @type auth() :: {auth_option(), String.t()} | auth_option()
  @type(auth_option() :: :none, :basic, :bearer, :netrc)

  defstruct flavor: :curl,
            flags: :short,
            headers: [],
            cookies: [],
            user_agent: nil,
            method: :get,
            url: URI.parse(""),
            compressed: false,
            redirect: false,
            data: false,
            proxy: false,
            proxy_auth: false,
            auth: false

  def to_curl(%__MODULE__{} = request) do
    headers =
      for {key, val} <- request.headers do
        val = Enum.intersperse(val, ";")
        ["-H \"", key, ": ", val, "\""]
      end

    ["curl", headers, request.url] |> Enum.intersperse(" ") |> IO.iodata_to_binary()
  end

  def to_req(%__MODULE__{} = request, _opts \\ []) do
    %Req.Request{}
    |> Req.merge(url: request.url)
    |> add_header(request.headers)
  end

  defp add_header(req, headers) do
    for {key, value} <- headers, reduce: req do
      req ->
        Req.Request.put_header(req, key, value)
    end
  end
end
