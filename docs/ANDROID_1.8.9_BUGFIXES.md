# Android 1.8.9 bug-fix notes

This note records the public behavior changes for the Android 1.8.9 QA build.
The repository does not contain the vendor APK, decoded vendor resources, or
signing material. The changes below are implemented by the local adapter using
a legally supplied base package.

## Reports covered

- Redmi and other devices could keep a stale server cache after switching
  between Wi-Fi and mobile data, leaving no usable server list.
- A selected server could show a list but fail to provide a usable test start
  after the network changed.
- A custom run could display zero or a frozen number, or let the number and
  gauge needle drift apart.
- Disabling controls while a run was active could leave one queued custom frame
  on screen.

## Behavior in 1.8.9

- Opening server selection refreshes page zero even when cached rows exist.
  This lets the native server manager recover after a connectivity transition;
  native provider and server selection remain untouched.
- A custom download or upload target is selected once at the start of its phase.
  The live value eases toward that target, then has small settling variation.
  It is never regenerated for each callback or when a result is saved.
- The same live value is sent to both the number display and the native gauge
  mapper, so the blue leading arc, gray trailing bar, and needle stay together.
  The visible gauge scale remains fixed at 1k.
- The first frame uses a small positive fraction of the target instead of a
  zero frame, which avoids the reported stuck-at-zero screen while the native
  engine is quiet.
- `DISABLE ALL` invalidates queued live frames before clearing the active
  configuration.

## Verification

The local build was checked for package metadata (`org.zwanoo.android.speedtest`,
version code `258549`, version name `1.8.9`), v2/v3 APK signatures, zip
alignment, and presence of the server-refresh and gauge-bridge methods in the
rebuilt dex files. There was no Android device connected for a physical Redmi
or Wi-Fi/mobile-data transition test, so those two scenarios still need device
confirmation.

The QA package is debug-signed. It is suitable for a clean test install, but it
cannot replace an installation signed with a different production key or serve
as a production OTA update until the project owner signs it with the same
release key used by the installed app.
