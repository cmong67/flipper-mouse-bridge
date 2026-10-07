# Kingshot mouse and scrolling qualification — 7 October 2026

## Assessment

**Verified for supervised navigation:** Flipper-delivered left clicks and sustained left-button drags work in the native Kingshot castle and world maps, with useful coverage of scrollable menus. No user pointer placement was needed during this run. **Vertical wheel commands were acknowledged but produced no visible scrolling or zooming in the tested Kingshot surfaces.** Use held left-button dragging for navigation.

This is a broad navigation qualification, not a test of every building, button, game action, or macOS display mode. It supports assistant-assisted gameplay navigation with observation after each action. It does not establish unattended operation or a general fix for every macOS mouse problem.

## Setup and method

The installed hardware-tested build was used on the development MacBook Pro, with official Flipper firmware 1.4.3/API 87.1. Bluetooth RPC carries commands to the Flipper; its USB HID interface carries mouse reports back to the same Mac. USB remains required. This is not Bluetooth HID mouse emulation.

The controller ran in CLI mode. PING/PONG and ARM/ARMED established readiness. A read-only pointer observer supplied logical screen coordinates. Bounded relative MOVE corrections placed the pointer at each target before a hardware click or drag. Native app inspection supplied screenshots after each action; game input itself came through the Flipper. Retina screenshots were converted to logical window/screen coordinates. The screenshot's rendered cursor was not relied on as a live pointer reading.

An old GUI controller and an initial CLI session coexisted at setup. They were stopped and a single fresh CLI session used for qualification. This is an operational observation, not proof that the GUI caused a fault. The absence of a GUI window does not imply the CLI bridge is stopped.

## Results

| Surface / input | Observed result | Status |
| --- | --- | --- |
| Focus and pointer entry | Pointer moved from outside into the already-running game; ground click established focus without user placement | PASS |
| Castle map: up/down/left/right | Scene visibly panned in all four directions | PASS |
| Castle map: diagonal | Scene visibly moved diagonally | PASS |
| Castle map: wheel | An isolated negative wheel command caused no visible pan/zoom; positive wheel was combined with a following drag and is not independently qualified | No useful wheel response observed |
| Infirmary | Selection, Details overview and More Details table opened; both overlays closed back to castle | PASS |
| Infirmary detail table | Held-button drags revealed earlier and later level rows | PASS, both directions |
| Infirmary detail table: wheel | Isolated positive and negative wheel commands caused no visible row change | No visible response |
| Heroes | Grid opened; vertical drag revealed the final hero row | PASS |
| Hero details | Stats, Skills and Gear tabs opened; back navigation returned to castle | PASS |
| Heroes: wheel | Negative wheel caused no visible grid change | No visible response |
| Backpack | Resources, Speedups, Bonuses, Gear and Other categories opened | PASS |
| Backpack grid | Vertical drag revealed later stone/iron rows | PASS |
| Alliance | Overview and Members opened; member rank expanded to show cards | PASS |
| Alliance member list | Vertical drag revealed later members; back navigation returned to castle | PASS |
| Castle → world | World control opened the world map | PASS |
| World map: up/down/left/right | Scene panned in each direction; opposing drags returned to the preceding location | PASS |
| World map: diagonal | Scene visibly moved down and right | PASS |
| World map: wheel | Isolated positive and negative wheel commands caused no visible pan/zoom | No visible response |
| World ground: left click | Plains information opened with ground-action controls; clicking outside dismissed it | PASS |
| World ground: right/middle click | Commands acknowledged; no visible game response | Game behavior unqualified |
| World ground: double-click | Command acknowledged; no lasting panel or zoom effect | Distinct double-click gesture unqualified |
| World → castle | Town control returned to castle | PASS |
| Events | Panel opened; horizontal tab strip dragged left and right | PASS |
| Event task list | Vertical drag revealed later task cards | PASS |
| Governor profile | Avatar click opened profile; back returned to castle | PASS |
| Conquest | Panel opened and closed; no Conquer or Claim action taken | PASS for navigation only |
| Shutdown | STOP disconnected; normal USB serial reappeared; no bridge process remained | PASS |

Representative commands included `DRAG 250 0 1000` and its reverse for world panning, `DRAG 0 -500 1500` for lists, and opposing `DRAG ±300 0 1200` for event tabs. These are relative HID counts, not screen pixels; exact displacement varies with macOS acceleration and game handling. The detail-table wheel checks included isolated `SCROLL 8` and `SCROLL -12`; the world checks used isolated `SCROLL 12` and `SCROLL -12`.

No attacks, purchases, upgrades, healing, item use, task acceptance, reward claims, or messages were intentionally triggered. The game continues its normal background timers. The final observed view was the castle; the bridge was then stopped.

## Interpretation of the mouse problem

The earlier failed interaction and this working bridge do not establish a single macOS root cause. What is verified is that a real held-button sequence delivered by USB HID is accepted by native Kingshot. The new run extends that evidence from a pair of city pans to both maps and multiple scrollable panels.

Wheel delivery and application response must be separated. The earlier browser fixture received wheel events from this bridge. In this run the device acknowledged wheel commands, while the selected game views did not visibly react. Acknowledgement alone is not proof that the game scrolled. The practical working interaction is a click for selection and a sustained left-button drag for touch-style scrolling/panning. No native horizontal wheel support was added; horizontal event navigation used dragging.

## Remaining qualification and optimization

1. **Reusable navigation controller:** package the observed loop—present the window, measure pointer position, correct with bounded moves, click/drag, inspect the resulting screen—into a clear start/readiness workflow. This run was assistant-orchestrated, not a standalone one-button application.
2. **Position accuracy:** benchmark twenty harmless targets across the window, record final error and retries, then calibrate small/large motions. Position correction worked across many targets here, but no aggregate accuracy, success percentage or latency benchmark was measured.
3. **Connection ownership:** allow only one controller session, expose disconnected/connecting/ready/armed states, and require fresh arming after reconnection. Never replay stale mouse actions.
4. **Recovery:** live-test physical BACK, GUI delayed-command cancellation, Bluetooth loss, USB removal, sleep/wake and abrupt termination. The earlier STOP-during-drag browser test passed; these other fault cases remain unqualified.
5. **Display and launch coverage:** test cold launch, true macOS full-screen/Spaces, window movement/resizing and multiple displays. This run used an already-running windowed game.
6. **Screen-specific recipes:** retain left-button dragging for Kingshot lists/maps, verify the new state after every step, and separate navigation qualification from any consequential game-action qualification.

Not attempted: every building/submenu, Shop/Deals/purchase paths, battle execution, resource use, messaging, long unattended operation, trackpad gestures, zoom by pinch, or keyboard functionality. Broader gameplay is not automatically qualified by successful navigation.

Public documentation excludes game account screenshots, chat, player/member identity, map coordinates, device identity and private installation paths. Source code and the installed binary were not changed during this qualification.
