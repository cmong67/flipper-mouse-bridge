# Flipper Mouse Bridge

Control a USB mouse on macOS through a Flipper Zero, with Bluetooth carrying commands and USB carrying mouse input. Built for official Flipper firmware 1.4.3. Browser mouse tests and two-direction map dragging in native Kingshot passed on the development setup on 7 October 2026.

Read the [full development paper](docs/Development-Paper.md), [validation record](docs/Validation.md), and [optimization roadmap](docs/Roadmap.md). This is a supervised input bridge; precise screen targeting and complete gameplay workflows remain follow-up work.

## Build

On macOS, install Apple's command-line developer tools, Python 3, and the official uFBT package. Then:

```sh
sh scripts/build-mac.sh
python3 tests/test_mouse_commands.py
python3 -m venv .venv
.venv/bin/pip install ufbt==0.2.6
.venv/bin/ufbt update --branch=1.4.3
cd flipper_mouse
../.venv/bin/ufbt
```

The Mac application is generated in `dist/Flipper Mouse Bridge.app`. The Flipper build is generated in `flipper_mouse/dist/ble_usb_mouse.fap`. Transfer the FAP to `/ext/apps/Tools/ble_usb_mouse.fap` using qFlipper's file browser. Close qFlipper before starting the bridge. The repository excludes SDK caches and compiled distribution files. The Flipper build must match the firmware's API; other versions are not qualified here.

## Run

Keep the Flipper plugged into USB, enable Bluetooth, and allow the Mac application Bluetooth access. Supply a distinctive substring of your Flipper's advertised name:

```sh
"dist/Flipper Mouse Bridge.app/Contents/MacOS/mouse-bridge" --gui DEVICE_NAME
```

Compare and confirm the pairing code on both devices when requested. Wait for **Bridge ready**, send `PING`, then `ARM`. The GUI delays mouse commands for three seconds: focus the intended application and place the physical pointer before that delay ends. Terminal mode runs commands immediately:

```sh
"dist/Flipper Mouse Bridge.app/Contents/MacOS/mouse-bridge" --cli DEVICE_NAME
```

| Command | Action |
|---|---|
| `PING` / `ARM` | Check connection / enable this session |
| `MOVE 30 0` | Move right by relative HID counts |
| `CLICK 1 1` / `CLICK 1 2` | Left click / double-click |
| `CLICK 2 1` / `CLICK 4 1` | Right / middle click |
| `SCROLL -3` | Vertical wheel |
| `DRAG 120 0 1000` | Hold left, move for one second, release |
| `STOP` | Disconnect, release, restore normal USB |

MOVE/SCROLL accept −127…127; DRAG accepts ±2000 per axis and 100…3000 ms. Mouse counts do not equal screen pixels. Open `tests/MouseTest.html` in a browser to check delivery before another application. Use one controller connection at a time. Press BACK on the Flipper or Stop in the controller to exit; reopen to reconnect. Physical BACK is implemented but awaits a live test.

## Verification scope

The original installed build passed browser click/scroll/drag/cancellation tests and native Kingshot map pans. Public source only changes the device-name configuration and application identity; it was compiled and protocol/command tests passed. The GUI's delayed gesture flow, sleep/wake, cable loss, and prolonged unattended use remain unqualified. The Mac build uses a local ad-hoc signature, not Apple notarization.

Sources: [official firmware](https://github.com/flipperdevices/flipperzero-firmware/tree/1.4.3), [uFBT](https://github.com/flipperdevices/flipperzero-ufbt). See the paper for architecture, evidence, and references.
