# Progressive development history

Reconciled 2026-10-08, Asia/Hong_Kong, from repository history and the linked qualification reports. This retrospective index preserves the development sequence; it is not a verbatim conversation transcript. Commit dates identify saved checkpoints, not precise installation times.

Current release: Mac **0.4.0 build 5**, Flipper **AI HID CTRL 0.4**. See [current release evidence](Pointer-Display-v04.md) and [README](../README.md) for current operation. Earlier game defaults and qualification results are dated history.

| Date | Milestone | Development record | Checkpoint | Evidence |
|---|---|---|---|---|
| 2026-10-07 | Initial bridge and publication | BLE command transport to USB HID; development paper and initial validation published. | [214a85a](https://github.com/cmong67/flipper-mouse-bridge/commit/214a85ac94fbc6bf4d0653fccf9bbd9060393b4e) | [Report](Development-Paper.md) |
| 2026-10-07 | Automated target focus | Historical game focus and pointer validation recorded. | [d8fb926](https://github.com/cmong67/flipper-mouse-bridge/commit/d8fb92659a43f2a18da6078290365bf918f30166) | [Report](Kingshot-Qualification.md) |
| 2026-10-07 | Broader input survey | Tested mouse and drag navigation; wheel response varied by target view. | [4ab3d94](https://github.com/cmong67/flipper-mouse-bridge/commit/4ab3d94d014ac3d5ae89177d69f37f88b87ec4f7) | [Report](Kingshot-Qualification.md) |
| 2026-10-07 | Second qualification round | Positioning, launch and recovery evidence recorded with coverage limits. | [8d9ee40](https://github.com/cmong67/flipper-mouse-bridge/commit/8d9ee40314c3e0fd748af027d609270b2a13f4dc) | [Report](Kingshot-Round-2.md) |
| 2026-10-07 | Version 0.2 refinement | Bounded queues, session ownership, guarded positioning and reconnect recovery. | [9d9c639](https://github.com/cmong67/flipper-mouse-bridge/commit/9d9c639642e699df9ffe2d4b728cbcbd1b88331c) | [Report](Refined-App-Qualification.md) |
| 2026-10-07 | GUI retry record | Successful retry preserved alongside unresolved initial preparation behavior. | [f2fb735](https://github.com/cmong67/flipper-mouse-bridge/commit/f2fb73512d35249892891ddb7ed32522681562ed) | [Report](Refined-App-Qualification.md) |
| 2026-10-08 | Version 0.3 general-purpose controller | Removed game defaults; Mac and Flipper dashboards; GUI startup initially gated. | [496e206](https://github.com/cmong67/flipper-mouse-bridge/commit/496e206e241919ea698b526fa79721f8c317bfd0) | [Report](General-Purpose-Controller.md) |
| 2026-10-08 | Bluetooth initialization repair | Separated authorization from discovery; optional stable app-signing support. | [d83d8f9](https://github.com/cmong67/flipper-mouse-bridge/commit/d83d8f9e8f310799c4cdd4101aabbda72007ca0a) | [Report](General-Purpose-Controller.md) |
| 2026-10-08 | Final version 0.3 qualification | Owner permission refresh; unchanged installed build passed browser tests and 20 positioning targets. | [7a2dd2b](https://github.com/cmong67/flipper-mouse-bridge/commit/7a2dd2b436cc28527e518f9a97ddbf5f5803f520) | [Report](General-Purpose-Controller.md) |
| 2026-10-08 | AI HID CTRL rename | Flipper metadata/header renamed; installed readback checked. | [8831ef3](https://github.com/cmong67/flipper-mouse-bridge/commit/8831ef38dacdb8c1e050b3dd7a638d95f6a73fe5) | [Report](General-Purpose-Controller.md) |
| 2026-10-08 | Version 0.4 display revision | 20-position fading tail and bounded display-only absolute-coordinate feed. | [bdda626](https://github.com/cmong67/flipper-mouse-bridge/commit/bdda6269b46ca2861bbe847234c255c5c741e687) | [Report](Pointer-Display-v04.md) |
| 2026-10-08 | Version 0.4 live qualification | SAFE coordinate acknowledgements, reconnect and normal Stop verified after owner authentication. | [9275fe3](https://github.com/cmong67/flipper-mouse-bridge/commit/9275fe3dba2e4b492a1115dc4998df843443acce) | [Report](Pointer-Display-v04.md) |

## Evidence and privacy boundaries

Published reports retain failures, repairs, measured outcomes and unqualified cases. Passing a later check does not erase an earlier failed attempt or qualify unrelated behavior. Performance figures from different target sets are not controlled speed comparisons.

The canonical dated work journals, private installation details, raw test logs and recoverable note snapshots stay in the private Obsidian development vault. Public GitHub contains this sanitized chronology, source, shareable papers, qualification reports and versioned visual previews. No private journal dump is published.

## Continuing the record

For each meaningful revision, preserve the previous evidence; record the problem, change, exact version/build, verification, limits, rollback and next action. Add a dated private journal entry and link the public sanitized report/checkpoint here. Label retrospective summaries and distinguish installed state from proposals or unverified tests.
