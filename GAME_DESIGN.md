# Mirror — Living Game Design

Updated: 2026-09-09

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
- The orthographic camera uses four views at 45°, 135°, 225°, and 315°, with 30° downward elevation. Empty-space swipes turn it in quarter steps on mobile; dim curved buttons and Q/E do this on desktop. Each view change blends camera angle, scale, and framing about one fixed pivot for 0.4 seconds. A transient crop at the outer edge is accepted. Rotate-ring fitting runs when Rotate opens, after resize, and after a camera-view change; the camera stays fixed during a rotation gesture. Window resizing cancels the active gesture and starts one blended framing update.

## Agreed world rules

### Mirror and geometry

- The character starts in the original world. One bounded mirror panel selects source geometry inside its rectangular aperture and replaces only the destination column. Original geometry outside the aperture remains. The column has unlimited depth along the panel normal, and both sides clip partial objects at the plane.
- The prototype supports one mirror with legal continuous yaw and pitch. Debug **Angle snap** ranges from 0° (No snap) to 90° in 5° increments and starts at 15°. It sets the rotation target while dragging; 0° retains legal continuous angles. Position targets use half units, size targets use whole units, and angle targets use the selected increment. A target changes only after the pointer passes 10% beyond its midpoint. The displayed sheet eases to the latest target in 0.10 seconds. All levels permit every orientation and both source directions. Each level permits its original and absolute bounds plus a two-unit margin, including previous ranges and initial pivots. These broad limits do not prescribe the solution. A stable world-space pivot determines rotation; a half turn exchanges the source and reflected sides.
- Reflected structures are real interactive geometry. An absolute is one shared object across worlds; mirrors cannot copy, move, or cut it away.
- The character crosses the plane wherever supported surfaces connect. Mirror changes leave the character at the same world position. Absolute platforms provide stable resting points.
- Rendering, collision, prediction, and picking share closed convex fragments at the selected angle. Cardinal results match the box calculation. Box fragments use box collision; angled fragments use convex collision. Live editing changes display geometry only until Confirm. Absolute geometry has priority. Each fragment keeps its original source ID and material coordinates. Native transforms compose the reflected mapping, so textures are cut without compression. Edge detail uses fixed world-unit widths.
- Deactivating a mirror removes its reflections and restores the original geometry it replaced. Gravity always points downward; reflection does not reverse it.
- A fresh mirror is 3×3 world units. Width and height range from 1 to 6 units. Each top or side resize pill captures its opposite edge. Each size target then applies its grid-centre correction from that captured edge. The result must remain inside the placement area; stop at the nearest valid whole-unit size. Undo and Cancel restore dimensions; confirmed removal discards them. The character can cross connected side surfaces.

### Movement and changes

