# Android parity status

| Feature | iOS implementation | Review status |
|---|---|---|
| Download/upload exact or range | Engine progress mutation with one cached target plus guarded label fallback | Needs device review |
| Realistic live movement | Progress-driven deterministic settling curve with callback-gap fallback | Unit contract passes |
| Stock gauge opening | Original Gauge controller retained | Needs device review |
| Ping and jitter | Latency progress setters | Needs device review |
| Packet loss | Local saved-model sent/received encoding | Needs device review |
| ISP/provider/location | State, final labels, details, compare, feedback | Needs device review |
| Three profiles | Persistent NSUserDefaults dictionaries | Static review complete |
| Ten themes | Scoped recursive UIKit palette application | Needs visual review |
| Guide and badge | Injected UIKit overlay | Needs layout review |
| Hidden/password panel | SHA-256 password hash, long-press unlock | Static review complete |
| Local text share | Unified finalized result builder | Static review complete |
| CSV | Four appended columns | Unit/device review needed |
| Update checks | Platform-specific manifest prompt | Network/device review needed |
| Server selection | Original controller left untouched | Regression review needed |
| Official remote result | Explicitly not modified | Code boundary reviewed |

The 0.1.11 maintenance build adds a label-only fallback for brief transfer
callback gaps reported on older iPhones. It does not replace the native
transfer model or server-selection path.

The first review build is intentionally conservative around private Swift model
internals. Visible parity and the local `CoreDataManager` boundary are implemented;
the reviewer should confirm which saved model setters are present at runtime
before any additional history-model hooks are enabled.
