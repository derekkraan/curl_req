# CurlReq

<!-- MDOC !-->

Req is awesome, but the rest of the world speaks Curl.

CurlReq provides two features:

```elixir
# Turn a Req request into a `curl` command!

## Examples

    iex> Req.new(url: "/fact", base_url: "https://catfact.ninja/")
    ...> |> CurlReq.to_curl()
    "curl -H \"accept-encoding: gzip\" -H \"user-agent: req/0.4.14\" -X GET https://catfact.ninja/fact" 

# Or use `CurlReq.inspect/2` to inspect inline!

    iex> Req.new(url: "/fact", base_url: "https://catfact.nijna/")
    ...> |> CurlReq.inspect(label: "MY REQ")
    ...> # |> Req.request!()

```

```elixir
# Turn a CURL command into a Req request with the ~CURL sigil!

## Examples

    iex> import CurlReq
    ...> ~CURL(curl https://www.google.com)
    ...> # |> Req.request!()

```

## Installation

The package can be installed
by adding `curl_req` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:curl_req, "~> 0.98.0"}
  ]
end
```

The docs can be found at <https://hexdocs.pm/curl_req>.
