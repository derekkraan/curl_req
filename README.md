# CurlReq

<!-- MDOC !-->

Req is awesome, but the world speaks curl.

Next time you're debugging a 3rd party API and need to ask for support, you can just toss in this line:

```elixir
|> CurlReq.inspect()
```

And you'll have the full curl command.

[Read the announcement here](https://codecodeship.com/blog/2024-06-03-curl_req).

## Usage

### Req to Curl
```elixir
# Turn a Req request into a `curl` command.

iex> Req.new(url: "/fact", base_url: "https://example.com/")
...> |> CurlReq.to_curl()
"curl --compressed -X GET https://example.com/fact" 

# Or use `CurlReq.inspect/2` to inspect inline.

Req.new(url: "https://example.com")
|> CurlReq.inspect()
|> Req.request!()
#=> curl --compressed -X GET https://example.com
```

### Curl to Req

`CurlReq` also implements the `~CURL` sigil, which converts a curl command to its corresponding Req request.

```elixir
iex> import CurlReq
...> ~CURL(curl https://www.example.com)
...> # |> Req.request!()

```

or use `CurlReq.from_curl/1`:
```elixir
iex> CurlReq.from_curl("curl https://example.com")
...> # |> Req.request!()

```

### Req Plugin

One final feature to note the Req plugin, `CurlReq.Plugin`. Use `CurlReq.Plugin.attach/2` to set up curl logging (inspired by `TeslaCurl`).

```elixir
iex> Req.new(url: "/fact", base_url: "https://example.com/")
...> |> CurlReq.Plugin.attach()
...> # |> Req.request!()

```

<!-- MDOC !-->

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

## Contributions

Contributions are welcome! There are gaps in the library, and this is open source, so let's work together to fill them!

## How to contribute

- Clone the repository to your computer.
- Add to your mix.exs file in your project: `{:curl_req, path: "~/path/to/curl_req"}`.
- Tinker until it does what you want.
- Add a test covering your case.
- Add a changelog entry if applicable.
- Submit a PR!
