# Speedtest+ original source kit

This is the public, clean-room source package for the original Speedtest+
helpers. It provides portable logic and contracts for:

- validating optional metric and provider overrides;
- generating realistic display samples that finish on one exact saved value;
- explicit, revocable analytics consent;
- privacy-preserving usage-event and bug-report contracts;
- offline demo and bounded data-saver test modes;
- custom theme codes with integrity checks;
- a signed-update manifest contract; and
- Android integration and a review-ready iOS extension source tree.

> **Important:** customized values are local simulation and presentation
> controls. They are not independently measured network performance and are
> not the provider's official remote report. Never present a customized result
> as genuine evidence for billing disputes, sales, employment, competitions,
> service-level claims, fraud, or any other deceptive purpose.

It is deliberately **not** a buildable copy of any third-party application.
You must supply your own legally obtained base APK or decrypted IPA and perform
integration locally. No third-party APK, IPA, decoded resources, signing material, or
credentials belong in this repository.

## Requirements

- JDK 8 or newer
- Node.js 18 or newer
- macOS, Xcode, and Theos only when compiling the optional iOS extension

## Verify

```sh
npm test
```

The verification suite compiles the dependency-free Java core, runs behavioral
tests, parses all JSON contracts/examples, and scans the public tree for
forbidden binaries, absolute local paths, and common secret patterns.

The iOS extension has additional checks:

```sh
cd ios
python3 Scripts/verify_project.py
python3 -m unittest discover -s Tests -v
python3 Scripts/verify_objc_syntax.py
```

## Layout

- `src/main/java/` - original, platform-neutral Java helpers.
- `ios/` - independently written iOS tweak source, runtime inspection tools,
  build instructions, and reviewer checklist.
- `schemas/` - JSON Schema contracts for app/server boundaries.
- `contracts/openapi.yaml` - minimal HTTP API contract.
- `examples/` - safe payload examples.
- `tests/` - behavioral and public-tree tests.
- `docs/` - architecture, privacy, and integration guidance.

See [`docs/OFFLINE_AND_DATA_SAVER.md`](docs/OFFLINE_AND_DATA_SAVER.md) for the
user-facing behavior, traffic limits, and platform adapter boundaries.

## Public releases

The canonical public release page is the
[Speedtest+ docs repository](https://github.com/Csiklaoliver/speedtest-plus-docs).
Publish final APK/IPA files, release notes, download links, checksums, and OTA
manifest updates there. This repository remains the source, tests, build
instructions, and CI-artifact repository; it is not the public binary download
page. The iOS workflow intentionally uploads a short-lived build artifact so
it can be reviewed and published to the docs repository without putting final
downloads or signing material in source history.

## Scope and safety

Telemetry is off until the user opts in. The event contract contains no
advertising ID, hardware identifier, precise location, IP address, contact
data, or entered test override values. The server must aggregate accepted
events and apply short retention.

Public issue reports should never contain an APK, account token, signing key,
or copyrighted application file. See [SECURITY.md](SECURITY.md) for private
security reports.

Use the project only for lawful UI testing, demonstrations, accessibility
checks, and clearly disclosed simulations. A shared/exported customized result
should be labeled "simulated" or "customized" so another person cannot mistake
it for a measurement.

See [NOTICE.md](NOTICE.md) for the trademark and non-affiliation disclaimer.
