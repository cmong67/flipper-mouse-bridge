# General-purpose controller and companion dashboard — v0.3

Status: **v0.3 installed; final-build GUI/CLI browser qualification passed.**

Date:2026-10-08, Asia/Hong_Kong. Lead-performed design/code review; no independent reviewer was dispatched.

## Problem and decision

The v0.2 controller embedded one game’s bundle ID and startup behavior. During the latest client session, preparation stalled until the exact running installation was selected; hardware scrolling then worked. Native event-tab dragging still became an endpoint tap. These are distinct issues: application identity/focus in the bridge, and per-view routing in the client.

The controller now owns transport, observation, guarded targeting, timing and presentation. Client workflows own application discovery/startup, view recognition, action permissions and native-versus-hardware routing. No game identifier or game-specific startup preference remains in active source. The bundle ID and controller lock location remain stable to prevent competing legacy/new controllers and preserve existing preferences.

## Architecture

`Client workflow → selected app/PID + bounded command → Mac observation and dispatch guard → Bluetooth RPC → Flipper command handler → USB HID → target`

Mac modules: `ControlPanel.swift` presents controls/telemetry; `PointerMap.swift` draws a local geometry map; `TargetController.swift` handles exact app selection, focus and feedback; `MouseBridge.swift` serializes RPC and measures latency; `BridgeSupport.swift` validates input, queue and ownership; `main.swift` routes GUI/CLI and offline checks.

Runtime is local/self-contained. System AppKit/CoreGraphics/CoreBluetooth supply the UI, observation and transport. No server, cloud/API call, telemetry upload, external runtime or keyboard injection was added.

## Efficiency changes and evidence limits

1. Preparation only focuses/verifies a visible window. It no longer pays for a center movement unrelated to the next control.
2. If the pointer is already within4 points, positioning immediately succeeds. A position-only `MOVE 0 0` check completes locally.
3. Feedback settling drops from100 to50 ms after successful move completion. Axis gains adapt from bounded observed HID displacement; incompatible/opposite/outlier feedback is discarded. Report limits,32 corrections and8-second deadline remain.
4. Release compilation uses Swift optimization. One RPC remains active; no batching/replay of consequential commands was introduced.
5. Display observation is10 Hz while visible; window geometry polling is2 Hz. Pointer-map repaint occurs only when point/geometry changes. These observations add no Bluetooth requests.
6. Command timing runs from dispatch to response completion. It excludes queue wait and app focus/positioning. Last latency and exponential moving average are diagnostic, not total-action speed claims.

Controlled equivalent-target hardware measurements are required before calling this faster. Gains can vary with macOS acceleration, display geometry and interference from manual pointer movement. Never infer pixel displacement from HID counts.

## Review and corrections before installation

- Removed ambiguous bundle-ID startup searches. PID selects the exact running app; choosing an application file matches its installation URL. No automatic target selection on launch.
- Added a final focus/geometry/generation guard when each queued movement/action dispatches, closing the gap between enqueue and actual send.
- Preserved queue limit8,5-second expiry, single positioning task, cancellation generation, exclusive process lock and fresh ARM after reconnect.
- Replaced a nonfunctional “send at pointer” dashboard idea: clicking the dashboard changes focus. “Use target pointer” instead copies a recent observed target point into percentage fields without input. CLI HERE requires current target focus.
- Kept the device display’s command data synchronized in a small snapshot; paint does not hold the RPC lock.
- Added a pointer-distance check at actual action dispatch; moving the pointer after positioning prevents the queued action. Saved dashboard coordinates are rejected when the selected window geometry changes.
- Added standard Quit behavior and compact connection labels; Bluetooth initializes on Connect so read-only previews make no transport requests.
- Kept old app/FAP recoverable. No companion replacement while another chat owns the controller.

## Flipper dashboard assessment and design

The companion’s128×64 display is appropriate for a compact execution/status dashboard, not a miniature Mac desktop. It has no independent view of the Mac pointer. Absolute X/Y would require host telemetry; this revision deliberately avoids that extra transport load and any misleading synthetic position.

