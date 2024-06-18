# Changelog

## 0.98.5
- Multiline Curl commands are now supported
- `to_curl/2` now supports short and long argument flag generation
- `to_curl/2` now uses native curl compression mechanics by default. Can be switched to be exactly like the `Req.Request` with the `mode` option

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
