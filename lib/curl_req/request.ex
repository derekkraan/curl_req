defmodule CurlReq.Request do
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
          proxy: boolean(),
          proxy_auth: boolean(),
          auth: :none,
          encoding: :raw | :form | :json,
          body: term()
        }

  @type header() :: %{optional(String.t()) => [String.t()]}
  @type cookie() :: {String.t(), String.t()}
  @type auth() :: {auth_option(), String.t()} | auth_option()
  @type(auth_option() :: :none, :basic, :bearer, :netrc)

  # TODO: redact auth field
  defstruct flavor: :curl,
            flags: :short,
            headers: %{},
            cookies: %{},
            user_agent: nil,
            method: :get,
            url: URI.parse(""),
            compressed: false,
            redirect: false,
            proxy: false,
            proxy_auth: false,
            auth: :none,
            encoding: :raw,
            body: nil

  @doc """
  Puts the header into the CurlReq.Request struct
  """
  def put_header(%__MODULE__{} = request, "authorization", "Bearer " <> token) do
    %{request | auth: {:bearer, token}}
  end

  def put_header(%__MODULE__{} = request, key, val) when is_list(val) do
    headers = Map.put(request.headers, key, val)
    %{request | headers: headers}
  end

  def put_header(%__MODULE__{} = request, key, val) when is_binary(val) do
    headers = Map.put(request.headers, key, Enum.split(val, ";"))
    %{request | headers: headers}
  end

  @doc """
  Puts the cookie into the CurlReq.Request struct
  """
  def put_cookie(%__MODULE__{} = request, name, value)
      when is_binary(name) and is_binary(value) do
    values = Plug.Conn.Cookies.decode(value)
    cookies = Map.put(request.cookies, name, values)
    %{request | cookies: cookies}
  end

  @doc """
  Fetches the cookie into the CurlReq.Request struct
  """
  def fetch_cookie(%__MODULE__{} = request, name) when is_binary(name) do
    case Map.get(request.cookies, name) do
      nil ->
        nil

      # TODO: figure out cookie encoding
      value when is_map(value) ->
        for v <- value do
          Plug.Conn.Cookies.encode(v)
        end
    end
  end

  @doc """
  Puts the body and optional encoding into the CurlReq.Request struct
  """
  def put_body(%__MODULE__{} = request, body, encoding \\ :raw)
      when encoding in [:raw, :form, :json] do
    %{request | body: body, encoding: encoding}
  end

  @doc """
  Puts the method into the CurlReq.Request struct
  """
  def put_method(%__MODULE__{} = request, method)
      when method in [:get, :head, :put, :post, :delete] do
    %{request | method: method}
  end

  def put_method(%__MODULE__{} = request, method) when is_binary(method) do
    method =
      method
      |> String.downcase()
      |> String.to_existing_atom()

    %{request | method: method}
  end

  @doc """
  Sets a request option
  """
  def configure(%__MODULE__{} = request, options) do
    options = Keyword.validate!(options, [:compressed, :redirect, :proxy, :proxy_auth])
    Enum.into(options, request)
  end

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
