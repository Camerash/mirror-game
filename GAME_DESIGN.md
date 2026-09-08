# Mirror — Living Game Design

Updated: 2026-09-08

This is the current design record. Agreed rules are separate from later milestones and playtest questions.

## Experience and platforms

- A calm spatial puzzle about discovery and creative experiments. The story direction remains open.
- Players change reflected structures to reach places that ordinary paths cannot reach.
- Previews, short failure feedback, undo, cancel, and reset make experiments inexpensive.
- The game view and controls support iPhone, iPad, Android, and desktop development. Touch uses large reachable targets; mouse and keyboard provide equivalent desktop input. Camera framing and controls adapt to safe areas and aspect ratio.
- During prototype exploration, use the smallest useful check on Mac. Run the relevant full checks after design decisions are confirmed, as regression guardrails; do not repeat full suites or layout matrices for each idea. Earlier evidence includes an iPhone touch Level 1 pass and iPad rendering. A later Simulator restart stalled on a blank background, so final Simulator validation is unresolved and deferred. Physical iOS and Android checks and user playtests come later. See `VALIDATION.md` for actual checks and limits.

## Technical baseline

- Godot **4.7.2 stable**, typed GDScript, Compatibility renderer.
- Procedural 3D geometry is the current prototype approach. Blender assets come later.
- Level data is JSON and separate from scenes.
- Touch targets are at least 48 logical units. The agreed direction is an immersive world with minimal gameplay controls. A top-right gear will show or hide debug panels; panels will be hidden by default. The world fills the window. Gameplay uses direct gestures and small contextual actions; diagnostic controls stay in the gear panel.
- The orthographic camera uses four views at 45°, 135°, 225°, and 315°, with 30° downward elevation. Empty-space swipes turn it in quarter steps on mobile; dim curved buttons and Q/E do this on desktop. It fits committed geometry during play and permitted reflections for the selected orientation on entering editing or turning the mirror; zoom stays steady during mirror dragging. Off-screen failure outcomes use an edge marker.

## Agreed world rules

### Mirror and geometry

- The character starts in the original world. A mirror keeps original geometry on its source side and replaces the entire opposite side with reflections. Original geometry is clipped at the plane, including partial objects.
- The prototype supports one axis-aligned mirror: a vertical X/Z plane or a horizontal Y plane. All levels permit every orientation and both source directions. Positions use half-unit offsets and level-defined ranges. A stable world-space pivot determines rotation; a half turn exchanges the source and reflected sides.
- Reflected structures are real interactive geometry. An absolute is one shared object across worlds; mirrors cannot copy, move, or cut it away.
- The character crosses the plane wherever supported surfaces connect. Mirror changes leave the character at the same world position. Absolute platforms provide stable resting points.
- Pure AABB source clipping and reflection are shared by preview and collision. Absolute geometry has priority.
- Deactivating a mirror removes its reflections and restores the original geometry it replaced. Gravity always points downward; reflection does not reverse it.

### Movement and changes

- The character is a `CharacterBody3D` with downward gravity. Its visible face turns toward horizontal movement.
- Flat-surface navigation uses direct clear paths or an eight-direction `AStar3D` search with unnecessary turns removed. Every segment checks character clearance and support across the full footprint. Ladders are not implemented yet.
- Create opens a fresh mirror preview near the press; Edit changes an existing mirror. Remove previews an absent mirror. Confirm applies the proposal. Cancel restores the committed state. After removal there is no saved mirror placement; Undo alone can restore it from history. Turn left/right rotates vertical mirrors by 90°. Lay flat/Stand up changes between horizontal and the previous vertical direction. Reverse sides swaps the source. The whole visible sheet is draggable during editing; hidden portions and UI do not receive sheet input. There is no separate drag handle.
- Editing freezes character position and velocity. Cancel resumes saved movement in the unchanged world. Confirm preserves position and vertical velocity, clears the walking route, and rejects embedding in solid geometry.
- Editing during walking and falling is allowed by default. A session-level **Standing still only** test option provides the stricter comparison. Decorative atmosphere runs at 20% speed while editing; the UI and ghost stay responsive. Editing has a subtle tint, contextual controls, and a dashed pulsing sheet. Confirm settles the sheet into its steady placed appearance. A disabled proposal keeps a removal outline until Confirm.
- A separate collision world predicts the result with the same capsule and gravity step as the character. A bright ghost with a dark outline, a trajectory with contrasting strokes and arrows, and labelled landing/failure markers show the outcome. A supported character gets a stationary support ring. Pending or blocked predictions cannot be confirmed; predicted failure can be confirmed and undone.
- Applying a physics-boundary change rebuilds navigation and clears the current route.
- Losing support starts a fall. Original, reflected, or absolute geometry can provide support, including original geometry restored on deactivation. Landing is safe at any height in this milestone; passing the level's lower boundary causes failure.
- Undo stores the pre-action mirror, character, and goal state for each accepted walk or confirmation, then stops navigation when restored. Opening or cancelling a preview adds no history. Reset clears history.

