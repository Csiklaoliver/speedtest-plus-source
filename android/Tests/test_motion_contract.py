from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
ADAPTER = (ROOT / "src" / "main" / "java" / "com" / "ookla" / "mobile4" / "views" / "SpeedPlusMotion.java").read_text(encoding="utf-8")
DOC = (ROOT / "SPEEDPLUS_MOTION_INTEGRATION.md").read_text(encoding="utf-8")


class MotionContractTests(unittest.TestCase):
    def test_motion_preference_is_private_and_local(self):
        self.assertIn('getSharedPreferences(PREFS', ADAPTER)
        self.assertIn('putBoolean(KEY, enabled)', ADAPTER)
        self.assertIn('ANIMATOR_DURATION_SCALE', ADAPTER)
        self.assertNotIn('startActivity', ADAPTER)
        self.assertNotIn('http', ADAPTER.lower())
        self.assertNotIn('android_id', ADAPTER.lower())

    def test_animator_hook_is_presentation_only(self):
        self.assertIn('animator.setDuration(0L)', ADAPTER)
        self.assertIn('configureAnimator(animator, context)', DOC)
        self.assertIn('does not alter\nthe measured transfer', DOC)


if __name__ == "__main__":
    unittest.main()
