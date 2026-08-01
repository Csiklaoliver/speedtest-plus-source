#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


EXPECTED = {
    "main": {
        "_TtC9SpeedTest23SpeedTestViewController": {
            "viewDidLoad", "viewWillAppear:", "viewDidAppear:", "suiteStagePrepared:", "handleProgress:",
            "handleLoadedLatencyProgress:", "handleCompletion:", "suiteComplete",
            "canShowAdForAdView:",
        },
        "_TtC9SpeedTest27ResultDetailsViewController": {"viewDidLoad", "shareResult:"},
        "_TtC9SpeedTest24ResultListViewController": {"viewWillAppear:"},
        "_TtC9SpeedTest33CompareResultsOfferViewController": {"viewWillAppear:"},
        "_TtC9SpeedTest30PreparedFeedbackViewController": {"viewDidLoad"},
        "_TtC9SpeedTest28SpeedtestCardsViewController": {"collectionView:willDisplayCell:forItemAtIndexPath:"},
        "_TtC9SpeedTestP33_A9A507B3669C583A38FE6357D8AFFD8023SharingTextActivityItem": {"item"},
        "_TtC9SpeedTestP33_A9A507B3669C583A38FE6357D8AFFD8033SharingResultsCSVTextActivityItem": {"activityViewController:itemForActivityType:"},
    },
    "Gauge": {
        "_TtC5Gauge22GaugeViewControlleriOS": {"beginPressedWithSender:event:"},
        "_TtC5Gauge17ISPHostController": {"setAssemblyStackView:", "ispView"},
    },
    "SpeedTestEngine": {
        "TestParameters": {"stageType", "progress"},
        "TestParametersTransfer": {"speed", "setSpeed:", "setSpeedMST:", "setSpeedSuperSpeed:", "setSpeedAverage:"},
        "TestParametersLatency": {"setPing:", "setJitter:"},
        "CoreDataManager": {"saveReportAsResult:", "lastSavedResult", "save"},
        "ReportPacketLossModel": {"setSent:", "setReceived:"},
        "GraphSampleEntryModel": {"initWithSpeed:progress:"},
        "GraphSamplesModel": {"initWithDownload:upload:"},
    },
}

CORE_DATA_FIELDS = {
    "download": 300,
    "upload": 300,
    "latency": 200,
    "jitter": 500,
    "downloadJitter": 500,
    "uploadJitter": 500,
    "packetsSent": 100,
    "packetsReceived": 100,
    "isp": 700,
    "serverSponsor": 700,
    "serverName": 700,
    "graphSamples": 1800,
}


def selectors(methods):
    return {method["selector"] for method in methods}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding="utf-8"))
    groups = {"main": report.get("selected_runtime_classes", {})}
    groups.update(report.get("selected_framework_runtime_classes", {}))
    failures = []
    for group, classes in EXPECTED.items():
        actual_classes = groups.get(group, {})
        for class_name, expected_selectors in classes.items():
            if class_name not in actual_classes:
                failures.append(f"{group}: missing class {class_name}")
                continue
            missing = expected_selectors - selectors(actual_classes[class_name])
            for selector in sorted(missing):
                failures.append(f"{group}: {class_name} missing {selector}")
    if report.get("encrypted") is not False:
        failures.append("main executable is encrypted or encryption could not be determined")
    actual_fields = report.get("speedtest_result_coredata_fields", {})
    for field, expected_type in CORE_DATA_FIELDS.items():
        if field not in actual_fields:
            failures.append(f"Core Data: missing SpeedTestResult.{field}")
        elif actual_fields[field].get("attribute_type") != expected_type:
            failures.append(f"Core Data: {field} type changed from {expected_type}")
    if failures:
        print("hook map verification failed")
        print("\n".join(f"- {failure}" for failure in failures))
        return 1
    count = sum(len(selectors_) for classes in EXPECTED.values() for selectors_ in classes.values())
    print(f"hook map verification passed: {count} required selectors and {len(CORE_DATA_FIELDS)} Core Data fields")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
