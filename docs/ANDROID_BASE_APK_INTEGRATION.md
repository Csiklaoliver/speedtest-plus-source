# Android integration with a user-supplied base APK

This repository does not contain a base APK or third-party application code.
The following is a generic local workflow for people who have a lawful right
to modify their own copy.

## Inputs

- A legally obtained base APK supplied by the user.
- Android SDK build tools.
- A locally generated signing key controlled by the user.
- The original helpers and contracts from this repository.

## Generic workflow

1. Record the base APK version and SHA-256.
2. Decode it into a temporary directory outside this repository.
3. Identify stable lifecycle/model boundaries without copying vendor code here.
4. Compile the Java helper classes for the target Android API.
5. Add thin local adapters that call the portable helpers.
6. Rebuild to an unsigned APK.
7. Run verifier checks, install on a disposable emulator, and test onboarding,
   GO, connecting animation, speed/video results, history, update checks, and
   consent withdrawal.
8. Zip-align and sign with the user's private key.
9. Verify alignment, signing schemes, package name, and version code.
10. Keep the decoded tree, APKs, and keys outside the public source tree.

## Required regression checks

- 320dp width, 1.3x font scale, landscape, and gesture navigation.
- Android 7, 9, 12, 14, and current Android where available.
- No lone metric icon before its value.
- Connecting animation remains visible.
- Gauge maximum remains the configured fixed scale.
- A configured speed animates through plausible samples and finishes exactly
  on the immutable final value.
- Saved, shared, and history values equal the final display.
- Customized exports are clearly labeled and are never submitted as measured
  performance to the provider's remote service.
- Analytics emits nothing before opt-in or after opt-out.
- An invalid theme code or update manifest fails closed.

Do not automate redistribution of a proprietary base application.
