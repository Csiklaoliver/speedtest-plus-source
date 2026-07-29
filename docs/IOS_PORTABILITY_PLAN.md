# iOS portability plan

This document prepares for a future native iOS implementation. It does not
contain, build, or distribute an IPA.

## Portable now

- Configuration field meanings and validation limits.
- Immutable final-result lifecycle.
- Realistic result-curve algorithm and exact final sample.
- Theme JSON and share-code envelope.
- Consent state machine and telemetry/bug-report schemas.
- API and signed-update metadata contracts.

## Native iOS components later

- Swift value types mirroring the schemas.
- SwiftUI controls, guide, result cards, themes, and accessibility.
- `URLSession` API client with certificate/system trust.
- Keychain only for genuinely secret user credentials; ordinary preferences in
  `UserDefaults`.
- App Store/TestFlight update flow. iOS must not self-install an IPA.
- `MetricKit`/user-approved diagnostics only after a separate privacy review.

## Recommended milestones

1. Generate Swift models from the stable JSON schemas.
2. Port validation and curve golden tests.
3. Build a standalone SwiftUI prototype with synthetic local data.
4. Implement consent and offline event queue.
5. Add API integration against a staging server.
6. Run VoiceOver, Dynamic Type, reduced motion, dark mode, iPhone SE, current
   iPhone Pro Max, iPad split-view, and poor-network testing.
7. Complete App Privacy labels and independent security review.
8. Use TestFlight for opt-in beta distribution.

## Non-goals

- Reusing Android/decompiled application code.
- Shipping an IPA from this repository.
- Side-loading, bypassing App Store review, or embedding signing credentials.
- Reproducing third-party branding or proprietary test engines.
