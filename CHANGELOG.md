# Changelog

## 0.100.0

- [BREAKING]: Switch some flag positions in the generated cURL command
- Some bugfixes regarding the constructed `Req.Request` struct when multiple request steps have to be set
- [BREAKING]: From cURL to Req the body gets encoded in the specified encoding and set in the correct Req option
- [BREAKING]: User Agent is encoded in the user agent flag (`--user-agent`/`-A`) instead of a generic header ([#32](https://github.com/derekkraan/curl_req/pull/32))
- New `CurlReq.Request` module for an internal representation of the HTTP request ([#29](https://github.com/derekkraan/curl_req/pull/29))
- Add new supported flag: `--insecure`/`-k` ([#31](https://github.com/derekkraan/curl_req/pull/31))
- Improved documentation

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
