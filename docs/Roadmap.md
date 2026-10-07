# Optimization roadmap

The bridge is verified for mouse delivery and two-direction map dragging in native Kingshot. An assistant-orchestrated focus, pointer correction and Infirmary-selection sequence also passed without user pointer placement. The next milestone is repeatable targeting with visual confirmation.

1. **Pointer targeting:** observe physical pointer location, calibrate relative counts, handle Retina/window coordinates, verify final position before click. Proposed acceptance: twenty harmless targets within four logical points, zero unintended clicks.
2. **Connection and recovery:** device picker, remembered device, bounded scan/retry, clear session state, fresh arming after reconnect, no stale-command replay.
3. **Failure qualification:** physical BACK, Bluetooth loss, unplugging, sleep/wake, GUI delayed command cancellation. Keep individual pass/fail evidence.
4. **Supervised gameplay:** qualify harmless panel opening/return and map pans, with observation before and verification after every action.
5. **Performance and releases:** measure latency/error; pin toolchain; add compatibility coverage; choose licensing and public signing/release strategy.

The development paper explains the rationale and proposed acceptance criteria. The single automated targeting trial is recorded in Validation; the broader acceptance targets remain pending.
