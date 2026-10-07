# Kingshot qualification: round 2 — 7 October 2026

## Assessment

**Verified:** twenty movement targets reached within four logical screen points, automatic cold game launch and focus, basic full-screen navigation, normal stop/reconnect, and recovery after terminating an idle controller. No user pointer placement was required. The game was returned to its windowed castle view and the bridge stopped; normal USB serial returned and no CLI bridge process remained.

The important focus finding is that the first click after a cold launch activated Kingshot but did not open Heroes. A second click opened it. Startup should use a harmless ground click, confirm that Kingshot is frontmost, and only then select a game control. Do not blindly repeat a consequential click.

## Method and results

The unchanged installed bridge and official firmware 1.4.3 were used. Bluetooth RPC carried control commands and the attached USB cable carried HID mouse input. Native application inspection supplied screenshots and setup keyboard actions; all tested game mouse input came through the Flipper. A read-only CoreGraphics observer measured actual pointer location in logical screen coordinates.

| Test | Evidence | Outcome |
| --- | --- | --- |
| Twenty-target positioning | 20/20 movement-only targets, each final error ≤4 logical points; no click commands during benchmark | PASS |
| Automatic focus | Raised game, moved physical pointer to clear ground, hardware left click; observer reported Kingshot frontmost | PASS |
| Cold game launch | Quit game, verified process absent, launched it, observed loading and then castle; fresh game process; bridge still answered PING | PASS |
| First click after cold launch | First Heroes click activated game without opening panel; second click opened Heroes; hardware back click returned to castle | Focus step required |
| Full-screen | Entered macOS full-screen, re-read geometry, moved to Heroes control and opened it, dragged grid upward to reveal later rows, clicked back, exited full-screen | PASS for tested controls |
| Normal Stop | Controller disconnected and exited; USB serial returned on subsequent inspection | PASS |
| Reconnect without ARM | PING succeeded; MOVE rejected with “not armed or USB unavailable”; actual pointer unchanged | PASS |
| Explicit fresh ARM | ARM acknowledged; MOVE acknowledged and physical pointer moved | PASS |
| Idle controller termination | Sent SIGTERM to the test CLI process; process exited; normal USB serial returned | PASS, idle only |
| Reconnect after termination | New session reached ready and answered PING; unarmed MOVE rejected; actual pointer unchanged; final STOP restored USB | PASS |

No purchases, attacks, upgrades, healing, item use, claims, or messages were intentionally triggered. Normal game timers continued. An incomplete CLICK command was rejected before a valid click was sent; no unintended game action was observed.

## Pointer benchmark

The game window measured 788 × 1083 logical points on an 1800 × 1169 display with 2× Retina screenshots. Targets covered dispersed positions across the window. Each trial measured the pointer, issued bounded relative MOVE corrections and stopped within four points. This is positioning qualification, not twenty semantic click targets.

| Metric | Measured result |
| --- | --- |
| Targets passing | 20/20 |
| Largest final error | 3.991 logical points |
| Mean final error | 3.589 logical points |
| Mean positioning time | 3.350 seconds |
| Positioning time range | 1.093–4.009 seconds |
| Mean MOVE commands per target | 6.65 |
| MOVE command range | 2–8 |

Elapsed time includes observation, shell/tool orchestration and correction. It is not a measurement of Bluetooth or HID latency. The correction gain was a practical fixed choice, not a calibrated model. Small residual errors are intentionally accepted once the four-point threshold is reached. These results apply to this setup and do not establish a population success rate or accuracy on other displays.

Full-screen changed the main window geometry to 1800 × 1130 logical points with portrait content centered between sidebars. Re-reading geometry and choosing targets from the current screen worked. Reusing old window offsets would be wrong.

## Limits and next priorities

1. Package the observed launch → present window → harmless focus click → verify focus → position → action → verify screen loop into the application. The tested sequence is still assistant-orchestrated, not a built-in one-button startup feature.
2. Reduce correction time through measured small/large movement calibration; measure acknowledgement and action timing separately before tuning.
3. Add single-controller ownership, bounded discovery and clear disconnected/ready/armed indicators. The missing GUI does not mean a CLI controller is absent; consult actual session state.
4. Qualify physical BACK, held-button abrupt disconnect, USB removal, sleep/wake, GUI delayed-command cancellation, window resizing/movement, other Spaces/displays and prolonged use. SIGTERM at idle does not prove release during an interrupted drag, Bluetooth-radio loss or power loss.
5. Keep navigation supervised and verify each resulting screen. Earlier castle/world and panel drag tests remain valid; wheel commands still have no qualified useful Kingshot scrolling response.

No source or installed binary was changed in this round. Private raw observations remain local. Public documentation excludes device identity, installation paths, game account screenshots, chat and exact target coordinates.
