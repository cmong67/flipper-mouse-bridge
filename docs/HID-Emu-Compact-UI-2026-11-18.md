# Compact HID Emu interface — 2026-11-18

The owner's earlier dashboard had cramped alignment and inconsistent spacing. The new native interface groups connection, pointer/radar, arming and STOP, active applications, and command activity into aligned slate panels with consistent padding. It opens at 760 × 620 points; View → Compact Window uses 720 × 580. Version appears in both title and header. Activity, Apps and Display share the lower panel; essential switches and command entry stay visible. Connection settings move behind the sliders button.

Mac 2.1.0 build 4 introduced this layout. The owner then reported a white Dock icon despite correct bundle artwork. Explicit runtime icon assignment addressed that case; the owner acknowledged the rebuilt app. Mac 2.3.0 build 6 extends the compact layout with Device updates and a Classic/Quiet RGB target selector.

Native UI inspection verified both default and minimum sizes, including the five-row Display settings. Source and installed bundle signature checks passed. These checks do not establish accessibility coverage at every text size or monitor scale. See the [spectrum and updater report](HID-Emu-Spectrum-Updates-2026-11-18.md) for current versions and hardware evidence.