## Current playable prototype

Level 1, “Rest, then rebuild the route” (shown as “A place to stand” in the game), uses unit-width original platforms at 0, 1, and 2, an absolute resting platform at 5, and an absolute goal at 8. Mirror offsets run from 2.5 to 4.0. At 2.5, walk to the rest platform. At 4.0, walk from it to the goal. Safe alternative routes, including successive overlapping reflections, are valid. Completion depends only on reaching the goal.

Seven selectable test fixtures cover natural diagonal walking, obstacle detours, gaps, narrow passages, partial cut, source selection, absolute support, deactivation, wall conflict, and horizontal reflection. The horizontal fixture starts beside reflected high ground, then disables the mirror so the character falls to safe original ground.

Level 2, “Reveal the exit” (shown as “The path beneath”), tests safe restoration on ordinary ground. Original platforms occupy 0–2 and 5–7; the absolute goal is at 8. The initial X orientation stays at offset 2.5. Enable it, walk to 5, then disable it: the original platform replaces reflected support and the final approach returns. The goal stays visible throughout. This layout is a playtest candidate; no new object or goal rules are needed.

Completing Level 1 shows **Next**. Level 2 ends the current puzzle sequence. The menu also gives direct access to both puzzles and the seven fixtures. Entering a level clears previous movement and Undo history.

Later level:

- **The useful fall:** Reflect a ladder vertically to reach high ground. Remove support, collect an absolute key during the fall, and land beside a locked goal door. Ladder sections join across the plane. Test automatic pickup and forgiving alignment.

## First playtest observations and questions

- Check whether players understand which source side is selected, what partial clipping does, and why absolutes remain.
- Check whether preview support, final-position support, wall rejection, route clearing, and fall feedback are clear.
- Check whether tap/click navigation and half-unit mirror movement feel predictable on phone, tablet, and desktop.
- Check whether all four camera views keep original, reflected, absolute, and goal geometry readable in both portrait and landscape safe areas.
- Check horizontal reflection with unchanged downward gravity and a safe landing. No scores or timers are planned.
- Compare edits during walking/falling with the standing-only option. Check Cancel resumption and whether the ghost makes safe and unsafe outcomes clear.
- Check whether the world atmosphere and absolute contact highlights explain replacement before changing any geometry rules.
- In Level 2, check whether players remember the hidden original approach and trust its support preview. Compare an early deactivation above the gap with a safe deactivation above platform 5.
- Record goal recognition, useful placement predictions, stable-support recognition, recovery, confusion, and alternative solutions. Observe before explaining the intended route.

## Visual and sound direction

- Use clear 3D forms, soft colour and lighting differences between original and reflected space, and a consistent absolute material that does not rely on colour alone.
- The mirror boundary may be portal-like or translucent. Keep affected regions and plane orientation readable.
- The world uses a neutral distant background, warm original surfaces, cool reflected surfaces, and local world-space haze. A translucent sheet with subtle ripples spans the stage and permitted reflections. Its visible edges lie outside playable geometry and do not limit reflection. The two sides have no assigned sun/moon meaning. An even, softly feathered band of light extends along the entire mirror perimeter toward the reflected side. It has no point spikes or bright corner overlaps. **Boundary only** in Test options removes local haze for comparison. Walking surfaces remain solid and readable.
- Absolutes retain their material and stripe pattern with clear edges. During editing, reflected contact regions are highlighted and a brief dashed outline shows incoming reflected structures. Collision and overlap rules are unchanged.
- Watercolour-like modular forms, soft piano, muffled percussion, and subtle boundary changes remain candidates. Validate readability before adding effects.

