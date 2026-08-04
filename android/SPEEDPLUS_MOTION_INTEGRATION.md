# Reduced-motion integration

Speedtest+ now exposes a local **Reduce gauge motion** switch in the controls
panel. It is an accessibility/presentation preference only: it does not alter
the measured transfer, configured metrics, saved result, remote submission,
or data-saver limits.

The Android adapter is `SpeedPlusMotion`:

- `isReduced(context)` reads the private `speedtest_plus_mod` preference and
  also respects Android's global `ANIMATOR_DURATION_SCALE == 0` setting.
- `bindSwitch(control, context)` initializes and persists a controls-panel
  `CompoundButton` without collecting identifiers or opening a network.
- `configureAnimator(animator, context)` sets only the animation duration to
  zero when reduced motion is active. Call it for the gauge-opening and guide
  transitions before `start()`; do not use it to bypass result finalization.

When integrating a decoded APK, keep the switch below the existing test-mode
controls and use the same `speedtest_plus_mod` preferences. The feature is
safe to omit from a build if the host does not expose a compatible animation
hook; the native Android accessibility setting remains untouched.
