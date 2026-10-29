# Agent playtest 2 — six-stage tutorial, blind run

Date: 2026-10-29. Build: working tree at the time of the test, release UI, Godot 4.7.2.
Tester: Claude (agent), playing blind as a first-time player. Screenshots: `docs/playtests/2026-10-agent-2/`.

## 1. Verdict

I finished all six stages and reached the end card ("The tutorial is complete."). The core idea is good. Copying ground across a mirror to make a bridge, and lowering the mirror to get real ground back, gave me two real "oh" moments (stages 2 and 3). The look is calm and clean, and the in-game hints arrive at the right time.

It is not yet clear enough. Most of my failures came from not being able to read the isometric view: is that block next to me, one tile further away, or one level higher? The game gave me no reliable way to check before I clicked. Stage 6 has a real bug: the traveller can land half on a ledge and then cannot walk at all. Only Undo gets you out. I would continue playing if the adjacency reading and the stage 6 bug were fixed. In the current state, stage 6 would make many players quit.

## 2. Stage by stage

Times come from the game clock under a slow software renderer. They include waits for screenshots, so treat them as rough.

| Stage (as shown) | Time | Actions | Failures / Undo | Result |
|---|---|---|---|---|
| 1 Walk + turn view | ~0.5 min | 3 | 0 | Easy |
| 2 Drag mirror (bridge) | ~1.5 min | 7 | 1 Undo | Good puzzle |
| 3 Lower mirror (reveal) | ~1.5 min | 6 | 1 dead click | Good puzzle |
| 4 "Only the ground" | ~3.5 min | 11 | 2 failed walks, 4 camera turns | Confusing |
| 5 Turn with arrow | ~2 min | 6 | 2 failed walks | Confusing |
| 6 Fall + combine | ~8 min | ~25 | 2 softlocks, 6 Undo, 1 refused fall | Bug, frustrating |

**Stage 1.** "Tap a block to walk there." I clicked the green block. A new hint said the way on was out of sight and to turn the view. The corner arrow turned the camera, the goal ring appeared, and I walked there. This is clear. Hovering a tile shows a faint path line and a small ring on the target. Good, but subtle.

**Stage 2.** The mirror button raised a glass frame at the traveller, and the camera zoomed in. "Drag the mirror along the path. It copies what is behind it to the other side." Dragging it showed the copy live, which felt good. My first full drag bridged to the goal block but left a gap behind me. I used Undo, walked to the middle block first, then dragged again. This was the best moment of the tutorial: a small plan in two steps.

**Stage 3.** Raising the mirror turned the far row into dashed ghosts, and the hint said lowering the mirror brings back the ground it covered. I dragged the mirror so the copy reached into the ghost row, walked out, and pressed M. The real row came back under me. Clear and satisfying. One problem: I clicked a reflected tile and nothing happened, with no feedback. A second click slightly elsewhere worked. Reflected tiles inside the mirror's screen area are hard to click, because the mirror takes the click.

**Stage 4 ("Only the ground").** The copy included a slice of a tall pillar, which floated beside the goal. My walk failed, and then a hint appeared: drag the mirror straight down to lower the frame. That worked, but the goal still looked adjacent to the end of the copied floor (screenshot 04), and clicks on it did nothing. I turned the camera four times and could not tell whether the goal was higher, further away, or blocked. In the end I dragged the mirror one more step, and the copy then ran under the goal. I solved it by trial, not by understanding. A goal that looks adjacent but is not is the main clarity problem.

**Stage 5.** "Drag the mirror's arrow to turn it." Turning works well: four snap dots appear during the drag (screenshot 05). After the turn, the copy stopped half a tile short of the goal. I moved the mirror forward and then left a gap behind me instead (screenshot 06). I moved it back by half a tile and it lined up. The mirror can sit on half tiles, so the copy can be off by one, and nothing tells you which way to move it.

**Stage 6.** Hint: "A fall is safe when there is ground below. Only the edge of the world is not." I turned the mirror toward the lower row and lowered the frame to drop a copied block (stage 4 skill). I walked to the end of the copy and lowered the mirror. The traveller fell and landed, but it hung beside the first lower tile, half off its edge (screenshot 08). Every click then did nothing: no path, no hover ring, no message. The stage reported normal play. I reproduced this twice. Undo recovered it. Lowering from the second-last tile was refused, with a clear ghost and message (screenshot 07). That part is good. What finally worked: I moved the mirror half a tile further, walked to the new end tile, and dropped. It landed cleanly and I walked to the goal. Without Undo, and without reading the code to understand the cause, I would likely have given up.

## 3. Controls and feedback