### Visual trial 01

- **Panel A, Stage-spanning sheet**, is the approved initial art direction. The saved reference is [docs/art/visual-trial-01.png](docs/art/visual-trial-01.png); the trial record is [docs/art/README.md](docs/art/README.md).
- After the mechanics pass, Level 1 receives the first polished trial: procedural soft stone, restrained seams and wear, warm original and cool night surfaces, local haze, a thin sheet, and a simple dark character. The reference guides composition and materials; its added pillars and cubes do not change level geometry.
- Review feedback: the current trial does not yet reach the reference. Improve depth fog, flowing mirror shading, material detail, objective detail, and lighting together. Keep other levels as simple fixtures. Story work remains open.

### Immersive controls and visual trial 02

- Hold empty space for 450 ms to create a mirror, or hold its visible sheet to edit. Movement under 12 logical units counts as a hold. A short release on a platform walks; a hold or swipe never also walks.
- A new pivot comes from projecting the press onto a horizontal plane at the character's feet, then snapping and clamping each coordinate. The level supplies a fresh starting axis and source direction. One mirror is supported now; holding empty space while it exists does not create another.
- During editing, drag the sheet to translate. A separate short tap within 24 logical units of a visible outline confirms. Releasing a drag never confirms. A small Confirm action appears if no outline is accessible.
- Two curved grips near the sheet corners turn and tilt it. A 24-unit drag produces one quarter turn; the directional ends also accept taps. The turn grip is hidden when horizontal. Reverse sides remains available in editing.
- A horizontal mobile swipe of at least 48 units, with horizontal movement over 1.5 times vertical movement, turns the camera. Mirror gestures take priority. Desktop has dim bottom-left curved arrows and Q/E.
- Cancel, Remove/Keep mirror, and Reverse sides appear only during editing. Undo appears when available outside editing. Failure offers Undo and Reset; completion offers Next. Gear opens debug controls and Reset. Targets stay at least 48 units and respect safe areas.
- **D** in [visual-trial-02.png](docs/art/visual-trial-02.png) is the approved visual direction, with a correction: light is even along all four edges rather than concentrated in spikes. The generated image is an approximate reference, not an in-game capture.
- Level 1 uses holographic pearl-blue reflections with clear near-opaque walking tops, translucent sides, and soft contours. Original stone and patterned absolutes remain solid. Layered mist, detailed stone, and a carved goal ring supply the first art trial. Other levels retain simple platform materials.
- The image's extra pillars and cubes do not change level geometry or objectives.

## Pending story directions

All three directions remain open and may overlap:

| Direction | Candidate story | Connection to play |
| --- | --- | --- |
| Connection and belonging | A traveller repairs paths between residents and finds a place among them. | Creating routes brings people together; absolutes provide shared places. |
| Identity and possible lives | Someone returns to a place they left and explores how different choices change relationships. | The same source structures offer different routes and possibilities. |
| Loss and acceptance | Someone inherits unfinished work and gives it a purpose of their own. | Familiar structures remain useful as paths and needs change. |

The workshop concept remains one loss-and-acceptance candidate: the protagonist returns to close a deceased mentor’s workshop, completes repairs for residents, and adapts that work to present needs. Character identities, opening scene, and ending remain open.

Compare each story through an opening, one relationship, a puzzle with emotional meaning, and an ending. A quiet protagonist and environmental storytelling remain options.

## Later exploration

- Generate candidate levels from data, search for solutions with shared world rules, and replay solutions for review. Human playtests decide clarity and enjoyment.
- Multiple mirrors and recursive reflections need rules for order, depth, and overlap. An apparently infinite corridor remains a possible special scene.
- Decide how reflected interactive objects share state when switches, keys, and doors enter the game.

## Next work

- Use focused Mac checks while exploring. After a design decision is confirmed, run the relevant full checks as regression guardrails. Use one focused Simulator pass only when an unchecked platform-specific feature could cause substantial rework; record the concrete risk first.
- Test representative physical iOS and Android devices later, when that work is scheduled.
- Play the seven fixtures and both puzzle routes; use observations to tune clarity and safe boundaries.
- Use Level 2 observations to refine restoration feedback. Add ladders and the key-and-fall level after these rules are stable.
- Choose a visual treatment and develop story scenes after concrete playtests.
