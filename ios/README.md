# Speedtest+ for iOS

Speedtest+ is an independently written iOS extension that mirrors the Android
Speedtest+ controls while preserving the stock iOS gauge animation and server
selection flow.

## Included

- Download and upload exact values or ranges
- Ping, jitter, and packet loss presentation controls
- ISP, server provider, and server location controls
- Three named profiles
- Ten persistent dark themes
- A one-time guide, active override badge, and password lock option
- Consistent local result details, compare labels, feedback text, sharing, and CSV
- Opt-in update checks for a sideloadable release
- No official remote result mutation

## Compatibility target

The current runtime map targets Speedtest 7.0.5 build 6 with bundle identifier
`com.ookla.speedtest`. The extension deployment target is iOS 12. Hooks fail
closed when a class or selector is absent.

## Build

This project requires macOS, Xcode, Theos, and a valid personal signing setup.
See [docs/BUILD_AND_SIGN.md](docs/BUILD_AND_SIGN.md).

The GitHub workflow performs source checks and an unsigned Theos compile on a
macOS runner. It does not sign or publish an IPA.

## Source boundaries

The `reference/` directory is ignored and must never be committed. It is used
only for local compatibility inspection. The public source contains no IPA,
decompiled application code, signing material, telemetry identifiers, or secrets.