- **Mirror button.** Clear. The tooltip "Raise the mirror (M)" helps. The icon (a dashed rectangle) does not say "mirror" by itself.
- **Dragging the mirror.** It feels good, and the live preview is excellent. You grab inside the frame. The frame turns cyan when grabbable. Snaps are half a tile, which is hard to read. A drag sometimes moved one step when I meant two.
- **Lowering the frame (drag down).** I only found this through the hint after a failure. The frame height change is subtle. A half-lowered frame showed a cut, greyed copy of the block, and I could not read what that meant.
- **The arrow.** The round badge on the frame corner. Turning works, and the snap dots are good. The badge also covers tiles behind it and blocks clicks on them.
- **Walking.** It is free-position, not tile-centred: the traveller walks to the exact point clicked. This is the root of the stage 6 perch, because where you click on a tile changes where you land after a fall. Clicking an unreachable tile does nothing silently.
- **Hover cues.** The ring on the target appears only when the tile is reachable. This is the most useful cue in the game, but it is small and I learned it late. Unreachable tiles show nothing, so I could not tell "unreachable" from "missed the tile".
- **Camera.** The corner arrows, Q/E, and a sideways drag (touch too) all work. The camera did not reset on "Play again", so stage 1's "turn the view" lesson was skipped.
- **Undo.** The button and Ctrl+Z both work, and steps are fine-grained (walks, drags, raise/lower). It saved stage 6. It has no visible tooltip.
- **Settings (gear).** Music, Effects, Fullscreen, Restart stage, Return to title. Clean, but there is no list of controls. "?" only repeats the current hint.
- **Keyboard.** M raises and lowers, Q/E turn, Ctrl+Z undoes. I found no key to move or turn the mirror. Arrow keys and Tab only move UI focus. For Steam, mouse is required.
- **Phone, landscape 844x390.** Usable. Tap and drag on the mirror worked. The hint box sits close to the raised frame.
- **Phone, portrait 390x844.** The stage is drawn small, with tiles about 25 px wide in the middle third of the screen and large empty bands above and below (screenshot 09). Two taps on the green block failed because it sat behind the arrow badge and frame. Taps on clear tiles worked. The buttons are reachable at the bottom.

## 4. What to improve (ranked by impact)

1. **Fix the ledge perch after a fall.** If the landing is not walkable, the fall predictor should either refuse the fall or slide the traveller to a walkable spot. Today it treats a landing on the tile edge as safe (stage 6).
2. **Make adjacency and height readable.** On hover, outline the tile under the pointer, and show an "X / can't reach" mark on unreachable tiles. Mark the gap or step that breaks the path. Stage 4 and stage 5 failures were all "looks connected, isn't".
3. **Show feedback on a failed walk click.** A brief shake or a red ring, plus a short reason if possible ("gap", "too high", "blocked").
4. **Show the mirror's step on the ground.** Draw the mirror's footprint line on the tiles while dragging, so half-tile positions and the copy's start and end are visible. Consider whole-tile snaps in the tutorial.
5. **Let clicks pass through the frame and badge to tiles.** Give tiles priority unless the press starts a drag, or shrink the frame's hit area to its edges and the badge.
6. **Teach lowering the frame before it is needed.** Stage 4 shows the hint only after a failed walk. Show it up front, and make frame height visible (for example, a level tick on the frame).
7. **Full keyboard control of the mirror for Steam.** For example, arrows to move, Q/E or R to turn, PageUp/PageDown for height. Add a controls list in Settings.
8. **Portrait framing.** Zoom the stage to fill the width in portrait. Keep 44 pt touch targets around tiles near the frame.
9. **Reset the camera on "Play again"**, so stage 1 teaches the view turn again.

## 5. Keep these

- The live preview of the copy while dragging.
- Raising the mirror ghosts the covered ground; lowering it brings the ground back. This is clear and surprising.
- The refused-fall ghost and message ("The traveller would fall off the world, so the mirror goes back.").
- Hints that appear after a specific failure (stage 4).
- Fine-grained Undo with Ctrl+Z.
- The snap dots while turning the arrow.
- The dashed outline of the lowered mirror's last position.
- The calm visual style and the short stage-title cards.

## 6. Method and limits

- Environment: Linux, Xvfb, software Vulkan with the Mobile renderer, window 1152x800, fresh save, release UI. Input came from a driver script (mouse, touch, key events). Rendering was slow, so animations were judged from stills, not motion. No audio device, so sound was not assessed.
- What I read: `AGENTS.md`, plus my own driver folder. I did not open `tests/`, `levels/`, `docs/` (other than writing this file), `art_trial/`, the design or handoff docs, READMEs, the old playtest folder, or git history.
- Code peeked at, and why: after reproducing the stage 6 softlock twice, I read `world/fall_predictor.gd`, `world/walker.gd`, `core/walk_graph.gd` and the `walkable` / `clear_segment` / `embedded` helpers in `core/world_geometry.gd`. This was only to diagnose that bug. Finding: the walker is a physics capsule, and a fall counts as a safe landing when `is_on_floor()` is true. Walking, however, needs the capsule's whole footprint on the floor (`walkable`). A capsule resting on a tile edge is therefore "landed" but has no route, because `clear_segment` from its position fails. This reading told me the landing depended on position, and I then tried moving the mirror half a tile. Without that knowledge, my stage 6 notes would have been harder.
- Coverage: desktop mouse throughout, landscape and portrait touch on stage 2, the settings panel and "?" on stage 1. No physical devices. I did not export a build or run any automated tests.
- I did not modify any tracked file. The only files I added are this report and the screenshot folder.
