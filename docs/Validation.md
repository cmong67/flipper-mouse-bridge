# Flipper Mouse Bridge validation — 7 October 2026

The bridge was built and installed on the development MacBook Pro and Flipper Zero. Bluetooth carries control commands; the attached USB cable carries the mouse input back to macOS.

| Check | Result |
| --- | --- |
| Official firmware | Device reported 1.4.3, API 87.1, target 7 |
| Flipper build | Official uFBT compiler completed successfully |
| Installation | `/ext/apps/Tools/ble_usb_mouse.fap`; device read-back SHA256 matches the build |
| Mac app signature | Installed app passes strict codesign verification; local ad-hoc signature |
| Mac Bluetooth permission | Enabled and pairing completed by the user |
| Live Bluetooth RPC | Connected; app started; PING returned PONG; ARM returned ARMED |
| Live USB movement | Observed browser pointer movement after the Flipper MOVE/DRAG commands |
| Left/right/middle clicks | Observed button 0/2/1 down and up events; right/middle auxiliary clicks |
| Double-click | Browser reported DOUBLE CLICK and double count 1 |
| Vertical wheel | Browser received wheel event with delta -4.000244140625 from SCROLL -3 |
| Sustained drag | DRAG 120 -60 800 produced 62 held-button movement updates; target moved from 100,100 to about 143,78; release observed |
| Stop during drag | STOP during DRAG 500 0 3000 disconnected Bluetooth; button-up observed after only about 19 screen points of motion |
| USB restoration | Normal USB serial interface returned after stopping |
| Reconnection | Second Bluetooth session started successfully; PING/ARM passed |
| Native Kingshot | PASS: DRAG 240 0 1000 visibly panned the city map right; DRAG -240 0 1000 visibly panned it left; no building panel opened |
| Physical BACK button | Implemented; not yet pressed in a live test |
| GUI control window | Opened successfully; Stop ended the connection attempt. Three-second mouse-command delay implemented; live mouse tests used CLI mode |

Command tests exercised the actual C command handler with a mock USB interface: arming, input bounds, double-click timing, scroll, drag interpolation, cancellation, failed reports, and release behavior passed. Swift protocol tests passed varint boundaries, partial frames, nested application data, and truncated fields. These tests supplement the live device tests above.

HID counts are relative, not screen pixels. macOS acceleration changes the distance. Precision positioning needs feedback from the screen and calibration. Three buttons, double-click, vertical wheel, and left-button dragging are supported. Horizontal wheel, additional buttons, and trackpad gestures are outside this version. Long unattended use, sleep/wake, cable removal, and abrupt power loss have not been tested.

Installed FAP SHA256: `30836d1a1fe2e390af5b0965ffb1f37ada746e6c264c1c09034d0e63d5c6c995`.

After the Kingshot test, stopping restored the normal USB serial interface. A further CLI reconnection reached Bridge ready; discovery can take some time after disconnecting.

Public-source packaging verification: the device name is configurable and the bundle identifier is generic. Compilation, signature verification, and both test suites were repeated; the installed hardware build was retained.

## Automated focus and pointer test — 7 October 2026

PASS for an assistant-orchestrated sequence with no user pointer placement. The bridge was launched in CLI mode, Bluetooth connected, and PING/PONG and ARM/ARMED confirmed. The already-running native Kingshot window was raised. A read-only CoreGraphics observer measured the physical pointer in logical screen coordinates; bounded Flipper MOVE commands corrected its position into clear ground. A Flipper left click activated Kingshot, confirmed by the frontmost application name. A further move and left click selected the Infirmary: the game displayed “30 Infirmary” and Details/Heal controls. No Heal action was taken.

Window raising alone did not activate Kingshot; the harmless ground click established focus. Relative HID counts were corrected against measured cursor location, rather than assumed to equal pixels. STOP disconnected the command channel successfully; the normal USB serial device reappeared afterward.

This demonstrates automated bridge startup, window presentation, physical pointer positioning, focus and a building-selection click. It does not qualify cold-starting a closed game, macOS full-screen mode, a standalone one-button routine, or the twenty-target precision acceptance criterion. The game was already open, and the assistant chose corrections from observations. The GUI control window was closed during CLI operation, so its absence did not mean the bridge was stopped.

## Broad Kingshot navigation qualification — 7 October 2026

Castle and world maps passed four-direction and diagonal dragging. Building details, Heroes and its Stats/Skills/Gear tabs, all five Backpack categories, Alliance members, Events tabs/task list, Governor Profile and Conquest navigation were verified. Scrollable lists responded to held left-button dragging. Isolated wheel commands produced no visible scrolling or zooming in the tested game surfaces. Right/middle clicks and a world-ground double-click were acknowledged but had no distinct useful effect. No user pointer placement was needed. The game returned to castle view; STOP restored normal USB and the controller exited.

Read the [full qualification report](Kingshot-Qualification.md) for individual outcomes, method, limits and priorities. This broad navigation test does not qualify every game action, full-screen mode, cold startup, fault recovery or unattended gameplay.

## Round 2 — positioning, cold launch, full-screen and recovery

Verified on 7 October 2026: 20/20 movement-only targets finished within four logical points (maximum 3.991; mean 3.589). Mean positioning time was 3.350 seconds including observation and tool orchestration, not HID latency. Cold game launch, automatic focus and basic full-screen Heroes click/drag/back navigation passed without user pointer placement. The first cold-launch click only activated the game, so a harmless focus click and focus verification must precede control selection. Normal STOP and idle CLI termination restored USB; reconnect required fresh ARM and unarmed MOVE left the pointer unchanged. Returned to windowed castle and stopped the bridge.

See [round 2 report](Kingshot-Round-2.md) for measurements and scope. These results extend the earlier dated tests; they do not qualify a built-in startup routine, held-button fault recovery, physical BACK, cable removal, sleep/wake or unattended gameplay. Source and installed build were unchanged.
