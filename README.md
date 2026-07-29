# Speedtest+ original source kit

This is the public, clean-room source package for the original Speedtest+
helpers. It provides portable logic and contracts for:

- validating optional metric and provider overrides;
- generating realistic display samples that finish on one exact saved value;
- explicit, revocable analytics consent;
- privacy-preserving usage-event and bug-report contracts;
- custom theme codes with integrity checks;
- a signed-update manifest contract; and
- Android integration and future iOS portability guidance.

> **Important:** customized values are local simulation and presentation
> controls. They are not independently measured network performance and are
> not the provider's official remote report. Never present a customized result
> as genuine evidence for billing disputes, sales, employment, competitions,
> service-level claims, fraud, or any other deceptive purpose.

It is deliberately **not** a buildable copy of any third-party application.
You must supply your own legally obtained base APK and perform integration
locally. No third-party APK, decoded code/resources, signing material, or
credentials belong in this repository.

## Requirements

- JDK 8 or newer
- Node.js 18 or newer

## Verify

```sh
npm test
```

The verification suite compiles the dependency-free Java core, runs behavioral
tests, parses all JSON contracts/examples, and scans the public tree for
forbidden binaries, absolute local paths, and common secret patterns.

## Layout

- `src/main/java/` — original, platform-neutral Java helpers.
- `schemas/` — JSON Schema contracts for app/server boundaries.
- `contracts/openapi.yaml` — minimal HTTP API contract.
- `examples/` — safe payload examples.
- `tests/` — behavioral and public-tree tests.
- `docs/` — architecture, privacy, integration, and iOS planning.

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
should be labeled “simulated” or “customized” so another person cannot mistake
it for a measurement.

See [NOTICE.md](NOTICE.md) for the trademark and non-affiliation disclaimer.
