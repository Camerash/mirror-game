# Agent playtest: the six-stage tutorial, direct controls

Date: 2026-10-29. Branch `claude/funny-dirac-7dv0hf`. Played by an agent acting as a first-time player, from the title to the end card, with the default direct mirror controls and the release UI (`-- --release-ui`). Linux, Xvfb, Mesa lavapipe, Mobile renderer, 1152x800. Screenshots are in [`2026-10-agent/`](2026-10-agent/).

## 1. Verdict

Partly fun. The idea is good. Dragging a mirror and watching the world rebuild itself live is the best part of the game. Two moments landed as real "aha" moments: lowering the mirror to bring back the hidden ground (stage 3), and falling from a copied ledge onto the low path (stage 6).

Most of my time did not go into the puzzle ideas. It went into three other things:

- Reading the space. I often could not tell whether a copy was beside a path, above it, or touching it.
- Hitting exact half-unit positions with the mouse.
- Recovering from outcomes I could not predict. Two of these were deaths, and one was a goal that did not count.

Stages 4 and 5 felt like following instructions or fiddling, not like solving. The prompts give away stage 4. Stage 5 depends on a half-unit position that I could only find by trial.

The biggest single problem is a bug. Standing on the goal block does not always finish the stage (see 4.1). It happened to me twice without my trying.

## 2. Stage by stage

Times are game-clock seconds from the driver's log. My own thinking time between batches was much longer, so read them only as a rough guide to how much effort each stage took compared with the others.

### Stage 1, First steps (about 55 s, 4 actions)

- **What I thought the goal was:** walk somewhere. Then the prompt said the way on was out of sight.
- **What I tried:** I clicked a block and the traveller walked there. I tried a mouse swipe on empty space and nothing happened. Then I clicked the right curved arrow, the view turned, the ring appeared, and I walked to it.
- **Confusion:** on desktop the prompt says "Swipe sideways, or use the arrows". A mouse swipe does nothing, because swipes work for touch only (`world_gesture.gd` needs `pointer >= 0`). A touch swipe does work (checked later).
- **Confusion:** the curved arrows ↶ ↷ in the bottom left look exactly like Undo and Redo. I only knew they turn the camera because the prompt said "arrows".
- **Note:** the mirror button is already showing in stage 1, before the game has taught it.

### Stage 2, A place to stand (about 110 s, 7 actions)

- **Goal:** cross gaps from the start blocks to a jade block, then to the goal.
- **What I tried:** I raised the mirror. It ate the two blocks in front of me, which surprised me. I dragged it along the path, and the preview while dragging was clear and good (screenshot 02). On release it had gone two steps further than I meant. I dragged back, walked to the jade block, slid the mirror on, and walked to the ring.
- **Bug:** the traveller stood on the goal block and nothing happened for 20 seconds. A second tap on the block finished the stage. See 4.1.
- **Aha:** a mild one. "The copy is a bridge" reads well.

### Stage 3, The path beneath (about 150 s, about 10 actions, 1 death)

- **Prompt confusion:** the only prompt says "Tap the mirror button **again** to lower the mirror". It shows before the mirror has been raised on this stage, and the **?** button replays the same text.
- **What I tried:** I raised the mirror. The whole far platform vanished, because the destination column replaced it. I slid the mirror, walked to what looked like the end of the bridge, and lowered it. **I fell into the void.** The bridge ended one tile short of where the hidden platform would return, and nothing on screen showed where that platform had been.
- **Failure state:** the traveller hung frozen below the stage. There was no message or other cue (screenshot 03). The mirror button went dim. Only Undo was usable. Undo worked.
- **Second try:** a half-step slide made the bridge longer. I walked to its end and lowered the mirror. The ground came back under me and I walked to the goal.
- **Aha:** yes. "Lowering gives the ground back" is a nice idea. It would be fairer if the hidden original showed faintly while the mirror is up.

### Stage 4, Only the ground (about 90 s, 7 actions, 2 missed grabs)

- **Prompt:** "Drag it straight down to lower the frame." That is the solution, given before I had seen the problem.
- **What I tried:** I raised the mirror. The copy included a floating copy of the tower's lower half (screenshot 04). Two drags on the mirror did nothing at all. One press was just outside the glass. The other landed where the ledge passes through the frame, so the press hit the ledge. There was no hover or grab cue to tell me why. A drag straight down worked. I then slid the mirror toward the goal and walked over.
- **Aha:** none, because the prompt solved it. I never saw the tower copy block me, so the lesson "the frame decides what is copied" never felt earned.
- **Untested:** whether the tower copy really blocks the bridge. I followed the prompt before trying.

