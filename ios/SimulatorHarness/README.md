# Speedtest+ Simulator Harness

This native test host compiles the real Speedtest+ state, controls, profiles,
themes, curves, offline flow, diagnostics, sharing, updater, and connection
health code for iOS Simulator. It intentionally excludes `Tweak.xm` and does
not contain, reproduce, or submit traffic to Ookla services.

Generate and build the Xcode project:

```sh
cd SimulatorHarness
xcodegen generate
xcodebuild -project SpeedtestPlusSimulator.xcodeproj \
  -scheme SpeedtestPlusSimulator \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 11' \
  build
```

Run the simulator interaction suite:

```sh
xcodebuild -project SpeedtestPlusSimulator.xcodeproj \
  -scheme SpeedtestPlusSimulator \
  -destination 'platform=iOS Simulator,name=iPhone 11' \
  test
```

The harness is for deterministic UI/state validation. The injected extension's
private host hooks still require the approved device-target IPA and a physical
iPhone or compatible device farm.
