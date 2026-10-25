# Version 0.4.4: invocation and terminal-hangup qualification

Verified 2026-10-25, Africa/Cairo. Mac **0.4.4 build 9**, companion **AI HID CTRL 0.5**. Lead-performed implementation and review, without independent reviewers. All mouse actions in this round used Bluetooth commands to the Flipper and actual USB HID, observed by a separate native macOS event fixture. Native UI control was used only to operate the dashboard and test setup. No Kingshot input was sent.

## Findings and repair

Version 0.4.3 tested command-line flags independently. Combining `--cli` with `--dashboard-preview` could skip the sole-controller lock while entering live CLI initialization. The reproduction held the real lock, selected an absent test device and requested no ARM or HID input: ordinary CLI refused ownership, whereas the mixed invocation initialized Bluetooth. This was a startup isolation defect, not evidence of concurrent mouse actions.

Version 0.4.4 parses one exclusive launch mode before AppKit, Bluetooth or ownership initialization. Conflicting, unknown, missing or extra arguments exit 64 with usage. Live GUI and CLI require sole ownership; preview cannot enter CLI. Read-only help, version, self-test and render remain available without controller ownership. CLI device names are trimmed; the default remains `Flipper` when omitted. Render requires an absolute output path.

The first candidate passed ordinary hardware tests but exited by the default signal action on terminal hangup (SIGHUP). That discovery used mouse-disabled state, with no held button. The final build routes SIGHUP through the existing graceful Stop path alongside SIGINT and SIGTERM. Core hardware qualification was repeated on this final executable. No companion code changed.

## Final build results

| Coverage | Observed result |
|---|---|
| Real executable invocation regression | 16 invalid forms rejected; 3 live modes refused under another owner; 4 read-only modes succeeded; PNG render and write-failure behavior passed. Tested temporary and installed executable. |
| Positioning | 60/60 targets, corners and fine corrections; mean 1.445 s, maximum 2.007 s; mean error 3.197 and maximum 3.97 logical points. |
| Ordinary HID commands | 60 commands: left single/double, right, middle, both wheel directions and four drag directions. Independently observed balanced button events, wheel events and 240 drag events; final buttons 0. |
| Guards and recovery | Pre-ARM, second-owner, invalid/outside-target and 12 concurrent target requests refused; five reconnects required fresh ARM; five separate process starts passed. |
| Held-drag disconnect | Confirmed native button-down during a 2500 ms drag; DISCONNECT released it. |
| Signal shutdown | Separate confirmed held-drag tests for SIGINT, SIGTERM and SIGHUP all exited 0 and released buttons. Four held interruptions including DISCONNECT on the final build. |
| Other live invocation cases | STOP, lowercase quit and whitespace release; immediate startup EOF in three CLI forms; absent-device timeout then same-process recovery; missing/dead target and nonexistent application refusal; repeated Connect/ARM; overlapping Disconnect callbacks; discovery cancellation and case-insensitive reconnect. Six hardware clicks across these sessions. |
| Focus and app preparation | APPLICATION/PREPARE selected and focused an app; target focus loss refused POINT with no HID; explicit preparation recovered. Repeated with all three signal tests. |
| Installed dashboard | Owner refreshed the existing Bluetooth grant; authorization 3. Exact test PID selected; automatic focus/position/click, pointer-coordinate copy, wheel and drag completed. Native capture showed two balanced left pairs, one wheel event and 12 drag events. |
| Quit and reopen | Cmd-Q terminated the idle armed dashboard; unchanged installed app reopened OFFLINE; reconnect was SAFE with mouse disabled; Stop returned OFFLINE and ordinary USB serial was restored. Cmd-W had no effect and is not counted as a window-close pass. |
| Integrity | Installed executable hash and strict code-signature verification passed; fresh companion readback matched. Fixture quit normally, final host buttons 0. |

The GUI wheel test records native event direction; HID command sign need not equal the native sign under the host's current scrolling behavior. No scrolling preference was changed. These measurements are not a controlled speed comparison with prior versions.

## Exact artifacts and rollback

Installed Mac executable SHA256:
`91ced316784478dc201e60f27b7971d9f76253ae7d9ec8393f699d43256b0e58`

Unchanged installed Flipper companion SHA256:
`7c6e5f02038f980d65f3d5d399be92dbf8ea938e033dd720bc74ac9f8756a907`

The preceding 0.4.3 Mac bundle and previous companion backups are preserved privately for rollback. Replacing the Mac executable may require refreshing its existing Bluetooth grant; keep the qualified build unchanged between useful revisions. App signing remains ad-hoc, distinct from signed Git commits.

Private evidence includes the final stress report, live invocation report, three signal reports, installed GUI report, final event capture and fresh companion readback. Earlier lock-bypass proof and rejected candidate hangup results remain preserved. Raw device/session logs are excluded from this public repository.

## Repeatable startup regression

Stop all live controller processes first, then run:

```sh
python3 tests/test_invocation.py /absolute/path/to/mouse-bridge
```

This test holds the actual ownership lock and requests only invalid, read-only or owner-rejected startup modes. A passing test requests no Bluetooth connection or HID input. It is intentionally separate from the build script so an already-open controller does not make builds fail.

## Limits and next useful work

This is bounded supervised qualification, not all-condition assurance. Physical BACK during a held action, unexpected USB/Bluetooth loss, SIGKILL, sleep/wake, Spaces and multiple displays remain unqualified. Release grace is best effort, without a host release acknowledgement. The new build has not been exercised in Kingshot in this development round; exact client qualification belongs in its gameplay chat.

For gameplay, retain native Apple/CUA first and use the bridge for a demonstrated failing function. Use one controller, an explicit live target, fresh ARM and a harmless guarded position check before client actions. Next worthwhile testing is supervised physical fault recovery, followed by client-specific use. No background monitor or automatic game resume was installed.