### Stage 5, Another way round (about 300 s, more than 20 actions; this is where I got stuck)

- **Goal:** reach a jade ring that sits off the end of a four-tile row.
- **What I tried:** I raised the mirror and dragged the arrow toward the goal. The copy appeared to extend the row toward the ring. I slid the mirror one unit, and that opened a gap next to me. Taps on the copy and on the goal did nothing, with no "can't go there" feedback. I turned the view three times and still could not tell whether the copy was beside the row, above it, or in line with it. Isometric views make a sideways offset and a height offset look the same.
- **How I got out:** I undid everything and surveyed all four views. I raised the mirror, pointed it at the ring, then previewed half-step and one-step slides without releasing (screenshot 05). Only the half-step position connects. One half-unit is about 30 px of mouse travel at 1152x800.
- **Bug again:** I reached the goal block and the stage did not complete (4.1). I tapped the ring centre and it did.
- **Aha:** weak. What I learned was "the mirror turns", but the solving was trial and error at half-unit precision.
- **Peek disclosure:** I already knew from `tests/tutorial_playthrough.gd` (see section 5) that this stage needs a 0.5 slide. That steered me to try half steps. A true first-time player would likely take longer, or quit.

### Stage 6, Together (about 260 s, about 18 actions, 1 death)

- **Prompt:** "A fall is safe when there is ground below. Only the edge of the world is not." That is a good hint that does not give the answer away.
- **What I tried:** I surveyed the views. I raised the mirror and pointed it along the row; the copy extended out over the air. I misread the low path's position and pointed the arrow the other way instead. The preview showed the fall ghost (screenshot 06), but releasing applied it anyway and I died. The mirror turns about its pivot, so my own row was now in the destination column. Undo twice. A sideways preview also showed a fall, so I dragged back to cancel it.
- **What worked:** point along the row, slide half a step, drag down one unit to drop the tower copy, walk to the end, lower the mirror, and land on the low path.
- **Aha:** yes, the landing felt good. The low path got a glowing edge once the copy was over it, which helped.
- **End card:** "The tutorial is complete." with Play again and Title. It is abrupt but fine. Play again resets the view.

## 3. Controls and feedback

- **Mirror button and M:** easy to find and reliable. Raising a mirror deletes geometry right away (the destination column), which surprises you every time. Lowering has no preview at all. A drag shows a fall ghost before release, but the button does not, and the button is the action that killed me in stage 3.
- **Dragging the mirror:** the live preview is excellent. Locking the drag to one axis felt natural. The camera staying still while I dragged really helped me compare positions.
  - The hit area is unclear. Presses on blocks that pass through the frame, or just outside the glass, silently do nothing.
  - Steps are too fine: a half unit is about 30 px on desktop and about 12 px in phone portrait. I overshot twice.
  - In stage 1 the mirror can stand edge-on to the camera, inside a wall.
- **Arrow:** the knob is easy to grab. "The copy goes where the arrow points" reads well. But turning about the pivot can put the ground you stand on into the destination column, and release applies even a predicted death.
- **Undo (button and Z):** reliable, and it always got me out. The button appears only after the first action. Esc cancels a drag in progress, which is nice but untaught.
- **No reset:** the release UI has none, so after several steps the only way back is to press Undo many times.
- **Camera:** Q and E and the arrows work, and the 0.4 s blend is fine. A touch swipe works. A mouse swipe does not, although the prompt suggests it does.
- **Walking:** tap to walk works, through the glass too. A tap on an unreachable spot does nothing, with no feedback. A tap on the goal block may leave you off the goal's centre (4.1).
- **Copies, originals and absolutes:**
  - Jade absolutes read clearly.
  - Copies are pale, almost white, with translucent sides. They read as "copy", but not clearly as "solid and walkable", and their edges merge with the originals.
  - I could not judge distance or height between separate structures (stages 5 and 6). Copies cast no shadow and have no contact cue on the ground below.
  - The glowing edge on the target ground in stages 4 and 6 was useful, but I could not tell what it meant.
- **Failure:** the traveller freezes in the void with no message or other cue.

## 4. What to improve, ranked by impact

### 4.1 Bug: standing on the goal block does not always finish the stage

The completion check is `walker.position.distance_to(goal) < 0.22` in `game.gd`. The walk goes to the exact tapped point, not the tile centre. A tap on the goal block slightly off its centre, including on the ring's rim, leaves the traveller on the goal tile but outside 0.22. Nothing happens. I hit this by accident in stages 2 and 5. Screenshot 07 shows it.

Repro:

