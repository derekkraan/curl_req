# Changelog

## 0.100.0

### Breaking Changes

- Switch some flag positions in the generated cURL command ([#29](https://github.com/derekkraan/curl_req/pull/29))
- From cURL to Req the body gets encoded in the specified encoding and set in the correct Req option ([#29](https://github.com/derekkraan/curl_req/pull/29), [#39](https://github.com/derekkraan/curl_req/pull/39))
- User Agent is encoded in the user agent flag (`--user-agent`/`-A`) instead of a generic header ([#32](https://github.com/derekkraan/curl_req/pull/32))
- `--data`/`-d` flag now get's correctly interpreted as "form-urlencoded" instead of "raw" ([#39](https://github.com/derekkraan/curl_req/pull/39))
- If body is set in `Req`, and no encoding is specified the "content-type: text/plain" header is added ([#39](https://github.com/derekkraan/curl_req/pull/39))
- Content-Type is only set, when body is not `nil` ([#39](https://github.com/derekkraan/curl_req/pull/39))
- Method is automatically set to `:post` when some data is specified via `--data`/`-d` ([#39](https://github.com/derekkraan/curl_req/pull/39))

### Enhancements

- New `CurlReq.Request` module for an internal representation of the HTTP request ([#29](https://github.com/derekkraan/curl_req/pull/29))
- Add new supported flag: `--insecure`/`-k` ([#31](https://github.com/derekkraan/curl_req/pull/31))
- Improved documentation
- Added Livebook and cURL Cheatsheet ([#35](https://github.com/derekkraan/curl_req/pull/35))
- `http` scheme is now optional in cURL command ([#38](https://github.com/derekkraan/curl_req/pull/38))
- Added more flags to parser, to avoid errors for common flags ([#37](https://github.com/derekkraan/curl_req/pull/37))

### Bugfixes

- Some bugfixes regarding the constructed `Req.Request` struct when multiple request steps have to be set

## 0.99.0

- Add new supported flags: `--proxy` and `--proxy-user` ([#26](https://github.com/derekkraan/curl_req/pull/26))
- Add more supported auth steps: `netrc` and `netrc_file` ([#19](https://github.com/derekkraan/curl_req/pull/19))
- Add option to exclude `req` steps to run when generating the cURL command
- Raise on unrecognized `curl` flags ([#27](https://github.com/derekkraan/curl_req/pull/27))

## 0.98.6
- Handle `--data-raw` and `--data-ascii` ([#16](https://github.com/derekkraan/curl_req/pull/16))
- Strip `$` as necessary

## 0.98.5
- Multiline Curl commands are now supported
- `to_curl/2` now supports short and long argument flag generation
- `to_curl/2` now uses a native curl representation. Can be switched to be exactly like the `Req.Request` with the `flavor` option
- `from_curl/1` now supports the `--compressed` flag

## 0.98.4
- Add CurlReq.Plugin
- Add new supported flags: `--head`, `--form`, `--user` and `--location`
- Add `CurlReq.from_curl/1`
- Improved docs and added typespecs

## 0.98.3
- Change `ex_doc` to a dev dependency.
- Support iodata in Req.Request.body.
- Handle cookies in both directions ([#4](https://github.com/derekkraan/curl_req/pull/4))

## 0.98.2
- Handle multiple -d/--data flags ([#3](https://github.com/derekkraan/curl_req/pull/3))

## 0.98.1
- Handle long curl options (eg, --data, --header) ([#2](https://github.com/derekkraan/curl_req/pull/2))

## 0.98.0
Initial Release!
