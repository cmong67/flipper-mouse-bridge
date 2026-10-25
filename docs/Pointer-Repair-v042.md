# Pointer positioning repair — 0.4.2 build 7

Verified 2026-10-25, Africa/Cairo, on the installed Mac build and existing AI HID CTRL 0.4 companion. This is a local controller repair; no gameplay input was issued.

## Failure and cause

The previous 0.4.1 installation had a valid strict signature and working Bluetooth/Flipper transport. A movement-only attempt on an isolated native test window reproduced 32 corrections, including alternating saturated ±127 reports, ending in “Positioning timed out. No click sent.”

The positioning loop used a fixed gain of 2.2 for corrections within 120 points. Its adaptive estimate ignored samples above 8 points/count and reports below 32 counts, then clamped gain to 2.2–6. Those assumptions cannot accommodate the observed pointer response; repeated overshoot did not teach the loop how to recover. The originating system/device change is unknown; this is not evidence that a particular OS setting caused it.

## Change

Use observed gain at every distance. Accept directional finite feedback from small reports and samples up to 128 points/count, raise the estimate promptly after overshoot and relax it gradually as acceleration falls. Start with a maximum 24-count report at the initial gain; increase the bound when measured gain is low, within the existing ±127 protocol range. Fine correction permits a one-count report and a two-point axis deadband. The existing four-point arrival check, 32-attempt/eight-second deadline, focus/window dispatch checks, single ownership, fresh arming and cancellation remain in force.

On Ready, the dashboard now replaces its obsolete Bluetooth-approval hint with a connected instruction. Flipper code, display feed and icon are unchanged.

## Qualification

- Optimized build, strict signature and Swift input/queue/expiry/cancellation/RPC self-tests passed. Positioning regressions cover five sensitivities (0.6–24) and four destinations, including ±700 points and nonlinear fine response.
- An early temporary candidate failed the low-sensitivity regression and raised SIGTRAP through a test precondition. It was never installed. The report with process 30085 identifies that rejected candidate, not a production GUI crash.
- Installed 0.4.2 passed **10/10** actual Flipper positioning targets on an isolated native test window: mean **1.616 seconds**, mean error **3.36 points**, maximum **3.89 points**, 98 total reports. This is a repair qualification, not a controlled speed comparison with earlier target sets.
- Left/right/middle click, double-click, both scroll directions and a 500 ms drag all returned DONE. Independent native event counters confirmed four additional left down/up pairs (single, double and drag), one right pair, one middle pair, one event per wheel direction and 20 drag events. Down/up totals balanced.
- SAFE position-feed acknowledgements advanced 6→10→15; PING returned PONG; same-process reconnect reached SAFE with count 19. Normal Stop exited, and ordinary USB serial returned.

Installed executable SHA256: `9784b6a9bfd6291ee93ff23ababba6f6f7953a3c11e4c784bb95a8ecf11a31a5`.

The updated GUI initially reported Bluetooth authorization 0 despite the existing Settings grant. After the owner approved the scoped Touch ID refresh, the unchanged installed build reported authorization 3 and reached CONNECTED · SAFE in approximately one second. Its connected hint cleared correctly. A separate dashboard Position + send check on the native test window reached 3.56-point error in 10 reports / 1.977 seconds. STOP returned OFFLINE. CLI and GUI privacy identities can be evaluated differently by macOS. No broad privacy reset or expanded access was used. No stable Apple signing identity was available during this session.

## Limits and rollback

Kingshot, multiple displays/Spaces, sleep/wake, physical BACK and held-button cable/Bluetooth faults were not requalified in this session. Native Apple/CUA control remains the default; use the bridge only for an observed native failure. A fresh target/focus check and ARM are required for a new session.

The verified previous 0.4.1 bundle is retained privately. Close the controller, restore that bundle and verify its signature to roll back; macOS may require refreshing its existing Bluetooth grant. Replacing an ad-hoc signed build may change its privacy identity. An existing stable Apple signing identity remains an optional future improvement; Git signatures do not solve app permission identity.


## Extended test finding — 2026-10-25

A subsequent, broader test passed 60/60 positioning targets (maximum error3.97pt, mean1.502s), 60 mouse actions with matching independent native event counts, five reconnect/fresh-arm cycles, invalid-input rejection and single-controller enforcement. However, disconnecting while a confirmed 2500ms drag held the left button left macOS reporting that button down. Ordinary USB serial returned, but that did not prove button release. A reconnect/recovery click then failed its USB report. This invalidates any general shutdown-reliability inference from the earlier normal-action qualification. Version0.4.2 must not be described as fully qualified for interrupted gestures.

The stop implementation closed Bluetooth immediately and relied on the companion’s session-close cleanup. A teardown/release ordering race is suspected. A later candidate requests companion STOP before closing Bluetooth; its actual hardware result must be recorded separately. Physical USB reset was requested after the failure. No Kingshot controls were used.
