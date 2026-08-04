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

## Offline and data-saver modes

The portable [`TestMode`](../src/main/java/tech/oliverprojects/speedtestplus/core/TestMode.java)
contract defines the shared behavior. A local Android adapter should expose two
mutually exclusive controls:

- **Offline demo:** skip the native start/connection request, drive the local
  display with a clearly labelled synthetic result, and never call a provider
  report or submission API.
- **Data saver:** keep the native measured path, applying a maximum of 2
  seconds and 262,144 bytes per connection in the native `SuiteConfig` (or the
  equivalent configuration object for that base version).

Apply the data-saver limits immediately before each test configuration is
handed to the engine, because some releases clone the configuration during
startup. Store the mode flags in the app's private preferences, clear both on
**Disable All**, and leave the normal measured path untouched when neither is
selected. Do not publish the decoded vendor adapter or a rebuilt APK here;
keep those local as described above.

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
