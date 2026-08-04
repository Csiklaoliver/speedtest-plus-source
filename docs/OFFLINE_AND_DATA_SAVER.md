# Offline and data-saver testing

Speedtest+ now exposes two explicit test modes on Android and iOS. Both modes
are opt-in and mutually exclusive. With both switches off, the normal measured
test path is unchanged.

## Offline demo

Offline demo is a local UI simulation for demos, accessibility checks, and
layout testing. It never opens a test connection, discovers a server, uploads
telemetry, or submits a result to a remote provider. It finishes with clearly
labelled local values and the saved result carries `offline_demo: true` and
`remote_submission_allowed: false`.

Because it does not contact a server, offline demo cannot measure an internet
connection and must not be described as a real speed test. The result is marked
as a local simulation wherever the platform adapter has a result/status label.

## Data saver

Data saver keeps a real network test, but applies a conservative native budget:

- maximum duration: 2 seconds per direction;
- minimum duration: 1 second per direction;
- maximum transfer: 262,144 bytes per connection and direction.

The total device traffic can be higher because a native engine may use several
connections and protocol overhead. The setting is therefore a bounded budget,
not a promise of an exact total byte count. Server discovery and connection
setup still require network access. If the user must use zero data, choose
Offline demo instead.

## Controls

The switches are in the Speedtest+ Controls panel under **Test modes**.

- Android: enable one checkbox, then start the test normally.
- iOS: enable one switch and tap **Apply**, then start the test normally.
- Enabling one mode automatically disables the other.
- **Disable All** turns both modes off and returns to native measured testing;
  profiles and themes are retained.

The controls explain the behavior in-app so users do not mistake an offline
demo or shortened test for a provider measurement.

## Adapter limits

The public repository contains clean-room state and integration contracts, not
the proprietary Speedtest engine. Android APK patches require a legally
obtained base APK and a local rebuild; the iOS source requires the project’s
normal Theos/Xcode build environment. If a private native build does not expose
the documented suite configuration setters, the adapter leaves that part of
the native engine untouched rather than risking a startup crash.

## Verification checklist

1. Start with both modes off and confirm server discovery and measured results.
2. Enable Offline demo, disable Wi-Fi and mobile data, and confirm the test
   still completes with a local-only label and no network request.
3. Enable Data saver with network available and confirm the native duration and
   byte limits are applied; verify that server discovery still works.
4. Toggle either mode while a test is running only for the next test; do not
   interrupt an active native transfer.
5. Use **Disable All** and confirm the next run is measured again.
6. Verify that a shared offline result is labelled as local simulation and is
   never sent to a remote provider.
