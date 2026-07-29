# API client contract

The application talks only to HTTPS endpoints described in
`contracts/openapi.yaml`.

## Client requirements

- A compile-time public base URL may be configured; credentials must not ship.
- Use connect/read timeouts and bounded request/response bodies.
- Send `Content-Type: application/json`.
- Reject redirects from HTTPS to HTTP.
- Treat every non-2xx response as failure.
- Never block app startup, GO, testing, results, or settings on the API.
- Retry only transient failures with capped exponential backoff and jitter.
- Do not retry validation failures.
- Keep at most 100 consented telemetry events and drop oldest first.
- Bug reports are sent only after an explicit final confirmation.

## Authentication

Anonymous telemetry and bug reports use no embedded secret. Abuse controls
belong on the server. Administrative endpoints, if any, are outside the mobile
contract and must never share credentials with the app.

## Response handling

Ignore unrecognized response fields. Do not render server-provided HTML.
Display a neutral success/failure message for bug reports. Telemetry failures
remain silent and must not create user-facing noise.
