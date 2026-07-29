# Privacy and telemetry contract

Analytics is optional, off by default, and intended only to answer aggregate
product questions such as which screens and features are used and whether a
workflow succeeds.

## Consent

- Show a concise explanation before the first opt-in.
- “Not now” and “Allow” receive equal visual weight.
- Store `unknown`, `declined`, or `granted` locally.
- Provide a permanent settings switch.
- Withdrawing consent deletes the local queue immediately.
- Do not upload historical events collected before consent.

## Allowed data

- Random event ID used only for de-duplication.
- App version, platform, OS major version, and coarse device class.
- Allowlisted screen/feature name.
- Success boolean and coarse duration bucket.
- Theme source (`built_in` or `shared_code`), not the theme payload.

## Prohibited data

- Advertising, hardware, Android, Apple, SIM, or account identifiers.
- IP address stored as product telemetry.
- Precise location, SSID/BSSID, contacts, phone number, or email.
- User-entered ISP/server labels or custom metric values.
- Full URLs, clipboard contents, screenshots, or background logs.
- Free-form analytics property names or values.

## Server rules

- Validate against `telemetry-event.schema.json`.
- Discard the request IP after normal network processing; do not persist it.
- Rate-limit by short-lived keyed hash if abuse protection is necessary.
- Keep raw events no longer than 30 days.
- Keep only aggregated counts beyond raw-event retention.
- Provide a public deletion/contact route even though events are anonymous.
- Return no cross-site tracking cookies.

Bug reports are a separate explicit user action. The report preview must show
everything that will be submitted and allow editing before send.
