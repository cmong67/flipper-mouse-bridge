# HID Emu Mac icon — 2026-11-18

Mac **2.0.1 build 3** adds a native icon to the unified Flipper Zero + Cardputer app. The design upgrades the earlier AI HID CTRL pointer/circuit icon: a warm-white pointer with a mouse wheel, a slate-blue rounded tile and two connections. Orange represents Flipper Zero; cyan represents Cardputer. The 1254 × 1254 PNG master preserves transparency outside the tile.

Artwork was created with the built-in image-generation tool using the earlier PNG as a visual reference. [Master artwork](../assets/icons/HID_Emu_App_Icon_2026-11-18_v01.png); [saved design prompt](../assets/icons/HID_Emu_App_Icon_2026-11-18_v01.prompt.txt). No text or tiny device drawings are used, so the principal silhouette remains useful at Dock sizes.

`scripts/build-hid-icon.sh` uses macOS sips and iconutil to export the standard 16–1024-pixel native ICNS representations. `unified/build.sh` copies the resource into the bundle before signing; CFBundleIconFile registers HIDEmu. The app identity remains stable. Mouse-control sources and both companion firmware versions are unchanged: Cardputer1.3.0 and Flipper1.1.0. A backup of Mac2.0.0 was preserved before installation.

Validation includes native image decoding, icon representation sizes, bundle metadata, strict signature verification and a Mac dashboard relaunch. This is an artwork/package update; it adds no gameplay or failure-condition qualification. The previous release and its checksums remain available for rollback.

Final installed executable SHA256 `41b32f3ba8937df8fd7cd31ea7df27902e48fd52b9d5bc5d7f365ce8d2be1ffd`; ICNS SHA256 `6cd84cd0712b6954f3d046e5fc82ecd6aebc6a7f344af62c92ad8730773a6a35`. All ten decoded ICNS representations have the expected dimensions; installed resource matches the repository. Strict ad-hoc signature passes. The rebuilt executable differs from2.0.0 despite unchanged control source; this release therefore has separate hashes and a preserved rollback bundle.

The installed Mac GUI reconnected to Cardputer1.3.0 and Flipper1.1.0, both with HID ready and mouse disabled. The owner allowed the rebuilt app's Bluetooth prompt. Final app is observing Flipper, disarmed; no ARM or HID commands were issued during this icon update. Dock inspection through accessibility timed out, so live Dock rendering was not independently confirmed; bundle registration and native resource checks passed. Native artwork was inspected at128px and32px.
