# HID Emu: two devices, one Mac app

Date: 2026-11-18, America/Los_Angeles. This retrospective uses the development conversation, builds, installed-device replies and local test evidence. Review was performed by the implementing agent, not an independent reviewer.

## Evolution and owner contributions

The project began as a Mac-to-Flipper Bluetooth command bridge, with Flipper delivering USB mouse reports. October revisions added bounded commands, fresh arming, STOP/release handling, pointer displays and startup ownership. Their dated qualification reports remain historical evidence.

The owner then asked to restore M5Launcher on a Cardputer ADV and make the bridge a selectable app, rather than reinstalling complete firmware for every program. A verified original flash backup preceded Launcher installation. The future 32 GB SD card was discussed; its installation was not verified.

Successive owner observations drove the dashboard design: incorrect orientation and crowded coordinates, flickering redraws, a request for active-app names and uptime, live physical clicks and scrolling, a ten-position radar proportional to the controlled monitor, and a clean professional layout. Off-screen rendering and changed-state updates addressed flicker; the owner confirmed a stable screen. Right-click identity and double-click detection were corrected after reported mislabeling. The owner proposed different scroll colors: green UP, amber DOWN, blue horizontal.

Finally, the owner requested one Mac app for either device and a more informative Flipper display. Shared event handling and command validation now feed separate USB and Bluetooth links. Automatic selection prefers a recognized Cardputer when both are present; manual selection remains available. The owner proposed **HID Emu** after considering MouseBridge; the app subtitle explicitly names Flipper Zero and Cardputer.

## Versions and checks

Mac 2.0.0 build 2, Cardputer 1.3.0, Flipper 1.1.0. Build checks, command implementation tests under Address/Undefined Behavior Sanitizers, Swift queue/input tests, Cardputer protocol tests, and signature checks passed. Flipper's final FAP was transferred and read back byte-for-byte. A read-only capture of its actual display confirmed the new HID EMU layout.

During the unified integration, Automatic selected Cardputer with both devices present; both transport links connected, reported their companion version and accepted a small movement followed by a compensating movement. Fresh-arm gating rejected an input attempted before the ARM acknowledgement. Flipper STOP disconnected and restored its normal USB management port. These integration checks preceded the final branding-only release; the final Mac app subsequently reconnected to Flipper 1.1.0 and Cardputer 1.3.0. Flipper STOP restored its USB management port. Cardputer reported HID=1, ARMED=0, BUTTONS=0 and confirmed its Launcher menu name as HID Emu. The final Mac dashboard was left connected to Cardputer in observation mode, disarmed. Full installation logs remain private.

## Limits and recovery

The unified app has not inherited the older controller's target-PID guard or adaptive positioning. Its earlier 60/120-target and interrupted-drag qualifications do not transfer to this pair. Kingshot gameplay, physical held-button cable/Bluetooth loss, forced termination, sleep/wake and multi-display edge cases remain unqualified. A display capture verifies pixels and connection, not physical mouse delivery.

Telemetry is observation only; it does not renew arming. Device session times are not cumulative control time. Flipper is monochrome, so scroll direction uses symbols rather than colors. The stable FAP filename and Cardputer partition identifier are intentionally preserved underneath the new display name. Previous source history, device backups and old app bundles provide rollback; backups and private host identities are excluded from public GitHub.
