from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
ADAPTER = (ROOT / "src" / "main" / "java" / "com" / "ookla" / "mobile4" / "views" / "SpeedPlusDiagnostics.java").read_text(encoding="utf-8")
LISTENER = (ROOT / "src" / "main" / "java" / "com" / "ookla" / "mobile4" / "views" / "SpeedPlusDiagnosticsClickListener.java").read_text(encoding="utf-8")


class DiagnosticsContractTests(unittest.TestCase):
    def test_snapshot_is_local_and_identifier_free(self):
        self.assertIn('getSharedPreferences(PREFS', ADAPTER)
        self.assertIn('setPrimaryClip', ADAPTER)
        self.assertIn('no IP address', ADAPTER)
        self.assertNotIn('URL(', ADAPTER)
        self.assertNotIn('http', ADAPTER.lower())
        self.assertNotIn('android_id', ADAPTER.lower())
        self.assertNotIn('deviceId', ADAPTER)

    def test_listener_only_copies_diagnostics(self):
        self.assertIn('SpeedPlusDiagnostics.copyToClipboard(context)', LISTENER)
        self.assertNotIn('startActivity', LISTENER)


if __name__ == "__main__":
    unittest.main()
