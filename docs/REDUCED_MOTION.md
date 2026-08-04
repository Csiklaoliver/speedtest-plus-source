# Reduced Motion

Speedtest+ includes a local **Reduce gauge motion** switch in the controls
panel on Android and iOS. It is a presentation and accessibility preference,
not a test override:

- measured bytes, server selection, finalized metrics, and saved results are
  unchanged;
- no network request, identifier, or telemetry event is added;
- the preference is stored in the existing private `speedtest_plus_mod`
  state on each platform;
- Android also honors `Settings.Global.ANIMATOR_DURATION_SCALE == 0`;
- iOS also honors the system **Settings > Accessibility > Motion > Reduce
  Motion** setting.

With the preference enabled, the gauge-opening and configured-result display
use a slower monotonic progress ramp and remove the settling pulse. Native
result finalization still runs normally, so the final displayed scalar remains
exactly the saved value. This is intended for motion-sensitive users and for
devices where transition animations are unstable.

Platform integration details are in:

- [`android/SPEEDPLUS_MOTION_INTEGRATION.md`](../android/SPEEDPLUS_MOTION_INTEGRATION.md)
- `ios/Sources/SPMotion.{h,m}` and `SPState.reduceMotionEnabled`
