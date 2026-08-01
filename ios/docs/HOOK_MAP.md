# Runtime hook map

## Reference build

| Item | Value |
|---|---|
| Bundle | `com.ookla.speedtest` |
| App version | 7.0.5 build 6 |
| Main executable | `SpeedTest` |
| Architecture | arm64 |
| Mach-O encryption | `cryptid 0` |
| Minimum OS in app | iOS 10.0 |
| Frameworks | 56 |

The implementation itself targets iOS 14 or later. Runtime hooks are installed
only when both the expected class and selector exist.

## Gauge and live test

| Runtime class | Selector | Purpose |
|---|---|---|
| `_TtC5Gauge22GaugeViewControlleriOS` | `beginPressedWithSender:event:` | Reset one finalized target per new run before the stock animation starts |
| `_TtC5Gauge17ISPHostController` | `setAssemblyStackView:` | Attach the 48-point info button, badge, and provider-row long press |
| `_TtC9SpeedTest23SpeedTestViewController` | `suiteStagePrepared:` | Track the native stage without replacing its transition |
| same | `handleProgress:` | Change transfer values before the original gauge consumes them |
| same | `handleLoadedLatencyProgress:` | Apply optional ping and jitter values |
| same | `handleCompletion:` | Preserve the last shaped transfer value at stage completion |
| same | `suiteComplete` | Freeze the final local values once and refresh final labels |

Disassembly of the 7.0.5 `suiteStagePrepared:` switch confirms stage 1 is
latency, stage 2 is download, and stage 3 is upload.

No Gauge state, arc layer, needle animation, or transition duration is replaced.
This is deliberate. The original blue arc and gray trailing bar remain coupled
to the original animation timeline.

## Engine model

The following `SpeedTestEngine.framework` properties were confirmed through
Objective-C metadata:

- `TestParameters`: `stageType`, `progress`
- `TestParametersTransfer`: `speed`, `speedMST`, `speedSuperSpeed`, `speedAverage`
- `TestParametersLatency`: `ping`, `jitter`
- `ReportPacketLossModel`: `sent`, `received`
- `CoreDataManager`: `saveReportAsResult:`, `lastSavedResult`, `save`
- `GraphSampleEntryModel`: `initWithSpeed:progress:`
- `GraphSamplesModel`: `initWithDownload:upload:`

Transfer speed uses the engine's kilobits-per-second integer representation.
Speedtest+ converts local Mbps to raw units with `round(mbps * 1000)`.

The local `CoreDataManager` boundary is hooked. `ResultSaver`, `ResultReport`,
`ResultReportBuilder`, and network upload methods are intentionally not hooked,
so the official remote Ookla report remains measured.

## Result presentation

| Runtime class | Hook |
|---|---|
| `_TtC9SpeedTest27ResultDetailsViewController` | Replace visible local detail labels from the finalized result |
| `_TtC9SpeedTest30PreparedFeedbackViewController` | Use the active ISP in the rating prompt |
| `_TtC9SpeedTest28SpeedtestCardsViewController` | Rewrite visible provider-rating and expectations survey labels in displayed cards |
| `SharingTextActivityItem` Swift runtime class | Build local plain-text sharing output |
| `SharingURLActivityItem` Swift runtime class | Suppress the official public-result URL item |
| `SharingResultsCSVTextActivityItem` Swift runtime class | Append ISP, provider, jitter, and loss columns |
| `SharingResultsCSVFileActivityItem` Swift runtime class | Apply the same columns to file-based CSV exports |

`CompareResultsOfferViewController` is intentionally not hooked because it
renders remote ISP offers and provider medians, not the user's result model.

## Server selection

`_TtC9SpeedTest26SelectServerViewController` and its
`tableView:didSelectRowAtIndexPath:` method were mapped but are not hooked.
Normal server selection and connection logic stay intact.

## Fail-closed behavior

Every hook checks class and selector availability before installation. Optional
model setters are called only after `respondsToSelector:`. This prevents a minor
upstream layout change from becoming a launch crash.
