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
        self.assertNotIn('SPHook(coreData, @"resultSaver:didCompleteWithSuccess:', TWEAK)

    def test_local_save_is_bound_to_report_and_consumed_once(self):
        self.assertIn('SPKVCValue(report, @"speedTestResult")', TWEAK)
        self.assertIn("consumePendingLocalResult", TWEAK)

    def test_remote_compare_offer_is_not_modified(self):
        self.assertNotIn('SPHook(compare, @"viewWillAppear:', TWEAK)

    def test_native_secondary_speed_channels_are_scaled(self):
        self.assertIn("SPScaledRaw(nativeMST", TWEAK)
        self.assertIn("SPScaledRaw(nativeSuper", TWEAK)
        self.assertIn("SPScaledRaw(nativeAverage", TWEAK)

    def test_url_share_is_suppressed_and_csv_file_is_rewritten(self):
        self.assertIn("SharingURLActivityItem", TWEAK)
        self.assertIn("SharingResultsCSVFileActivityItem", TWEAK)

    def test_scene_aware_presentation_and_provider_only_long_press(self):
        self.assertIn("connectedScenes", TWEAK)
        fallback = TWEAK[TWEAK.index("static void SPAttachControls"):TWEAK.index("static void SPAttachProviderControls")]
        self.assertNotIn("UILongPressGestureRecognizer", fallback)
        self.assertNotIn("bottomAnchor", fallback)
        self.assertNotIn("rightBarButtonItems", fallback)
        self.assertNotIn("SPControlBarItemKey", TWEAK)

    def test_provider_info_icon_is_attached_to_isp_row(self):
        provider = TWEAK[TWEAK.index("static void SPAttachProviderControls"):TWEAK.index("static BOOL SPIsScopedController")]
        self.assertIn('SPLabel(hostController, @"ispNameLabel")', provider)
        self.assertIn('systemImageNamed:@"info.circle"', provider)
        self.assertIn("insertArrangedSubview:button", provider)
        self.assertNotIn('setTitle:@"S+  i"', provider)

    def test_provider_controls_retry_and_rebind_after_guide(self):
        self.assertIn("static void SPRetryProviderControls", TWEAK)
        self.assertIn("SPRetryProviderControls(controller)", TWEAK)
        self.assertIn("HookSpeedViewDidLayoutSubviews", TWEAK)
        self.assertIn("SPAttachProviderControlsAfterLayout", TWEAK)
        self.assertIn("removeTarget:nil action:NULL", TWEAK)
        self.assertIn("removeGestureRecognizer:oldGesture", TWEAK)

    def test_provider_long_press_has_row_hotspot_fallback(self):
        provider = TWEAK[TWEAK.index("static void SPAttachProviderControls"):TWEAK.index("static BOOL SPIsScopedController")]
        self.assertIn("SPProviderHotspotTag", TWEAK)
        self.assertIn("userInteractionEnabled = YES", TWEAK)
        self.assertIn("SPInstallProviderLongPress(ispLabel", provider)
        self.assertIn("SPInstallProviderHotspot(presenter, providerView, ispLabel, target)", provider)
        self.assertIn("alpha = 0.01", TWEAK)
        self.assertIn("bringSubviewToFront:hotspot", TWEAK)
        self.assertIn("@selector(openControls)", TWEAK)

    def test_custom_button_remains_available_when_panel_is_locked(self):
        self.assertIn("button.hidden = NO", TWEAK)
        self.assertIn("password-protected Speedtest+ controls", TWEAK)
        self.assertIn("speedtest_plus_controls_hotspot", TWEAK)
        self.assertIn("if (SPState.shared.panelHidden) SPPresentUnlock(host)", TWEAK)

    def test_provider_anchor_survives_private_label_changes(self):
        provider = TWEAK[TWEAK.index("static void SPAttachProviderControls"):TWEAK.index("static BOOL SPIsScopedController")]
        self.assertIn("[stack isKindOfClass:UIView.class]", provider)
        self.assertIn("![ispLabel isKindOfClass:UILabel.class]", provider)
        self.assertIn("button.trailingAnchor constraintEqualToAnchor:ispView.trailingAnchor", provider)

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