1. Start a new game.
2. In First steps, walk to the end of the path and turn the view once (right arrow).
3. Click the goal tile about 25 px right of the ring's centre (I used (575, 368) at 1152x800).
4. The traveller stands on the jade tile beside the ring. The stage never completes. Tapping the ring's centre completes it.

Fix ideas: snap a walk that ends on the goal's tile to the goal point, or test for "standing on the goal tile" or "inside the ring" instead of 0.22.

### 4.2 Show what the mirror hides, and preview the mirror button

While a mirror is up, show the replaced originals as a faint outline. Give the lower action the same fall ghost that a drag gets: on hover on desktop, or on a press-and-hold of the button. Stage 3's death came only from not knowing where the hidden ground would return.

### 4.3 Make positions easier to read

Add drop shadows or contact marks under copies, or a faint ground grid. On desktop, highlight the reachable path on hover, or flash a short "can't reach" cue on a failed tap. Most of my stage 5 time went here.

### 4.4 Make half-unit precision forgiving

Use more pointer travel per step. Or let the mirror settle into the nearest position that connects to something. Or add keyboard nudges for a selected mirror; the arrow keys are ignored in direct mode today. This matters more on phones.

### 4.5 Don't apply lethal changes from the arrow

When a turn or slide is predicted to drop the traveller off the world, keep the preview on release and ask for a second release or a tap to apply it, or bounce it back as a blocked change already does. Or choose the turn pivot so the traveller stays on the source side. "Point first, then slide" is the natural order, and stage 6 punishes it.

### 4.6 A clear failure state

Say or show "fell". Pulse Undo. Or rewind automatically after a second. Today the traveller hangs in the void.

### 4.7 Fix the prompts

- Stage 1 on desktop: "use the arrows or Q/E".
- Stage 3: don't say "again" before the mirror has been raised.
- Stage 4: show the problem first, for example with no prompt until the copied tower blocks the bridge, then hint.
- Stage 5: the prompt teaches the arrow, but the real difficulty is the position. The stage needs a visual cue, not text.

### 4.8 Small fixes

- Make the camera buttons look less like Undo and Redo, for example arrows around a small cube.
- Make the mirror's grab area visible, with a hover cursor or highlight on desktop.
- Hide the mirror button on stage 1.
- Phone layouts frame the stage small: at 844x390 the stage uses about 100x170 px (screenshot 08), and in portrait about a third of the width.

### Keep these

- The sweep between stages with the chapter title (screenshot 01). It is lovely.
- The live preview while dragging, and the fall ghost during drags.
- The one-axis drag lock and the camera staying still.
- Undo, Z, and Esc to cancel.
- The calm look: jade reads as permanent and the ring as the goal.
- Touch tap and swipe both work.
- The stage 3 and stage 6 ideas.

## 5. Method and limits

- **Driver:** a SceneTree script outside the repo (in the session scratchpad) instantiated `main.tscn`, set a fresh save path, and polled numbered command files. Each batch injected real `InputEventMouseButton`, `InputEventMouseMotion`, `InputEventKey` and `InputEventScreenTouch`/`ScreenDrag` events through `root.push_input`, then saved screenshots, including frames held mid-drag. I looked at each screenshot before deciding the next batch. I used no debug shortcuts and no direct game calls. The only state I read was the stage name and phase in the log.
- **Changes:** no game code, levels or tracked files were changed. Only this report and its screenshots were written. The Godot log showed no script errors during play.
- **Environment limits:**
  - There was no audio device, so I heard none of the sound design.
  - Software rendering is slow, so I could not judge motion, easing, the pulsing sheet, or animation feel.
  - Screenshots are still frames, so I could not see hover states.
  - Timings are driver time, not human time.
  - I did not try pinch, multi-touch, a real phone, or a Mac.
  - I tried touch only for a tap and a swipe on stage 1.
- **What I read beforehand:** `AGENTS.md`, the top of `HANDOFF.md`, and `GAME_DESIGN.md`. The design record names each stage's lesson in one line, and describes Level 1 (shown in game as "A place to stand", stage 2 here) down to its block positions and mirror offsets.
- **What I peeked at:** while looking for how tests inject input, I read `tests/tutorial_playthrough.gd`, which contains the scripted solution of every stage. That told me stage 5 needs a 0.5 slide, and gave me the order for stage 6 (point, slide, drag down, lower). So my struggles in stages 5 and 6 understate how hard they are for a real first-time player.
- **What I did not open:** `levels/*.json` and the solvability tests.
- **Code read only to diagnose bugs I had already hit:** the goal check in `game.gd` and the swipe rule in `ui/world_gesture.gd`.
