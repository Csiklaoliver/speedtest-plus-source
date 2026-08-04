from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HEALTH_H = (ROOT / "Sources" / "SPConnectionHealth.h").read_text(encoding="utf-8")
HEALTH = (ROOT / "Sources" / "SPConnectionHealth.m").read_text(encoding="utf-8")
CONTROLS = (ROOT / "Sources" / "SPControlsViewController.m").read_text(encoding="utf-8")
MAKEFILE = (ROOT / "Makefile").read_text(encoding="utf-8")
DOCS = (ROOT.parent / "docs" / "CONNECTION_HEALTH.md").read_text(encoding="utf-8")


class ConnectionHealthContractTests(unittest.TestCase):
    def test_public_api_is_bounded_and_async(self):
        self.assertIn("runWithOfflineMode:(BOOL)offline completion:", HEALTH_H)
        self.assertIn("noteNativeServerListReady:(BOOL)ready", HEALTH_H)
        self.assertIn("ephemeralSessionConfiguration", HEALTH)
        self.assertIn("timeoutIntervalForRequest = 4.0", HEALTH)
        self.assertIn("timeoutIntervalForResource = 5.0", HEALTH)
        self.assertIn('request.HTTPMethod = @"HEAD"', HEALTH)
        self.assertIn("speedtest.oliverprojects.tech/api/ota/manifest", HEALTH)

    def test_states_are_user_readable_and_fixed(self):
        for text in (
            "Connection Health",
            "Internet/DNS/TLS",
            "Server-list readiness",
            "No speed test was started",
            "Not checked (offline mode)",
            "DNS lookup failed",
            "TLS handshake failed",
            "Internet unavailable",
            "Network check failed",
            "Native provider row ready",
            "Not observed yet",
        ):
            self.assertIn(text, HEALTH)

    def test_privacy_and_native_flow_contract(self):
        for forbidden in (
            "identifierForVendor",
            "UIDevice",
            "NSUUID",
            "CLLocation",
            "externalIp",
            "internalIp",
            "wifiSSID",
            "CoreDataManager",
            "beginPressed",
            "SelectServer",
            "didSelectRowAtIndexPath",
        ):
            self.assertNotIn(forbidden, HEALTH)
        self.assertIn("HTTPShouldHandleCookies = NO", HEALTH)
        self.assertIn("HTTPCookieStorage = nil", HEALTH)
        self.assertIn("URLCache = nil", HEALTH)
        self.assertIn("requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData", HEALTH)
        self.assertIn("SPConnectionHealth.m", MAKEFILE)

    def test_controls_expose_the_check_without_starting_a_test(self):
        self.assertIn('button:@"Check connection health" action:@selector(checkConnectionHealth)', CONTROLS)
        self.assertIn("runWithOfflineMode:offline", CONTROLS)
        self.assertIn("privacy-safe connection health", CONTROLS)

    def test_documentation_sets_correct_expectations(self):
        for text in (
            "Offline demo",
            "HEAD",
            "4 seconds",
            "5 seconds",
            "No speed test",
            "server-list readiness",
            "native server selection",
            "identifiers",
            "cookies",
        ):
            self.assertIn(text, DOCS)


if __name__ == "__main__":
    unittest.main()