![Flipper dashboard design](assets/flipper-dashboard-v03.svg)

| Row | Content | Meaning |
|---|---|---|
| Header | AI HID CTRL · SAFE/ARMED | Host has enabled this session or input is disabled |
| Transport | BLE:ON/OFF · USB:ON/OFF | RPC session present and USB HID connected |
| Command | `>` busy, `o` ended, `!` error + command | Active/last bounded command, not a semantic game action |
| Timing | Cmd:N · last ms | Processed-command count, including checks/errors; execution duration excludes Bluetooth latency |
| Footer | BACK: STOP + RELEASE | Physical emergency exit releases buttons and restores previous USB |

Display updates at command boundaries and every250 ms when idle. Long drags show the command as busy; no live percentage progress or absolute Mac coordinates is claimed. The Mac displays the live pointer and transport timing. Firmware remains official1.4.3; the external companion app changes to0.3.

## Verification and remaining qualification

Both native Mac and Flipper builds compile. Mac self-tests cover command bounds, queue expiry/cancellation/dispatch guard, adaptive-step limits and invalid feedback, and RPC framing. The existing harness executes the actual C input handler for arm/bounds/click/scroll/drag/interruption/report failure/button release. Offscreen Mac dashboard render was visually reviewed without activating a window or competing with gameplay.

Installed hardware results and the resolved GUI startup gate are recorded below. USB removal, Bluetooth interruption while held, sleep/wake, multi-display/Spaces and long-session behavior are separate fault qualifications; successful compilation is not those tests. Existing historical0.2 hardware qualifications apply only to that version.

## Installation and rollback

Install the verified temporary Mac bundle as ChatGPT Mouse Controller.app; retain Flipper Mouse Bridge.app. Both share one controller lock, so only one can run. Back up the original companion FAP, replace it while normal USB is available, read it back and compare hashes. Stop/close controller before reverting either component. The unchanged protocol allows the new Mac controller to work with the old FAP, which lacks the new dashboard. Do not automatically roll back/replay after an uncertain action result.

## Final installed-build qualification — 8 October 2026

The companion0.3 was installed and read back byte-for-byte. The final Mac executable was installed from the verified temporary bundle, then kept unchanged throughout permission refresh and live testing. Strict installed signature verification passed again after testing. Source checkpoint: `d83d8f9e8f310799c4cdd4101aabbda72007ca0a`.

| Test | Observed result on final installed build |
|---|---|
| GUI Connect after permission refresh | Ready in about4 seconds; no broad privacy reset |
| GUI Stop/Connect in the same process | Ready in about1 second, Safe; fresh enable required |
| GUI Quit/relaunch/Connect | Ready in about2 seconds; Bluetooth authorization remained allowed; no new permission prompt |
| GUI explicit target / Prepare | Selected exact browser PID; focused verified window without centering input |
| GUI left/right/middle and double click | Commands returned DONE; browser received6 down/6 up events across clicks and drag,4 clicks,1 double click |
| GUI vertical scroll / drag | Both wheel directions observed (2 wheel events);500 ms drag produced44 drag events and released its button |
| GUI edge guard / pointer copy |0%/0% rejected before dispatch; completed-command count unchanged; recent target point copied without input |
| CLI final20 movement-only targets |20/20 within4 logical points; mean1.131 seconds, mean error3.55 points, maximum3.97 points |
| CLI Prepare / reconnect |3 preparations passed; disconnected/reconnected action rejected before fresh ARM; PING returned PONG |
| Shutdown |Normal STOP/Quit, no controller process left, normal USB serial returned; final browser buttons=0 |

The final positioning sequence used a1562×1076-point browser window. Times measure focus/positioning until convergence; they do not include a semantic click. This is supervised browser qualification, not an equivalent-target speed comparison against v0.2 or qualification of every macOS app. The preceding v0.3 build's20-target mean1.117 seconds remains historical evidence only. No Kingshot action was issued in this qualification; the gameplay client remained stopped.

The Mac coordinate map and active/last command monitor updated during hardware actions. A minor presentation issue remains: the introductory permission hint can persist after Ready, although the connection badge and log correctly show connected/Safe. The installed executable remains unchanged; this cosmetic correction belongs in the next build and its qualification.