- The character is a `CharacterBody3D` with downward gravity. Its visible face turns toward horizontal movement.
- Navigation samples exposed polygon surfaces at their actual height, using direct clear paths or an eight-direction `AStar3D` search with unnecessary turns removed. The character can stand and walk on slopes up to 45° from horizontal. Steeper surfaces cause sliding or falling and cannot be walking destinations. Every segment checks character clearance and support across the full footprint. Ladders are not implemented yet.
- Create opens a fresh mirror preview near the press; Edit changes an existing mirror. Remove previews an absent mirror. Confirm applies the proposal. Cancel restores the committed state. After removal there is no saved mirror placement; Undo alone can restore it from history. Editing starts in **Move** mode. The bottom-right icon cycles Move, Rotate, and Resize; keys 1, 2, and 3 select them. The icons use thin, simple geometry: a cross for Move, a circle for Rotate, and a square for Resize. Only controls for the active mode are touchable. A short tap on the sheet confirms in every mode. A sheet drag and an inactive mode control never confirm. Move drags the sheet across X/Z at its captured height and uses vertical ticks for Y. Rotate uses two world-aligned full rings at the mirror pivot: Turn is in world X/Z and Tilt is perpendicular to local width. Turn is hidden while horizontal; the angle marker is not a required handle. Their radii are half width or height plus 0.35 world units, with a projected major radius of at least 48 logical units. The near half is clear and the far half is faint; each full visible ring has a 48-logical-unit touch strip. At an overlap, select the nearest curve, then use depth as the tie-breaker. Freeze the selected ring plane, radius, and camera for the gesture and hide the other ring. At edge-on projection, below a 0.15 minor-to-major ratio, use the captured projected tangent and one projected radius per radian. Rotate-ring fitting runs on entering Rotate, after resize, and after a camera-view change. Resize uses local top and side pills only. Reverse sides swaps the source without changing the panel frame. Debug quarter turns remain exact 90° changes.
- Edit modes do not change the physics guards, prediction rules, or history rules.
- Editing freezes character position and velocity. Cancel resumes saved movement in the unchanged world. Confirm preserves position and vertical velocity, clears the walking route, and rejects embedding in solid geometry.
- Editing during walking and falling is allowed by default. A session-level **Standing still only** test option provides the stricter comparison. Decorative atmosphere runs at 20% speed while editing; the UI and ghost stay responsive. Editing has a subtle tint, contextual controls, and a dashed pulsing sheet. Confirm settles the sheet into its steady placed appearance. A disabled proposal keeps a removal outline until Confirm.
- A separate collision world predicts the result with the same capsule and gravity step as the character. A translucent, fog-filled holographic character with two fading afterimages shows a predicted fall. Safe landings pause then fade; failure fades near the lower boundary. There are no trajectory lines, arrows, rings, or gameplay outcome labels. Supported proposals need no ghost. Diagnostic text remains in debug mode. Pending or blocked predictions cannot be confirmed; predicted failure can be confirmed and undone.
- Applying a physics-boundary change rebuilds navigation and clears the current route.
- Losing support starts a fall. Original, reflected, or absolute geometry can provide support, including original geometry restored on deactivation. Landing is safe at any height in this milestone; passing the level's lower boundary causes failure.
- Undo stores the pre-action mirror, character, and goal state for each accepted walk or confirmation, then stops navigation when restored. Opening or cancelling a preview adds no history. Reset clears history.

## Current playable prototype

Level 1, “Rest, then rebuild the route” (shown as “A place to stand” in the game), uses unit-width original platforms at 0, 1, and 2, an absolute resting platform at 5, and an absolute goal at 8. The intended route uses offsets 2.5 and 4.0 within the wider placement area. At 2.5, walk to the rest platform. At 4.0, walk from it to the goal. Safe alternative routes, including successive overlapping reflections, are valid. Completion depends only on reaching the goal.

Eight selectable test fixtures cover natural diagonal walking, obstacle detours, gaps, narrow passages, partial cut, source selection, absolute support, deactivation, wall conflict, and horizontal reflection. The horizontal fixture starts beside reflected high ground, then disables the mirror so the character falls to safe original ground.

Level 2, “Reveal the exit” (shown as “The path beneath”), tests safe restoration on ordinary ground. Original platforms occupy 0–2 and 5–7; the absolute goal is at 8. The intended route starts with the X orientation at offset 2.5; its position is freely adjustable within the broad level area. Enable it, walk to 5, then disable it: the original platform replaces reflected support and the final approach returns. The goal stays visible throughout. This layout is a playtest candidate; no new object or goal rules are needed.

Completing Level 1 shows **Next**. Level 2 ends the current puzzle sequence. The menu also gives direct access to both puzzles and the eight fixtures. Entering a level clears previous movement and Undo history.

Later level:

- **The useful fall:** Reflect a ladder vertically to reach high ground. Remove support, collect an absolute key during the fall, and land beside a locked goal door. Ladder sections join across the plane. Test automatic pickup and forgiving alignment.

## First playtest observations and questions

- Check whether players understand which source side is selected, what partial clipping does, and why absolutes remain.
- Check whether preview support, final-position support, wall rejection, route clearing, and fall feedback are clear.
- Check whether tap/click navigation, smooth mirror dragging, and target snapping feel predictable on phone, tablet, and desktop.
- Check whether all four camera views keep original, reflected, absolute, and goal geometry readable in both portrait and landscape safe areas.
- Check horizontal reflection with unchanged downward gravity and a safe landing. No scores or timers are planned.
- Compare edits during walking/falling with the standing-only option. Check Cancel resumption and whether the ghost makes safe and unsafe outcomes clear.
- Check whether the world atmosphere and absolute contact highlights explain replacement before changing any geometry rules.
- In Level 2, check whether players remember the hidden original approach and trust its support preview. Compare an early deactivation above the gap with a safe deactivation above platform 5.
- Record goal recognition, useful placement predictions, stable-support recognition, recovery, confusion, and alternative solutions. Observe before explaining the intended route.

