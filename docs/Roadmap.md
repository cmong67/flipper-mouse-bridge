# Optimization roadmap

The bridge is verified for mouse delivery, four-direction and diagonal dragging in both Kingshot maps, and navigation through several scrollable panels. Kingshot scrolling uses held left-button dragging; tested wheel commands had no visible effect. An assistant-orchestrated focus, pointer correction and Infirmary-selection sequence also passed without user pointer placement. The next milestone is repeatable targeting with visual confirmation.

1. **Pointer targeting:** observe physical pointer location, calibrate relative counts, handle Retina/window coordinates, verify final position before click. Proposed acceptance: twenty harmless targets within four logical points, zero unintended clicks.
2. **Connection and recovery:** device picker, remembered device, bounded scan/retry, clear session state, fresh arming after reconnect, no stale-command replay.
3. **Failure qualification:** physical BACK, Bluetooth loss, unplugging, sleep/wake, GUI delayed command cancellation. Keep individual pass/fail evidence.
4. **Supervised gameplay:** qualify harmless panel opening/return and map pans, with observation before and verification after every action.
5. **Performance and releases:** measure latency/error; pin toolchain; add compatibility coverage; choose licensing and public signing/release strategy.

The development paper explains the rationale and proposed acceptance criteria. The twenty-target positioning criterion passed in round 2. Recovery is partly qualified: normal stop and idle controller termination restored USB; reconnection required fresh arming. Other fault cases remain pending.

The [broad Kingshot qualification](Kingshot-Qualification.md) records the expanded navigation coverage. Reusable startup/focus/positioning, precision measurement and recovery remain the next milestones.

## Updated priorities after round 2

Twenty-target positioning, cold launch and basic full-screen navigation passed; see [round 2](Kingshot-Round-2.md). Prioritize packaging startup/focus/state verification, calibrating movement to reduce the measured 3.350-second mean positioning time, then held-button and physical-device recovery. The existing positioning code is test orchestration, not a shipped controller feature.

## Version 0.2 priorities

Built-in startup/focus/positioning, bounded connection and command handling, remembered device identity and same-app reconnect are now implemented. Twenty-target positioning passed in the refined controller; the measured mean was 1.49 seconds, with different orchestration overhead from round 2. See [v0.2 qualification](Refined-App-Qualification.md).

1. Qualify the complete GUI flow and physical recovery: BACK, Bluetooth loss, unplugging, sleep/wake and held-button abrupt faults.
2. Add verified game-screen/loading recognition before semantic actions, then qualify Spaces, displays and window changes.
3. Add locally stored target profiles for supervised navigation only after screen recognition is reliable.
4. Measure longer-session reliability and action latency with a consistent benchmark; tune only against those results.
5. Decide signing/notarization and packaged release distribution when external installation is required. Preserve offline runtime and no telemetry.


## General-purpose revision — 8 October 2026

See [v0.3 review, qualification and dashboard design](General-Purpose-Controller.md) for the current architecture, installed tests and resolved GUI Bluetooth startup gate and remaining physical fault tests. This document retains its historical findings.


## Final v0.3 qualification — 8 October 2026

GUI startup, same-process reconnect and full relaunch passed after the installed executable’s existing Bluetooth grant was refreshed. Final browser commands and20-target positioning passed (mean1.131s, maximum3.97pt). Prioritize physical display/BACK, held-input faults, sleep/wake and equivalent-target timing. Proposed AI HID Controller / AI HID CTRL naming is deferred to the next build; current installed build remains unchanged.
