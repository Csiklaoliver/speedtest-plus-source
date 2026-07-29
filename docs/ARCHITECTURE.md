# Architecture

Speedtest+ is split into portable policy and thin platform adapters.

```text
Android UI / future iOS UI
          |
          v
  platform adapter layer
          |
          v
 portable core + schemas
    |          |       |
 result     themes   consent
 curves              and events
          |
          v
 HTTPS API implementing contracts/openapi.yaml
```

The core never owns an Activity, View, Android identifier, network socket, or
filesystem path. Platform adapters translate host-application events into
core models and dispatch approved API payloads.

## Result lifecycle

1. Validate an optional configuration.
2. Finalize each target value exactly once for the test session.
3. Generate display samples from that immutable final value.
4. Feed samples to the UI without re-randomizing the target.
5. Save/share the same immutable final value.

This design avoids both frozen displays and mismatches between the last value
shown and the value saved.

Customized results remain local simulation/presentation data. Adapters must
not submit them as measured values to a provider's remote service, and exports
must make their customized status clear.

## API lifecycle

1. Keep analytics disabled by default.
2. Store the user's consent decision locally.
3. Build only allowlisted aggregate events.
4. Batch conservatively and upload over HTTPS.
5. Drop rather than retry indefinitely.
6. Delete queued events immediately when consent is withdrawn.
