# September stability candidates

Android 1.8.14 and iOS 0.1.26 are test candidates, not a claim of universal device support.

## Android integration

Build `SpeedPlusConnectionHelp.java` against Android API 35, Java 8, then D8
with min API 24. Pass the resulting DEX as `connection_dex` to
`android/pack_runtime_dex.py`. The existing feature DEX must become
`classes7.dex`; connection help becomes `classes8.dex`. Run zipalign and sign
after repacking, never before. Keep private signing material outside this repo.

Decoded runtime changes required in addition to the helper:

- `SpeedPlusLiveAnimator$Pulse.run`: the initial failed generation check returns
  immediately. It must NOT call `stop(direction)`, which would stop a newer run.
- `SpeedPlusLiveAnimator.begin`: after accepting a new direction and before
  `beginLiveSpeed`, call `stop(3 - direction)` to invalidate the opposite feed.
- `SpeedPlusState.overrideLiveSpeed`: in offline mode, ignore native empty
  readings by reusing the active direction's current simulated value.
- `SpeedPlusState.offlineLiveSpeed`: update the matching current-speed cache
  and tick counter for both ramp and fluctuation branches.
- `SpeedPlusState.hasValidatedNetwork`: reject missing active network, missing
  INTERNET capability and known CAPTIVE_PORTAL. Do not require VALIDATED; the
  native engine handles reachability errors. Do not disable TLS verification.
- `SpeedPlusState.showConnectionHelp`: get the current Activity from its weak
  reference and call `SpeedPlusConnectionHelp.show(Activity)`.
- Native test-controller error callback: after excluding TEST_CANCELLED,
  request connection help. Do not change normal server selection or reports.

Vendor guidance is local, once per process after a test error, and applies to
Xiaomi/Redmi/POCO, Oppo/Realme, Vivo/iQOO, Huawei/Honor and OnePlus. This is not a
claim that every device from these brands is broken. No device identifier or
manufacturer data is transmitted by this helper.

WARP is optional and opens an official guide only after a tap. It changes routing
and can change measured speeds. It is not a guaranteed fix. Sources:
[Android setup](https://developers.cloudflare.com/warp-client/get-started/android/),
[WARP modes](https://developers.cloudflare.com/warp-client/warp-modes/).

## iOS changes

- All runtime hooks use class-local overrides instead of mutating inherited
  UIViewController methods globally.
- Setup repair avoids duplicate touch/primary-action wiring. OS permissions and
  consent are not fabricated or silently granted.
- Profile/error alerts wait for the current UIKit alert transition.
- Every test has a generation; stale offline, live-label and final-label tasks
  cannot repaint another run. Backgrounding cancels an offline run.
- Offline mode has an explicit full-screen, local-only simulation display with
  Close, both direction readings, ping/jitter and a capped 1k gauge. It avoids
  unavailable private gauge methods and server discovery. Normal online gauge
  presentation is unchanged. No floating S+ control is added.
- Default offline readings animate too; each phase gets its full progress range.

## Required runtime gates

Static contracts and syntax checks do not prove UIKit or Dalvik runtime behavior.
Test fresh/returning startup, optional permission denial, provider controls,
profile save/load, two consecutive tests, cancel/restart, background/foreground,
offline upload, saved final parity, no-network errors, and selected-server failure.
Test on physical iPhones and affected Android devices before promoting stable OTA.
Offline iOS history is held in Speedtest+ local state, not a fabricated remote report.

## Rollback

Do not change stable OTA metadata until validation. Keep previous APK/IPA assets.
Source changes can be reverted by commit. Android downgrade may require uninstall
and lose data; prefer a higher-version rebuild of known-good code with the same key.
Never clear user data as a diagnostic shortcut.
