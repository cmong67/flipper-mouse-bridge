# Progressive development history

Reconciled 2026-10-08, Asia/Hong_Kong, from repository history and the linked qualification reports. This retrospective index preserves the development sequence; it is not a verbatim conversation transcript. Commit dates identify saved checkpoints, not precise installation times.

Current installed build: Mac **0.4.4 build 9**, Flipper **AI HID CTRL 0.5**. Hardware regression and installed GUI qualification passed. See [current release evidence](Invocation-Qualification-v044.md) and [README](../README.md) for current operation. Earlier game defaults and qualification results are dated history.

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


## Icon revision — 2026-10-13

[Icon assets](../assets/icons/README.md) added in signed checkpoint `c01a307`; native Mac integration installed as0.4.1 build6. See [installation report](Icon-Installation-v041.md) for verification and the resolved Bluetooth grant refresh and reconnect qualification.


## Positioning repair — 2026-10-25

Mac 0.4.2 build 7 replaces fixed fine-correction gain and restrictive learning bounds after reproducing pointer oscillation on 0.4.1. Ten live targets and all bounded native mouse event tests passed; SAFE feed/reconnect passed. The rejected temporary self-test build is retained in the evidence. See [repair report](Pointer-Repair-v042.md). Flipper 0.4 remains unchanged.


## Extended shutdown finding — 2026-10-25

Installed0.4.2 passed60 targets/60 normal mouse actions and5 reconnects, but held-drag disconnect left the host button down and subsequent USB reports failed. Ordinary serial restoration is insufficient release evidence. The0.4.3 candidate requests STOP before closing BLE; built/self-tested only, hardware reset/qualification pending. See [failure and candidate report](Stop-Release-v043.md).


## Combined shutdown/readiness repair — 2026-10-25

The first Mac-only0.4.3 candidate released a held button but failed its reconnect click and was rejected. The final pair adds Flipper0.5 USB readiness gating and Mac startup-exit failure handling. Both are installed;60 targets,60 normal commands, repeated held-drag release/reconnect, fresh-ARM guards, five process starts, focus refusal and SIGTERM release passed. The unchanged installed GUI then passed Bluetooth authorization, automated test-window focus/position/click, SAFE reconnect and Stop; final state OFFLINE with buttons0. Earlier failed results remain history; see [full repair paper](Stop-Release-v043.md).


## Repeat qualification — 2026-10-25T18:36:22+03:00

Unchanged installed0.4.3/0.5 pair passed120 positioning targets,120 ordinary actions, boundary input tests, ten reconnects/ten process starts and13 held-action interruptions including EOF and SIGINT. GUI click/scroll/drag, coordinate acknowledgements, companion readback and final release/signature checks passed. No production code or permission changes. A dashboard wheel-sign test assumption was corrected and both directions explicitly verified. See [repeat report](Repeat-Qualification-v043.md).


## Exclusive invocation and hangup repair — 2026-10-25, Africa/Cairo

Mixed preview/CLI flags in0.4.3 bypassed the ownership check during a safe absent-device reproduction. Exclusive launch parsing now rejects conflicting arguments before initialization. The first0.4.4 candidate exposed default SIGHUP termination in a mouse-disabled check; the final build adds graceful hangup release and repeats the core tests. Final0.4.4/0.5 passed60 positioning targets,60 normal hardware actions, varied invocation/recovery cases, confirmed held-drag release under SIGINT/SIGTERM/SIGHUP, installed GUI commands and SAFE reconnect. Existing Bluetooth permission refreshed by the owner; final dashboard OFFLINE, buttons released, USB restored. See [qualification and limits](Invocation-Qualification-v044.md). Earlier candidates and failures remain in private evidence.
