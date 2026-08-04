# Redmi server and test-start troubleshooting

## Current diagnosis

The Android build has separate server-discovery and test-start paths:

- Server discovery uses the native server catalog and depends on network access and runtime location permission. Redmi/HyperOS battery, background-data, Data Saver, VPN/Private DNS, or location-scanning restrictions can leave the catalog empty.
- Starting a test launches `SpeedtestForegroundService`. If Android/HyperOS rejects the foreground-service or notification start, the current service can stop without a useful on-screen error, making GO appear to do nothing.
- The custom provider and location fields are presentation/result overrides. They do not create or select a real network server; the actual connection still uses the native server object.
- The current APK ships native libraries only for `arm64-v8a`. Older 32-bit Redmi devices cannot run the native engine correctly.

## Device checks

Enable precise location, Wi-Fi scanning, unrestricted battery use, Autostart, background mobile/Wi-Fi data, and notifications. Temporarily disable Data Saver, VPN, Private DNS, and ad blockers. Test with an automatically discovered native server.

## Maximum configured speed

The controls accept a finite, non-negative speed up to **73,786,976,294,838.0 Mbps** per direction. This is the safe validator ceiling because the result model stores the value as a signed 64-bit raw rate and converts Mbps using `125,000`.

The gauge is still visually scaled to 1,000 Mbps, so values above 1,000 Mbps may display correctly as text while the needle/scale is saturated. Extremely large values are not practical for readable UI or floating-point precision; use a lower value for demonstrations.

## Useful log signatures

- `UnknownHostException` or `SSLHandshakeException`: DNS, VPN, Private DNS, or network filtering.
- `SecurityException` or location errors: runtime permission or location services.
- `ForegroundServiceStartNotAllowedException` or `IllegalStateException`: HyperOS foreground-service/notification restrictions.
- `UnsatisfiedLinkError`: unsupported ABI/native library.
