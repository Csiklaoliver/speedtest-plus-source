from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TWEAK = (ROOT / "Sources" / "Tweak.xm").read_text(encoding="utf-8")
THEME = (ROOT / "Sources" / "SPTheme.m").read_text(encoding="utf-8")
SHARE = (ROOT / "Sources" / "SPShareBuilder.m").read_text(encoding="utf-8")
CONTROLS = (ROOT / "Sources" / "SPControlsViewController.m").read_text(encoding="utf-8")
STATE = (ROOT / "Sources" / "SPState.m").read_text(encoding="utf-8")


class SourceContractTests(unittest.TestCase):
    def test_confirmed_stage_mapping(self):
        self.assertIn("SPStageDownload = 2", TWEAK)
        self.assertIn("SPStageUpload = 3", TWEAK)

    def test_remote_report_classes_are_not_hooked(self):
        self.assertNotIn('SPHook(report, @"populateSpeedTestResult:', TWEAK)
        self.assertNotIn('SPHook(saver, @"initWithResult:', TWEAK)
        self.assertIn('SPHook(coreData, @"saveReportAsResult:', TWEAK)

    def test_server_selection_is_not_hooked(self):
        self.assertNotIn("didSelectRowAtIndexPath", TWEAK)

    def test_ten_themes_exist(self):
        names = re.findall(r'\[self named:@"([^"]+)"', THEME)
        self.assertEqual(10, len(names))

    def test_local_share_has_no_public_result_url(self):
        self.assertNotIn("speedtest.net/result", SHARE.lower())
        self.assertIn("Speedtest+ Result", SHARE)

    def test_zero_badge_is_hidden(self):
        self.assertIn("badge.hidden = count == 0", TWEAK)

    def test_speed_ranges_require_both_bounds(self):
        self.assertIn("(minimum == nil) != (maximum == nil)", CONTROLS)

    def test_official_update_banner_filter_is_narrow(self):
        self.assertIn("SPHideOfficialUpdateBanner", TWEAK)
        self.assertIn('containsString:@"update available"', TWEAK)

    def test_number_pads_have_a_done_control(self):
        self.assertIn("field.inputAccessoryView = keyboardBar", CONTROLS)
        self.assertIn("UIBarButtonSystemItemDone", CONTROLS)
        self.assertIn('initWithTitle:@"Apply"', CONTROLS)

    def test_profile_slots_do_not_persist_nsnull(self):
        profile_section = STATE[
            STATE.index("- (NSDictionary<NSString *,id> *)profileAtIndex:"):
            STATE.index("- (void)beginTest")
        ]
        self.assertNotIn("NSNull.null", profile_section)
        self.assertIn("NSMutableDictionary *profiles", profile_section)
        self.assertIn("SPDefaultsSafeValue(self.store)", STATE)


if __name__ == "__main__":
    unittest.main()
