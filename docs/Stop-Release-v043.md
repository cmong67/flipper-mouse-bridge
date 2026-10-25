# Interrupted-drag shutdown and USB readiness repair — 0.4.3 build8

2026-10-25, Africa/Cairo. **Mac0.4.3 build8 and AI HID CTRL0.5 are installed. Hardware regression and installed dashboard qualification passed.** Earlier checkpoints below preserve the failures and candidate sequence; the latest qualification section supersedes their pending statuses.

## Extended 0.4.2 test

The unchanged installed0.4.2 passed60/60 pointer targets across five cycles: mean1.502s, maximum2.320s, maximum error3.97 logical points. It also passed60 commands across five mouse-action cycles: single/double/right/middle clicks, wheel±1/±20 and four drag directions. Independent native event deltas were35 left down/up pairs,5 right pairs,5 middle pairs,10 wheel events in each direction,240 drag events and5 second-click down events. Buttons were released after ordinary gestures.

The live controller refused a second owner, a click before ARM, ten invalid/outside-edge actions,12 concurrent target requests and clicks before fresh ARM after each of five reconnects. Those five reconnects and guarded positioning passed.

**Failure:** immediately disconnecting during a confirmed2500ms held drag left the host’s left button down; native counts were36 down/35 up and host pressed-buttons state1 after disconnect. Ordinary USB serial returning did not establish release. A later reconnect/recovery click returned USB-report failure and did not clear the state. The test stopped and requested physical USB reset and a trackpad click. The planned five independent-process starts, additional focus guard and signal-release tests were not completed.

## First candidate change — historical checkpoint

The Mac previously cancelled Bluetooth immediately. A teardown/release ordering race is suspected; a specific firmware or OS defect is not established. The candidate sends the existing companion STOP message before disconnecting and waits350ms to allow USB button-up to settle. This request bypasses the normal command-response queue so an active drag cannot block it. Stopping still cancels queued actions, rejects new ones, invalidates target work and retains sole ownership until CoreBluetooth confirms disconnection. The delayed callback checks the same peripheral and stopping state before cancelling, preventing it from closing a newer session. Unexpected connection loss still uses device cleanup and is not solved or qualified by this change.

Optimized build, strict temporary-bundle signature and Swift input/queue/expiry/cancellation/RPC/pointer self-tests passed. Flipper0.4 source/binary remains unchanged. Existing companion already recognizes STOP out of band. The candidate must pass repeated held-drag shutdown, reconnect/USB reports, normal-action regression and installed-GUI checks before installation/release is called complete. Its350ms grace is a bounded best effort, not host-confirmed release.

## Original resume plan — historical checkpoint

After owner USB reset, confirm native host button state0; first test five held-drag disconnect/reconnect cycles against the candidate while leaving installed0.4.2 unchanged. Preserve failed evidence. Only install a fully qualified candidate, then refresh the same existing Bluetooth grant if macOS requires owner authentication. No broad privacy reset, new certificate, gameplay input or firmware replacement.


## Recovery continuation

Owner unplugged/powered off the Flipper, then reconnected it. The previous minimal test fixture was no longer running; a fresh fixture showed host buttons0. Added a normal Quit menu and close-window termination to that private fixture and preserved the failed event capture before starting fresh logs.

The first Mac0.4.3 candidate released a confirmed held drag in0.367s, but a click after reconnect still failedUSBreport. That candidate was rejected. The companion previously announced RPC startup before installing/enumerating the USB HID profile. AI HID CTRL0.5 now sets the profile, waits250ms, then retries a neutral buttons-up report at100ms intervals (up to30 attempts), waits50ms after a successful submission, and only then announces startup. If readiness cannot be established it exits; the Mac now treats a startup app-exit event as failure. Neutral reports emit no intentional pointer movement or click. They are submission checks, not host acknowledgements.