## Visual and sound direction

- Use clear 3D forms, soft colour and lighting differences between original and reflected space, and a consistent absolute material that does not rely on colour alone.
- The mirror boundary may be portal-like or translucent. Keep affected regions and plane orientation readable.
- The world uses a neutral distant background, warm original surfaces, cool reflected surfaces, and local world-space haze. The bounded aperture limits width and height, while depth along the normal stays unlimited. The two sides have no assigned sun/moon meaning. An even, softly feathered edge light extends along the full perimeter toward reflected space, with no point spikes or bright corners. **Boundary only** in Test options removes local haze for comparison. Walking surfaces remain solid and readable.
- Absolutes use muted jade green (`#719B87`) with dark green stripes and outlines on both sides, including the goal platform. A fine, steady pearl seam with a wider soft cyan mist glow follows the exact intersections of the mirror panel and the four replacement-prism side boundaries on visible top and side faces of original and absolute structures. The contact glow excludes a mirror’s own reflected structures. Normal hologram edges, the perimeter light, and prism guides are unchanged. Absolutes remain solid and unchanged. The glow fades across the object surface, with slow, subtle variation around the stable centre. Contact light updates during editing and stays after placement; removal proposals fade it. Collision and overlap rules are unchanged.
- Watercolour-like modular forms, soft piano, muffled percussion, and subtle boundary changes remain candidates. Validate readability before adding effects.

### Visual trial 01

- **Panel A, Stage-spanning sheet**, is an earlier composition reference. The saved reference is [docs/art/visual-trial-01.png](docs/art/visual-trial-01.png); the trial record is [docs/art/README.md](docs/art/README.md).
- Level 1 keeps the procedural soft stone, restrained seams and wear, warm original and cool night surfaces, local haze, bounded sheet, and simple dark character. The reference guides composition only; its added pillars and cubes do not change level geometry.
- Improve depth fog, material detail, objective detail, and lighting together after bounded-panel readability is stable. Keep other levels as simple fixtures. Story work remains open.

### Immersive controls and visual trial 02

