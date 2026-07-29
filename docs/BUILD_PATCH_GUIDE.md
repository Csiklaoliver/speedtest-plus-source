# Reproducible local patch notes

Public releases should describe behavior, not carry a proprietary binary diff.
A maintainer may keep a private patch recipe containing selectors for the
lawfully supplied base version.

## Public recipe format

A public recipe may document:

- required base version and expected base SHA-256;
- original helper source revision;
- generic integration boundaries;
- resources newly created by Speedtest+;
- build-tool versions;
- verification commands; and
- final package/version metadata.

It must not include:

- decompiled third-party method bodies;
- vendor resources or signing certificates;
- a base or patched APK;
- private hosts, passwords, tokens, or local absolute paths.

## Failure behavior

Every local integration step should verify its target exists exactly once.
Abort on an unknown base version or ambiguous selector. Never guess a patch
location and never sign a build after a partial patch.
