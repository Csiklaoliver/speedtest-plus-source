# Build and sign

The extension must be built on macOS. Windows can inspect and package the source,
but it cannot provide the Apple SDK, codesign tools, or a valid provisioning
profile.

## Requirements

- macOS with current Xcode and command-line tools
- Theos installed at `$THEOS`
- A clean, legally obtained decrypted Speedtest 7.0.5 IPA for sideload injection
- A signing method chosen by the reviewer, such as a personal Apple developer
  certificate, TrollStore-compatible signing, or a supported sideload service

Do not use the inspected reference IPA as a release base. It already contains
unknown third-party injected dynamic libraries. Start from a clean decrypted IPA.

## Compile the tweak

```sh
git clone <your-speedtest-plus-ios-source-url>
cd ios-speedtestplus
make clean package FINALPACKAGE=1
```

The package is created under `packages/`. The compiled dynamic library is built
for arm64 and arm64e with an iOS 12 deployment target.

## Jailbroken installation

Install the generated Debian package with the device's package manager or copy
it through the normal Theos install flow. The filter loads it only into
`com.ookla.speedtest`.

## Sideloaded IPA installation

1. Obtain a clean decrypted Speedtest 7.0.5 IPA.
2. Build `SpeedtestPlus.dylib` on macOS.
3. Install LIEF with `python3 -m pip install lief`.
4. Create the unsigned review IPA:

```sh
python3 Scripts/build_unsigned_ipa.py \
  --input /path/to/decrypted-speedtest.ipa \
  --dylib .theos/obj/SpeedtestPlus.dylib \
  --output build/SpeedtestPlus-iOS-unsigned.ipa
```

5. Sign every embedded framework and dynamic library, then sign `SpeedTest.app`
   with the reviewer's provisioning profile and entitlements.
6. Install it through the reviewer's selected sideloading method.

The packaging script removes the inspected reference IPA's known third-party
injections, stale app signature, and embedded provisioning profile. It then adds
only `SpeedtestPlus.dylib`. It never changes or uploads the input IPA.

The exact signing command depends on the reviewer's certificate and sideload
workflow, so no identity, provisioning UUID, password, or signing key is stored
in this repository.

The Speedtest+ dynamic library uses Objective-C runtime swizzling directly and
does not require a bundled Substrate dynamic library in a sideloaded IPA.

## OTA behavior on iOS

iOS does not permit this injected extension to silently replace the containing
application. The updater reads the `ios` object from the Speedtest+ manifest and,
when a newer version exists, offers to open its signed download page. Installation
still uses the user's signing or sideload method.

Expected manifest shape:

```json
{
  "ios": {
    "version": "0.1.2",
    "download_url": "https://speedtest.oliverprojects.tech/ios"
  }
}
```

## Pre-release checks

```sh
python3 Scripts/verify_project.py
python3 -m unittest discover -s Tests -v
python3 -m pip install tree-sitter-language-pack
python3 Scripts/verify_objc_syntax.py
python3 Scripts/inspect_ipa.py /path/to/clean.ipa --output build/clean-ipa-report.json
python3 Scripts/verify_hook_map.py build/clean-ipa-report.json
```

Compare the new report with `docs/HOOK_MAP.md` before signing.
