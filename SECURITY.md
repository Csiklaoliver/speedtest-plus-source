# Security policy

Report security or privacy vulnerabilities privately to the project maintainer
through the security-reporting channel listed on the project website. Do not
post proof-of-concept exploits, credentials, tokens, APKs, or personal data in
a public issue.

Please include:

- affected source-kit version;
- platform and OS major version;
- minimal reproduction steps;
- expected and observed behavior; and
- whether user data or update integrity may be affected.

The project will acknowledge a valid report, triage severity, prepare a fix,
and publish a concise advisory after affected users can update.

## Supported security properties

- HTTPS-only API and update endpoints.
- Update size, SHA-256, package, version, and signing-certificate checks.
- No embedded server credentials.
- Consent-gated analytics with a local off switch.
- Theme-code size limits, versioning, and integrity validation.

The repository does not accept or store third-party signing material.
