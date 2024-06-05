# CurlReq

<!-- MDOC !-->

Req is awesome, but the world speaks curl.

Next time you're debugging a 3rd party API and need to ask for support, you can just toss in this line:

```elixir
|> CurlReq.inspect()
```

And you'll have the full curl command.

```elixir
# Turn a Req request into a `curl` command.

iex> Req.new(url: "/fact", base_url: "https://catfact.ninja/")
...> |> CurlReq.to_curl()
"curl -H \"accept-encoding: gzip\" -H \"user-agent: req/0.4.14\" -X GET https://catfact.ninja/fact" 

# Or use `CurlReq.inspect/2` to inspect inline.

iex> Req.new(url: "/fact", base_url: "https://catfact.nijna/")
...> |> CurlReq.inspect(label: "MY REQ")
...> # |> Req.request!()

```

`CurlReq` also implements the `~CURL` sigil, which converts a curl command to its corresponding Req request.

```elixir
iex> import CurlReq
...> ~CURL(curl https://www.google.com)
...> # |> Req.request!()

```

[Read the announcement here](https://codecodeship.com/blog/2024-06-03-curl_req).

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

- [ ] ~CURL sigil handles newlines
- [x] curl [url]
- [x] curl -H
- [x] curl -X
- [x] curl -d
- [x] curl -b
- [x] curl long form options (--header, --data, etc)
- [x] Req Plugin to log curl command (like `TeslaCurl`)

## How to contribute

- Clone the repository to your computer.
- Add to your mix.exs file in your project: `{:curl_req, path: "~/path/to/curl_req"}`.
- Tinker until it does what you want.
- Add a test covering your case.
- Add a changelog entry if applicable.
- Submit a PR!