The Flipper display was compiled/installed but its physical legibility and physical BACK behavior remain unobserved. USB removal, Bluetooth loss while held, sleep/wake, multi-display/Spaces, continuous focus checking through a held drag, and long-session behavior remain separate follow-up work. Dispatch guards do not provide semantic control recognition or a promise of unattended operation.

## GUI startup problem and verified repair

Earlier dashboard launches stalled with CoreBluetooth unknown state. Moving initialization to Connect alone did not resolve the live attempt. Once gameplay stopped and released ownership, filtered TCC info logs showed the rebuilt executable rejected against the permission record's older cdhash requirement, despite an enabled switch in System Settings. This directly supported an app-identity mismatch rather than a broken Bluetooth transport.

The final build separates cancellable Bluetooth initialization (60-second deadline) from device discovery (15 seconds after powered-on), logs authorization state, and accepts an optional existing `MOUSE_CODESIGN_IDENTITY`. Those changes improve diagnosis and bounded behavior; refreshing the grant for the actual installed executable resolved this observed startup failure. The owner approved the scoped System Settings refresh with Touch ID. Subsequent TCC logs accepted the executable's identity and user consent; GUI Connect, same-process reconnect and full relaunch all reached Ready. No `tccutil` reset was executed, and no other privacy grants were changed.

The current Mac has no valid Apple app-signing identity available and this build is ad-hoc signed. Git signing is separate. Apple DTS recommends an Apple Developer identity during development ([Apple Developer Forums](https://developer.apple.com/forums/thread/663889)). Apple documents Bluetooth authorization and purpose-string requirements ([Core Bluetooth](https://developer.apple.com/documentation/corebluetooth), [Designing for Privacy](https://developer.apple.com/videos/play/wwdc2019/708/)); this app includes its purpose string. Rebuilding can change an ad-hoc code identity: verify the installed bundle and requalify privacy/startup rather than trusting the Settings switch alone. No new certificate, account, weakened signature requirement or firmware flash was used.

## Next priorities and naming assessment

1. Observe the actual Flipper screen and physical BACK, then qualify Bluetooth loss during drag, cable removal, sleep/wake, multiple displays/Spaces and a longer supervised session.
2. Compare old/new controller using the same targets, window, acceleration and timing boundaries before claiming a speedup. Include queue wait and app focus in total-action measurements.
3. Retain native Apple/CUA control for working functions. Each client owns startup, view recognition, per-function fallback rules and visual outcome checks; never replay an uncertain consequential command automatically.
4. Correct the stale Ready hint in the next build. Verify moved-window and displaced-pointer rejection live in addition to existing handler/dispatch self-tests.
5. **AI HID CTRL** is now applied to the Flipper app-list metadata and dashboard header; **AI HID Controller** remains proposed for the Mac app. Current commands are mouse-only. The Mac executable, bundle ID, preferences and ownership lock remain unchanged.


## Flipper name revision and live client limit — 8 October 2026

After the user requested the actual name update and stopped gameplay, the Flipper app metadata and dashboard header were changed to **AI HID CTRL**. A fresh backup of the installed companion matched the preceding qualified hash. The rebuilt companion passed APPCHK for target7/API87.1, was installed at the existing compatibility path, and read back byte-for-byte; its embedded app metadata contains the new name. The FAP format stores major/minor only, so companion version remains0.3 (name revision). The Mac bundle was not rebuilt or re-signed. No input-handler or command-protocol change was made; no new mouse/game input was used to verify the rename. Physical screen legibility remains unobserved.

A separate live Kingshot run connected and armed successfully, but Prepare failed twice with “Selected app did not expose a focused visible window,” including after native raising. No hardware action beyond ARM was dispatched; the client stopped the bridge and continued with native control until the user's stop instruction. This narrows the current qualification: browser startup/actions passed, but the latest game window/focus/Space condition remains unresolved. The rename does not fix it. Previous game drag-scrolling results do not certify current Command Center navigation.
