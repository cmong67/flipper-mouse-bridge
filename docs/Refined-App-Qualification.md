# Refined application qualification — v0.2

Date: 7 October 2026. The refined Mac application is installed on the development MacBook Pro. The Flipper companion and official firmware 1.4.3 remain unchanged. This report supersedes earlier descriptions of the Mac controller's manual placement delay and restart requirement; earlier navigation results remain historical evidence.

## Architecture and local operation

The Mac application is a native Swift/AppKit executable using CoreBluetooth for local device commands, NSWorkspace for game launch/focus, and CoreGraphics for observing window bounds and pointer position. Every pointer movement, click, scroll and drag is emitted by the Flipper through USB HID. The application does not synthesize software mouse events.

The installed Mac bundle contains its runtime code and uses system frameworks. No Python, developer tools, cloud service, web endpoint, account or subscription is required at runtime. Source inspection found no networking client, web service, telemetry or subprocess-based mouse injection in the Mac or Flipper application. Preferences and cached device identity are stored locally. The companion FAP is a separate hardware prerequisite; Kingshot's internet requirement is independent. Repository distribution and toolchain downloads are outside the offline runtime boundary.

The controller now has explicit disconnected, scanning, connecting, starting, ready, armed, stopping and failed states. Discovery, connection and RPC waits have deadlines. Input is validated, the command queue is capped at eight entries, and queued actions expire after five seconds. Only one RPC/action is active at a time. Stop and disconnect clear pending actions. Reconnection requires fresh arming, and an OS file lock prevents competing GUI/CLI controllers.

Prepare launches or focuses Kingshot and moves to the visible window center without clicking. Send takes a percentage target in the current game window, focuses the game, and uses hardware mouse correction until the observed cursor is within four logical points. It checks focus, arming and window geometry during correction. An invalid target, edge target, changed window or failed positioning blocks the subsequent action. Game loading and screen/control recognition still need visual confirmation by the operator.

Modern macOS activation initially failed with the older activation call. The corrected implementation uses the SDK's cooperative activation/yield API, then verifies that Kingshot became frontmost. The harmless installed-app ACTION test subsequently passed from a different foreground application.

## Evidence

| Check | Outcome and scope |
|---|---|
| Swift input/queue tests | Passed bounds, queue capacity, expiry and cancellation |
| RPC tests | Passed varint boundaries, partial frames, nested payload and truncation |
| Actual Flipper C handler | Passed arming, bounds, double-click, scroll, drag interpolation, interruption, report failure and button release |
| Installed signature | Strict local verification passed for the installed v0.2 bundle |
| Controller ownership | A second CLI controller was rejected |
| Discovery deadline | Scan timed out after 15 seconds; CLI remained responsive |
| Hardware start | Cached/discovered device connected; PING returned PONG; ARM returned ARMED |
| Fresh arming | Unarmed movement was rejected |
| Pointer targeting | Twenty movement-only targets passed within four logical screen points |
| Guarded ACTION | Installed app focused Kingshot, positioned at window center and completed MOVE 0 0 |
| Edge target | ACTION 0 0 CLICK 1 1 was rejected before clicking |
| Same-process recovery | DISCONNECT then CONNECT returned to Ready; PING passed and unarmed MOVE was rejected |
| Normal shutdown | STOP disconnected; controller exited cleanly |

The twenty-target run finished with mean error 3.58 points and maximum 3.99 points. Mean elapsed positioning time was 1.49 seconds, with a 0.460–1.874-second range; mean correction count was 6.45 moves, with a 2–8 range. The earlier run averaged 3.35 seconds with more external observation/tool overhead. The observed reduction is useful end-to-end evidence, not a controlled transport latency comparison. This run used the same correction loop shipped in the final build; subsequent changes concerned foreground activation, GUI input validation and same-process CLI disconnect.

## Limits and next acceptance gates

The GUI window was observed running, but native UI automation could not reliably resolve the replacement app identity. Full GUI button interaction remains unqualified; CLI tests exercise the shared controller and targeting logic. Earlier browser/game click-and-drag results apply to the unchanged Flipper companion and older controller, not a complete qualification of every v0.2 GUI action.

Test physical BACK, actual Bluetooth interruption, cable removal, sleep/wake and abrupt faults while a button is held. Verify that the pointer/button state and normal USB recover and that no old action is replayed. Then test multiple Spaces/displays, game loading transitions and longer supervised sessions. Window/focus checks do not recognize the game screen or continuously police another application taking focus throughout a held drag. Raw CLI mouse commands intentionally do not enforce game focus.

No purchases, attacks, upgrades, resource claims or unattended gameplay workflow were added. No background service or scheduled automation was installed. The local ad-hoc signature is suitable for this development installation; distribution signing/notarization remains a separate release decision.
