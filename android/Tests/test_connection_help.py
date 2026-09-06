from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'src/main/java/tech/oliverprojects/speedtestplus/SpeedPlusConnectionHelp.java').read_text()

class ConnectionHelpTests(unittest.TestCase):
    def test_guidance_is_optional_and_honest(self):
        for phrase in ('not a guaranteed fix', 'measured speeds may differ', 'WARP guide', 'Close'):
            self.assertIn(phrase, SOURCE)

    def test_lifecycle_is_bounded(self):
        for check in ('WeakReference', 'Looper.getMainLooper()', 'shown ||', 'isFinishing()', 'isDestroyed()'):
            self.assertIn(check, SOURCE)

    def test_does_not_collect_or_enable_vpn(self):
        for forbidden in ('ANDROID_ID', 'VpnService', 'HttpURLConnection', 'getSerial', 'getDeviceId'):
            self.assertNotIn(forbidden, SOURCE)
        self.assertIn('https://developers.cloudflare.com/', SOURCE)

if __name__ == '__main__':
    unittest.main()
