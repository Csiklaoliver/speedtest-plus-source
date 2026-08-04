from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TWEAK = (ROOT / "Sources" / "Tweak.xm").read_text(encoding="utf-8")
UPDATER = (ROOT / "Sources" / "SPUpdater.m").read_text(encoding="utf-8")
THEME = (ROOT / "Sources" / "SPTheme.m").read_text(encoding="utf-8")
SHARE = (ROOT / "Sources" / "SPShareBuilder.m").read_text(encoding="utf-8")
CONTROLS = (ROOT / "Sources" / "SPControlsViewController.m").read_text(encoding="utf-8")
STATE = (ROOT / "Sources" / "SPState.m").read_text(encoding="utf-8")
DIAGNOSTICS = (ROOT / "Sources" / "SPDiagnostics.m").read_text(encoding="utf-8")
MOTION = (ROOT / "Sources" / "SPMotion.m").read_text(encoding="utf-8")


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
        self.assertIn("HookSetIspView", TWEAK)
        self.assertIn("HookSetIspNameLabel", TWEAK)
        self.assertIn('SPHook(provider, @"setIspView:"', TWEAK)
        self.assertIn('SPHook(provider, @"setIspNameLabel:"', TWEAK)
        self.assertIn("HookSetHostView", TWEAK)
        self.assertIn("HookSetHostNameLabel", TWEAK)
        self.assertIn("HookSetHostLocationLabel", TWEAK)
        self.assertIn('SPHook(provider, @"setHostView:"', TWEAK)
        self.assertIn('SPHook(provider, @"setHostNameLabel:"', TWEAK)
        self.assertIn('SPHook(provider, @"setHostLocationLabel:"', TWEAK)
        self.assertIn("removeTarget:nil action:NULL", TWEAK)
        self.assertIn("removeGestureRecognizer:oldGesture", TWEAK)

    def test_first_run_guide_waits_for_native_setup_continue(self):
        self.assertIn("static BOOL SPHasStockSetupModal", TWEAK)
        self.assertIn("static BOOL SPHasNativeSetupSurface", TWEAK)
        self.assertIn("SPTextLooksLikeNativeSetupAction", TWEAK)
        self.assertIn("SPInstallSpeedEnhancementsWhenReady", TWEAK)
        self.assertIn("static void SPQueueIntroGuideAttempt", TWEAK)
        self.assertIn("!providerButton", TWEAK)
        self.assertNotIn("if (!SPState.shared.introSeen) SPQueueIntroGuideAttempt(controller, 0);", TWEAK)
        self.assertIn("native first-run flow owns", TWEAK)
        self.assertIn("checkSilentlyFromViewController", TWEAK)
        self.assertIn('@"educational"', TWEAK)

    def test_native_setup_blocks_every_custom_speed_surface(self):
        provider = TWEAK[TWEAK.index("static void SPAttachProviderControls"):TWEAK.index("static void SPFindProviderControlsInView")]
        self.assertIn("if (SPHasNativeSetupSurface(presenter)) return;", provider)
        layout = TWEAK[TWEAK.index("static void SPAttachProviderControlsAfterLayout"):TWEAK.index("static BOOL SPIsScopedController")]
        self.assertIn("if (SPHasNativeSetupSurface(controller)) return;", layout)
        badge = TWEAK[TWEAK.index("static void SPRefreshBadge"):TWEAK.index("static BOOL SPViewIsDescendantOf")]
        self.assertIn("if (SPHasNativeSetupSurface(controller)) return;", badge)
        self.assertIn("if (!SPHasNativeSetupSurface((UIViewController *)self))", TWEAK)

    def test_update_version_matches_current_ipa(self):
        self.assertIn('SPCurrentVersion = @"0.1.15"', UPDATER)

    def test_update_prompt_defers_to_native_setup_and_existing_modals(self):
        self.assertIn("SPIsNativeSetupController", UPDATER)
        self.assertIn("SPHasBlockingPresentation", UPDATER)
        self.assertIn("SPShowUpdateWhenReady", UPDATER)
        self.assertIn("attempt > 20", UPDATER)
        self.assertIn("Continue action is visible", UPDATER)
        self.assertIn("navigationController", UPDATER)
        self.assertIn("presentingViewController", UPDATER)

    def test_custom_guide_and_unlock_are_blocked_during_native_setup(self):
        self.assertIn("static BOOL SPLooksLikeStockSetupController", TWEAK)
        self.assertIn('@"intro"', TWEAK)
        self.assertIn('@"permission"', TWEAK)
        self.assertIn("if (SPHasNativeSetupSurface(host)) return", TWEAK)

    def test_provider_host_lifecycle_hooks_cover_rebuilt_rows(self):
        for name in ("setHostView:", "setHostNameLabel:", "setHostLocationLabel:"):
            self.assertIn(f'SPHook(provider, @"{name}"', TWEAK)
        self.assertIn("SPInstallProviderHotspot", TWEAK)

    def test_liquid_glass_has_runtime_and_accessibility_fallbacks(self):
        self.assertIn('NSClassFromString(@"UIGlassEffect")', THEME)
        self.assertIn("UIAccessibilityIsReduceTransparencyEnabled", THEME)
        self.assertIn("UIBlurEffectStyleSystemMaterialDark", THEME)
        self.assertIn("applyFunctionalMaterialToView", THEME)

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

    def test_provider_button_is_repaired_after_row_rebuild(self):
        layout = TWEAK[TWEAK.index("static void SPAttachProviderControlsAfterLayout"):TWEAK.index("static BOOL SPIsScopedController")]
        self.assertIn("SPFindProviderControlsInView(controller.view)", layout)
        self.assertIn("reparent stale controls", layout)
        self.assertNotIn("[controller.view viewWithTag:SPButtonTag]) return", layout)

    def test_public_hierarchy_fallback_repairs_missing_provider_entry_point(self):
        provider = TWEAK[TWEAK.index("static BOOL SPFallbackLabelIsUsable"):
                         TWEAK.index("static void SPRemoveLegacyFloatingControls")]
        self.assertIn("SPFallbackProviderLabel", provider)
        self.assertIn("SPFallbackLabelIsInNonProviderSurface", provider)
        self.assertIn('excluded in @[@"feedback"', provider)
        self.assertIn("SPInstallFallbackProviderButton", provider)
        self.assertIn('accessibilityIdentifier = @"speedtest_plus_provider_info_fallback"', provider)
        self.assertIn("SPInstallProviderHotspot(presenter, row, ispLabel, target)", provider)
        self.assertIn("button.alpha = 1.0", provider)
        self.assertIn("SPAttachFallbackProviderControls(strongController)", TWEAK)
        self.assertIn("@2.5", TWEAK)

    def test_provider_fallback_rejects_survey_question_labels(self):
        provider = TWEAK[TWEAK.index("static BOOL SPFallbackLabelIsUsable"):
                         TWEAK.index("static BOOL SPFallbackLabelIsInNonProviderSurface")]
        for text in ("how would", "how does", "expectation", "compare your", "rate "):
            self.assertIn(text, provider)

    def test_feedback_prompt_is_rewritten_even_when_private_title_accessor_changes(self):
        start = TWEAK.index("static void HookFeedbackViewDidLoad")
        end = TWEAK.index("static void SPRewriteSurveyLabels", start + 1)
        feedback = TWEAK[start:end]
        self.assertIn("SPRewriteSurveyLabels", feedback)
        self.assertIn("titleLabel", feedback)

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

    def test_zero_native_speed_still_uses_configured_animation(self):
        display = STATE[STATE.index("- (double)displayMbpsForDirection:"):STATE.index("- (void)completeTestWithMeasuredDownload:")]
        self.assertIn("if (!isfinite(measured)) measured = 0.0", display)
        self.assertIn("double suppliedProgress", display)
        self.assertIn("MAX(suppliedProgress, elapsedProgress)", display)
        self.assertNotIn("measured <= 0.0", display)

    def test_live_label_fallback_covers_callback_gaps(self):
        self.assertIn("SPScheduleLiveLabelFallback", TWEAK)
        fallback = TWEAK[TWEAK.index("static void SPScheduleLiveLabelFallback"):
                         TWEAK.index("static void SPApplyIdentityLabels")]
        self.assertIn("state.testActive", fallback)
        self.assertIn("runHasSpeedOverrideForDirection", fallback)
        self.assertIn("displayMbpsForDirection", fallback)
        self.assertIn("dispatch_after", fallback)
        stage = TWEAK[TWEAK.index("static void HookSuiteStagePrepared"):
                      TWEAK.index("static void (*OrigHandleProgress)")]
        self.assertIn("SPScheduleLiveLabelFallback(self, direction)", stage)

    def test_theme_repaints_generic_core_surfaces(self):
        self.assertIn('containsString:@"Speed"', THEME)
        self.assertIn('containsString:@"Compare"', THEME)
        self.assertIn("CGColorGetAlpha(view.backgroundColor.CGColor) > 0.05", THEME)
        self.assertIn("SPThemeDidChangeNotification", TWEAK)

    def test_privacy_safe_diagnostics_is_available_in_controls(self):
        self.assertIn('button:@"Copy diagnostics" action:@selector(copyDiagnostics)', CONTROLS)
        self.assertIn("UIPasteboard.generalPasteboard.string = SPDiagnosticsText", CONTROLS)
        self.assertIn("no IP address", CONTROLS)
        self.assertIn("no IP address", DIAGNOSTICS)
        self.assertIn("identity text", DIAGNOSTICS)
        self.assertIn("Active overrides", DIAGNOSTICS)

    def test_reduced_motion_is_local_and_presentation_only(self):
        self.assertIn('setReduceMotionEnabled:', (ROOT / "Sources" / "SPState.h").read_text(encoding="utf-8"))
        self.assertIn('self.reduceMotionSwitch', CONTROLS)
        self.assertIn('Reduce gauge motion', CONTROLS)
        self.assertIn('UIAccessibilityIsReduceMotionEnabled', STATE)
        self.assertIn('SPMotionPresentationProgress', STATE)
        self.assertIn('safeElapsed / 8.0 * 0.96', MOTION)
        self.assertIn('return reducedMotion ? 0.0', MOTION)
        self.assertNotIn('NSURL', MOTION)


if __name__ == "__main__":
    unittest.main()
