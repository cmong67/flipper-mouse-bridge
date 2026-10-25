# Repeat qualification — Mac0.4.3 / AI HID CTRL0.5

Completed 2026-10-25T18:36:22+03:00 (Africa/Cairo). User requested another exhaustive test. This was a broad bounded regression on the unchanged installed pair, performed by the lead using an isolated native mouse fixture; it does not establish all possible operating conditions. No Kingshot actions, production code changes, reinstall or permission changes were required.

## Results

| Coverage | Result |
|---|---|
| Positioning | 120/120 targets over10 cycles; mean1.428s, maximum2.410s; mean error3.16, maximum4.00 logical screen points |
| Ordinary mouse actions | 120/120: left single/double, right/middle clicks, small/large wheel values in both directions, four drag directions |
| Independent native events for ordinary actions | 70 balanced left pairs,10 right pairs,10 middle pairs;20 wheel events per direction,480 drag events and10 second-click events; buttons0 |
| Reconnects | 10/10 returned SAFE; pre-ARM click refused each time, PING and rearmed positioning passed |
| Process starts | 10 independent CLI starts and normal stops passed |
| Guard rejection | Second controller, pre-ARM input,10 invalid/outside-edge requests and12 concurrent target actions refused without unintended mouse input |
| Added malformed input | 11 more cases, including NaN/infinity coordinates, trailing data, unsupported buttons/counts and out-of-range movement/scroll/duration, rejected without HID dispatch |
| Boundary actions | Nine commands passed: right/middle double-click, zero/±127 wheel values, diagonal drags at100ms and3000ms; expected button/wheel events independently observed |
| Varied held-drag Stop | 10/10 confirmed-held3000ms horizontal/vertical/diagonal drags stopped after0,150,500,1000 or2000ms; buttons released, down/up balanced, every reconnect click passed; disconnect completion0.372–0.398s |
| Other interrupted actions | Main-regression held-drag disconnect, closing command input during held drag, and SIGINT during independently confirmed held drag all released buttons; EOF/SIGINT exited0 |
| Focus and launch | Prepare launched the selected system application; changing target back without focus caused POINT refusal, no HID/event change; Prepare recovered |
| Coordinate feed | While SAFE, acknowledged coordinate updates increased0→5 during a two-second idle sample; this is command/acknowledgement evidence, not direct LCD observation |
| Installed dashboard | Existing Bluetooth authorization3; click, both scroll directions and drag returned DONE with independent event evidence; normal Stop returned OFFLINE |
| Closeout | Fixture quit normally; buttons0; ordinary USB restored; unchanged Mac executable and strict signature reverified; companion readback hash matched |

The boundary action capture contained two right pairs, two middle pairs, four left pairs and one wheel event per direction. The dashboard capture contained two left pairs (click and drag),12 drag events and one wheel event per direction.

## Test correction and interpretation

The first dashboard assertion incorrectly expected the HID wheel command sign to equal the native scroll-event sign. The observed sign was reversed. The check was corrected and both signs were explicitly exercised; opposite native event directions were confirmed without changing system settings. This was a test expectation error, not evidence of an application failure. The native fixture records wheel deltas rather than actual content travel in a client app.

Positioning timing varies by pointer starting position and run conditions; this is not a controlled speed comparison with earlier qualification. Event capture independently checks delivered input, while CLI/GUI DONE alone would only establish command completion. All thirteen held-action interruptions in this round released buttons under the tested conditions: one main disconnect, ten varied disconnects, EOF and SIGINT.

## Artifact identity and evidence

Mac0.4.3 build8 executable SHA256 `ff5798e588763801da7b68475cc08de97afd4297490ddb125889ca75e4dfd9c2`; AI HID CTRL0.5 installed readback SHA256 `7c6e5f02038f980d65f3d5d399be92dbf8ea938e033dd720bc74ac9f8756a907`. No binary changed during this round. The private development vault retains the dated journal, harnesses, native events, exact device/process identities and machine-readable results; these private logs are excluded from public Git.

See [repair and previous qualification](Stop-Release-v043.md) for architecture, earlier failed candidates and rollback. Existing rollback copies remain unchanged. No new firmware or signing identity was installed.

## Remaining limits and next useful tests

This establishes a successful repeat on the current single-display local test surface. Kingshot content scrolling and interaction remain a separate client qualification. Physical BACK while held, abrupt Bluetooth/cable/power loss, SIGKILL, sleep/wake, Spaces and multiple displays remain unqualified. The350ms Stop grace is best effort, not host acknowledgement. A physically supervised fault round is the next useful reliability expansion; ordinary input does not need another rebuild based on these results. Native Apple/CUA remains first choice, with hardware reserved for a specific observed native failure.
