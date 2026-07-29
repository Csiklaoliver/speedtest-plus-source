# Contributing

Contributions must be original and must not copy proprietary application code,
resources, artwork, strings, API secrets, or private server configuration.

## Workflow

1. Open an issue describing the behavior and the supported Android/iOS surface.
2. Add or update a contract before changing a client/server boundary.
3. Keep core logic platform-neutral when practical.
4. Add a regression test for every bug fix.
5. Run `npm test`.
6. Submit a focused pull request explaining privacy and compatibility impact.

## Base-application integration

Do not submit APKs, decompiled trees, binary diffs, or vendor signing
materials. Integration documentation may refer to generic lifecycle and model
hooks, but it must not reproduce proprietary method bodies.

## Compatibility

New Java helpers should remain compatible with Java 8 language features.
UI integrations should be tested at 320dp width, large font/display scaling,
landscape, gesture navigation, and Android 7 through the current Android
release. Avoid device-model allowlists.

## Privacy

Analytics changes require an updated schema, documentation, and tests proving
that collection remains disabled without consent. New identifiers, precise
location, free-form analytics properties, or silent log uploads will not be
accepted.