- Hold empty space for 450 ms to create a mirror, or hold its visible sheet to edit. Movement under 12 logical units counts as a hold. A short release on a platform walks; a hold or swipe never also walks.
- A new pivot comes from projecting the press onto a horizontal plane at the character's feet, then snapping and clamping each coordinate to the broad placement area. The level supplies a fresh starting axis and source direction. One mirror is supported now; holding empty space while it exists does not create another.
- Editing starts in Move mode. The bottom-right mode icon cycles Move, Rotate, and Resize; keys 1, 2, and 3 select them. Only the active mode controls receive touch input. Move drags the sheet across X/Z at its captured height. A height control moves it on Y; vertical ticks show its targets. The move guide has a half-unit grid at the captured height, a lower reference plane, a projected pivot marker, and a faint vertical link. It is a guide, not a floor, and does not affect camera fitting. A short sheet tap confirms in every mode; a dragged sheet and inactive mode controls never confirm. A small Confirm action appears when the sheet is inaccessible or removal is proposed.
- Rotate uses two world-aligned full rings at the mirror pivot. Turn is in world X/Z; Tilt is perpendicular to local width. Turn is hidden while horizontal; the angle marker is not a required handle. Their radii are half width or height plus 0.35 world units, with a projected major radius of at least 48 logical units. The near half is clear and the far half is faint; each full visible ring has a 48-logical-unit touch strip. At an overlap, choose the nearest curve, with depth as the tie-breaker. Freeze the selected plane, radius, and camera during the gesture and hide the other ring. Below a 0.15 projected minor-to-major ratio, use the captured projected tangent and one projected radius per radian. Fit rings on entering Rotate, after resize, and after a camera-view change. Runtime state stores yaw, pitch, and a separate source-side flag; history retains them. Reverse sides and keyboard/debug quarter turns remain available.
- Resize pills are 36×12 logical units with 48-unit touch regions, directly on the local top and side edges. They capture the opposite edge and apply the grid-centre correction for each size target. Other mode controls have no hit regions. Keep Cancel available.
- While dragging, position uses half-unit targets, size uses whole-unit targets, and rotation uses the selected angle target. The target changes after 10% midpoint hysteresis and the display eases to the latest target in 0.10 seconds. Committed collision stays unchanged; stale ghosts are hidden and confirmation is blocked during manipulation, settling, and prediction.
- Reuse platform instances, materials, and mist layers during edits. Preserve unaffected structures, animation clocks, and source textures. Update changed fragments together before the frame is drawn.
- A horizontal mobile swipe of at least 48 units, with horizontal movement over 1.5 times vertical movement, turns the camera. Mirror gestures take priority. Desktop has dim bottom-left curved arrows and Q/E.
- Cancel, Remove/Keep mirror, and Reverse sides appear only during editing. Undo appears when available outside editing. Failure offers Undo and Reset; completion offers Next. Gear opens debug controls and Reset. Targets stay at least 48 units and respect safe areas.
- [Mirror shader board 03, panel D](docs/art/mirror-shader-03.png) established the clear-centre direction: an almost-clear centre, fixed world-unit perimeter width, rare edge particles, and short uniform reflected-side ribbons. It replaces the earlier wave treatment. The generated image is an approximate reference, not an in-game capture.
- The current direction combines **B+C**: a 0.25-unit one-sided light skirt and sparse outward particles along the reflected normal, evenly distributed around the perimeter. Use **C: Mist glow** from the seam trial for contact light, including absolutes. [Board 04](docs/art/mirror-direction-contact-04.png) is an approximate reference; contact must follow actual geometry without cutting an absolute. Contacts on the prism sides continue beyond the guide fade distance. [Seam trial](docs/art/seam-glow-05.png) selects C for light softness only; the mockup mirror orientation is incorrect and must not guide geometry.
- Four faint pale blue-grey ribbons extend from the mirror corners along the reflected normal. They are 0.025 units wide at 12% peak opacity and fade smoothly over six units. The approved [subtle B reference](docs/art/prism-guides-06.png) guides their appearance. There is no far cap or filled prism face; the replacement depth stays unlimited. Guides follow the displayed pose and dimensions, remain visible in play, dim during a removal proposal, and disappear when the mirror is absent. They do not affect input or camera fitting. Contact glow remains brighter than the guides, with no extra brightness at shared corners or internal fragment seams.
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

- Add a progressive tutorial that introduces Move/create, then Resize, then Rotate. This is not assigned to the existing levels.
- Generate candidate levels from data, search for solutions with shared world rules, and replay solutions for review. Human playtests decide clarity and enjoyment.
- Multiple mirrors and recursive reflections need rules for order, depth, overlap, dependencies, parent removal, and recursion. No current multi-mirror implementation is agreed. An apparently infinite corridor remains a possible special scene.
- Decide how reflected interactive objects share state when switches, keys, and doors enter the game.

## Next work

- Use focused Mac checks while exploring. After a design decision is confirmed, run the relevant full checks as regression guardrails. Use one focused Simulator pass only when an unchecked platform-specific feature could cause substantial rework; record the concrete risk first.
- Test representative physical iOS and Android devices later, when that work is scheduled.
- Play the eight fixtures and both puzzle routes; use observations to tune clarity and safe boundaries. Fixture 10, **Bounded mirror workshop**, uses three ledges, side obstacles, and absolute start and goal objects to check bounded cuts, side crossing, absolute priority, and source-anchored materials. Its detailed materials check texture cuts; other fixtures remain simple.
- Use focused geometry, control, or resize checks as appropriate; do not treat them as full-suite or Simulator validation.
- Use Level 2 observations to refine restoration feedback. Add ladders and the key-and-fall level after these rules are stable.
- Choose a visual treatment and develop story scenes after concrete playtests.