This ordering follows the [official Flipper1.4.3 USB HID implementation](https://github.com/flipperdevices/flipperzero-firmware/blob/1.4.3/targets/f7/furi_hal/furi_hal_usb_hid.c): profile initialization and host endpoint configuration are separate, and report submission can fail while disconnected or awaiting its semaphore. Exact low-level origin of the persistent failure is not established; the readiness gate and successful live recovery establish the practical repair within tested conditions.

Real C handler tests additionally cover delayed readiness, permanent disconnection and pre-cancelled initialization. Flipper target7/API87.1 build passed; installed readback matched rebuilt companion SHA256 `7c6e5f02038f980d65f3d5d399be92dbf8ea938e033dd720bc74ac9f8756a907`. Previous installed FAP is retained privately for rollback.

Combined candidate and installed companion passed five consecutive confirmed-held2500ms drag disconnects: host buttons returned0 and native leftdown/up counts balanced; every reconnect then delivered a successful click. Disconnect completion was approximately0.366–0.368s. Broader regression and final Mac installation/GUI qualification are still pending at this checkpoint.


## Final combined-build qualification

The final optimized Mac executable (SHA256 `ff5798e588763801da7b68475cc08de97afd4297490ddb125889ca75e4dfd9c2`) was installed after strict signature verification and Swift self-tests. The installed executable is identical to the hardware-tested temporary build. The Flipper0.5 installed readback matches the build hash above. Source-handler tests passed, including delayed/disconnected/cancelled USB initialization. Previous Mac0.4.2 and companion binaries remain available privately for rollback.

| Check | Observed result |
|---|---|
| Positioning | 60/60 targets across five cycles; mean1.507s, max2.068s; mean error3.15, max3.99 logical points |
| Ordinary mouse input | 60 commands: single/double/right/middle clicks, both scroll directions at small/large values, four drag directions |
| Independent native event capture | 35 balanced left pairs,5 right pairs,5 middle pairs;10 wheel events per direction;240 drag events;5 second-click events; host buttons0 |
| Held-drag Stop | Five consecutive confirmed-held2500ms drags released; each reconnect then delivered a click; stop completion0.366–0.368s |
| Main regression shutdown | Additional confirmed-held drag disconnect released buttons |
| Session boundaries | Five reconnects returned SAFE and required fresh ARM; five independent process starts/stops passed |
| Rejected input | Second controller refused; pre-ARM input,10 invalid/outside-edge requests and12 concurrent target requests refused without unintended HID input |
| Focus guard | Installed binary refused a global point when the selected test window lacked focus; no HID dispatch or event change; preparation recovered |
| Termination | Installed controller terminated during2500ms drag; exited normally and host buttons returned0 |

Tests used an isolated native mouse fixture with independent event capture. The fixture gained a normal Quit menu and closes cleanly when its window is closed. Two focus-test harness attempts were inconclusive (overlap with an existing owner; focus did not actually change); neither was counted as a pass. The final focus test explicitly changed focus and passed. The rejected first0.4.3 candidate and0.4.2 held-button failure remain preserved privately alongside successful evidence.

These measurements do not establish a speed improvement over0.4.2: separate runs are not a controlled comparison. No Kingshot actions were sent in this qualification. Physical BACK during a held drag, unexpected Bluetooth/cable loss, SIGKILL, sleep/wake, Spaces and multiple displays remain unqualified. The350ms release grace is best effort, not host acknowledgement. Supervise held actions and retain physical USB reset as recovery.

## Installed dashboard closeout

After the scoped existing-grant authentication prompt cleared, Settings showed Bluetooth ON. The unchanged installed dashboard reported authorization3 and Ready/SAFE. Selected the exact native test process, enabled mouse, and Position + send automatically focused the test window, positioned at50%/50% and delivered CLICK1 1 with DONE. A second connection returned SAFE without automatic arming; both Stops completed. Final dashboard is OFFLINE, host buttons0, ordinary USB serial restored. The fixture quit normally. Strict installed signature and unchanged executable hash reverified after testing. No further owner authentication is needed for this tested executable; changed ad-hoc builds may require another grant refresh.
