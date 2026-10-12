# Mac icon installation — version 0.4.1

Date: 2026-10-13, Europe/London. User requested installation of the newly designed AI HID CTRL icon.

Converted the PNG master to native ICNS, bundled it as `Contents/Resources/AppIcon.icns`, registered `CFBundleIconFile=AppIcon`, and updated Mac version to 0.4.1 build 6. The build script now includes the icon before signing. Mouse-control code and Flipper companion 0.4 are unchanged.

Verified optimized build/self-tests, strict installed signature, native system icon resolution and successful GUI relaunch displaying version 0.4.1. Previous GUI was observed OFFLINE before replacement. Prior bundle is retained privately for rollback; no gameplay or mouse actions were used.

Installed executable SHA256: `267ee76e400ebbc77a6eb1fcb3b9a10cace21404c4cc8f30b535de484a199b18`.

Installed ICNS SHA256: `e2a11e5c7e9c625688e2f34f3598b8c3eafa4087533a6b02a431c6d1f15b4e1e`.

Bluetooth reconnection is pending owner Touch ID authentication for refreshing the same existing grant. The updated ad-hoc signature stayed at state0/authorization0 despite Settings showing access enabled. Controller closed while the scoped System Settings prompt is pending; no privacy reset or expanded permission requested. Icon installation is verified; reconnect qualification is not yet passed.

Rollback: close the controller, restore the previous verified bundle, verify its signature and reopen. A Bluetooth grant refresh may be required for the restored build as well.
