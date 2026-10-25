# Interrupted-drag shutdown repair candidate — 0.4.3 build8

2026-10-25, Africa/Cairo. **Candidate only: built and self-tested, not installed or hardware qualified.** The installed application remains0.4.2 build7.

## Extended 0.4.2 test

The unchanged installed0.4.2 passed60/60 pointer targets across five cycles: mean1.502s, maximum2.320s, maximum error3.97 logical points. It also passed60 commands across five mouse-action cycles: single/double/right/middle clicks, wheel±1/±20 and four drag directions. Independent native event deltas were35 left down/up pairs,5 right pairs,5 middle pairs,10 wheel events in each direction,240 drag events and5 second-click down events. Buttons were released after ordinary gestures.

The live controller refused a second owner, a click before ARM, ten invalid/outside-edge actions,12 concurrent target requests and clicks before fresh ARM after each of five reconnects. Those five reconnects and guarded positioning passed.

**Failure:** immediately disconnecting during a confirmed2500ms held drag left the host’s left button down; native counts were36 down/35 up and host pressed-buttons state1 after disconnect. Ordinary USB serial returning did not establish release. A later reconnect/recovery click returned USB-report failure and did not clear the state. The test stopped and requested physical USB reset and a trackpad click. The planned five independent-process starts, additional focus guard and signal-release tests were not completed.

## Candidate change

The Mac previously cancelled Bluetooth immediately. A teardown/release ordering race is suspected; a specific firmware or OS defect is not established. The candidate sends the existing companion STOP message before disconnecting and waits350ms to allow USB button-up to settle. This request bypasses the normal command-response queue so an active drag cannot block it. Stopping still cancels queued actions, rejects new ones, invalidates target work and retains sole ownership until CoreBluetooth confirms disconnection. The delayed callback checks the same peripheral and stopping state before cancelling, preventing it from closing a newer session. Unexpected connection loss still uses device cleanup and is not solved or qualified by this change.

Optimized build, strict temporary-bundle signature and Swift input/queue/expiry/cancellation/RPC/pointer self-tests passed. Flipper0.4 source/binary remains unchanged. Existing companion already recognizes STOP out of band. The candidate must pass repeated held-drag shutdown, reconnect/USB reports, normal-action regression and installed-GUI checks before installation/release is called complete. Its350ms grace is a bounded best effort, not host-confirmed release.

## Resume and rollback

After owner USB reset, confirm native host button state0; first test five held-drag disconnect/reconnect cycles against the candidate while leaving installed0.4.2 unchanged. Preserve failed evidence. Only install a fully qualified candidate, then refresh the same existing Bluetooth grant if macOS requires owner authentication. No broad privacy reset, new certificate, gameplay input or firmware replacement.
