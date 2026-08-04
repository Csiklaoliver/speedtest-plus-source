# Connection Health

Speedtest+ Controls includes **Check connection health** for troubleshooting
server-list and setup reports without starting a speed test.

## What it checks

- In **Offline demo**, no network request is made. The result says that
  internet/DNS/TLS was not checked and server-list readiness is not applicable.
- In normal mode, the check sends one `HEAD` request to the official
Speedtest+ HTTPS manifest endpoint. The request has a 4-second (4 seconds)
  request timeout and a 5-second (5 seconds) total resource timeout. It never downloads a test
  payload, measures bandwidth, or starts a speed test.
- An HTTP response in the normal 100–599 range means the transport reached the
  endpoint, even when the endpoint rejects `HEAD` with a status such as 405.
  DNS, TLS, timeout, and connection failures are shown as short fixed status
  messages instead of raw error text.

## Server-list readiness

The readiness line is local UI state. It says **Native provider row ready** only
when the native provider row has been observed in the current app session;
otherwise it says **Not observed yet**. It is not a remote server-catalog probe,
does not select a server, and does not change the native server selection or
native provider flow.

## Privacy

The check uses an ephemeral URL session with cookies and cache disabled. It does
not read or send IP addresses, device identifiers, account identifiers, ISP or
provider text, server location, contacts, or precise location. No result is
saved and no remote Ookla/Speedtest report is submitted. The summary always ends
with **No speed test was started.**

This is a transport hint, not a guarantee that every provider or speed-test
server will accept a later test. If the check passes but a test cannot start,
keep the selected native server and report the app version, device, and the
exact visible error without sharing private identifiers or credentials.
