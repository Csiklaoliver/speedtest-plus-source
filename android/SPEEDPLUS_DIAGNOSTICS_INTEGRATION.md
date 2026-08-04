# Android diagnostics integration

The controls dialog adds a `COPY DIAGNOSTICS` action backed by
`SpeedPlusDiagnostics.copyToClipboard(context)`.  The snapshot is local and
explicitly privacy-safe: it includes Android/app version, theme index, active
override categories, and finalized scalar values, but never includes an IP
address, account identifier, device ID, exact location, credentials, or the
entered ISP/provider strings.

The adapter reads only `speedtest_plus_mod` keys already written by the
Speedtest+ state holder.  It does not open a network connection and does not
alter test results or remote submission.  Keep the button inside the existing
Speedtest+ controls panel so normal provider/server navigation is untouched.

For a decoded APK integration, compile this adapter into the same classes
dex as the controls, then bind a `View.OnClickListener` to a button labelled
`COPY DIAGNOSTICS`.  The listener must call `copyToClipboard` and nothing else.
