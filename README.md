# Flipper Mouse Bridge

A local macOS app that controls a Flipper Zero USB mouse. Bluetooth carries commands directly from the Mac to the Flipper; USB carries hardware mouse input back to the Mac. Version 0.2 adds bounded connection recovery, explicit arming, and built-in Kingshot focus and pointer positioning.

**Local and self-contained at runtime:** the Mac app needs no cloud service, account, subscription, Python runtime, or internet connection. It uses macOS frameworks and saves preferences locally. The Flipper requires the separately installed companion FAP. Kingshot's own network connection is separate. Building or downloading the project can require internet access; using an installed bridge does not. There is no telemetry or remote control server.

Read the [refined app qualification](docs/Refined-App-Qualification.md), [development paper](docs/Development-Paper.md), [validation record](docs/Validation.md), and [roadmap](docs/Roadmap.md). Earlier [Kingshot navigation](docs/Kingshot-Qualification.md) and [round 2](docs/Kingshot-Round-2.md) reports retain their dated evidence. This is a supervised mouse bridge, not a complete unattended gameplay agent.

## Build

Install Apple's command-line developer tools, Python 3, and official uFBT for development:

```sh
sh scripts/build-mac.sh
python3 tests/test_mouse_commands.py
python3 -m venv .venv
.venv/bin/pip install ufbt==0.2.6
.venv/bin/ufbt update --branch=1.4.3
cd flipper_mouse
../.venv/bin/ufbt
```

The Mac app is generated in `dist/Flipper Mouse Bridge.app`. The build also prints a verified temporary copy outside cloud-synced folders. The Flipper app is generated in `flipper_mouse/dist/ble_usb_mouse.fap`; transfer it to `/ext/apps/Tools/ble_usb_mouse.fap` with qFlipper, then close qFlipper. Official firmware 1.4.3 / API 87.1 / target 7 is the qualified configuration. Other firmware versions require a matching build and qualification.

## Run

1. Keep the Flipper plugged into USB and enable Bluetooth. Open the Mac app and allow Bluetooth access.
2. Enter a distinctive substring of the Flipper's advertised name and select **Connect**. Confirm matching pairing codes if requested.
3. Wait for **Ready — mouse disabled**, then select **Enable mouse**. Every new connection needs fresh arming.
4. Select **Prepare Kingshot**. The app launches or focuses Kingshot and positions the pointer at the window center. If needed, use **Choose Kingshot…** to select its application. Confirm the game has finished loading.
5. Enter the target X/Y percentages of the current game window, measured from its top-left corner. For example, `50 50` selects its center. Enter a bounded command and select **Send**. The app focuses the game, verifies and corrects pointer position, then executes the command.
6. Select **Stop** to disconnect and restore normal USB. Connect again from the same app when needed.

There is no three-second manual placement delay in version 0.2. Positioning observes the cursor and uses Flipper hardware moves. Stop cancels queued actions; reconnect does not replay them. Use only one controller at a time. Physical BACK is implemented on the Flipper but still awaits a live qualification test.

## Advanced terminal control

```sh
"dist/Flipper Mouse Bridge.app/Contents/MacOS/mouse-bridge" --cli DEVICE_NAME
```

| Command | Action |
|---|---|
| `PING` / `ARM` | Check connection / enable this session |
| `PREPARE` | Launch or focus Kingshot and position at center |
| `ACTION 50 50 MOVE 0 0` | Focus and position at window center; harmless no-op |
| `ACTION 50 50 CLICK 1 1` | Focus, position, then left-click the supervised target |
| `POINT x y` | Position at absolute logical screen coordinates in focused Kingshot |
| `STATUS` | Report connection, game focus, pointer and window bounds |
| `MOVE 30 0` | Raw relative HID movement |
| `CLICK 1 1` / `CLICK 1 2` | Raw left click / double-click |
| `CLICK 2 1` / `CLICK 4 1` | Raw right / middle click |
| `SCROLL -3` | Raw vertical wheel |
| `DRAG 120 0 1000` | Raw left-button drag for one second |
| `DISCONNECT` / `CONNECT DEVICE_NAME` | Stop / reconnect without exiting |
| `STOP` / `QUIT` / `RELEASE` | Disconnect and exit |

Raw mouse commands act immediately and do not enforce Kingshot focus. GUI Send and CLI ACTION use the guarded positioning path. MOVE/SCROLL accept −127…127; DRAG accepts ±2000 per axis and 100…3000 ms. HID counts differ from screen pixels. Kingshot maps and tested lists responded to held-button dragging; tested wheel commands had no visible game effect.

## Verification scope

Version 0.2 passed native Swift protocol/queue/input tests, tests of the actual Flipper C command handler, exclusive controller ownership, hardware connection/arming, bounded scan timeout, and twenty movement-only targets within four logical points. Mean positioning time was 1.49 seconds in that run. The installed build passed strict local signature verification. The shared GUI/CLI focus-and-position path passed a harmless ACTION test; an edge target was rejected before clicking.

Native automation could not reliably inspect the replacement GUI, so its complete button flow is not yet qualified. Physical BACK, held-button abrupt faults, cable loss, sleep/wake, multiple displays/Spaces and extended unattended use remain pending. The app uses a local ad-hoc signature, not Apple notarization. See the qualification report for evidence and limits.

Sources: [official firmware](https://github.com/flipperdevices/flipperzero-firmware/tree/1.4.3), [uFBT](https://github.com/flipperdevices/flipperzero-ufbt).
