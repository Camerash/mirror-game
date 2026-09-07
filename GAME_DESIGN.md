# Mirror — Living Game Design

Updated: 2026-09-08

This is the current design record. Agreed rules are separate from later milestones and playtest questions.

## Experience and platforms

- A calm spatial puzzle about discovery and creative experiments. The story direction remains open.
- Players change reflected structures to reach places that ordinary paths cannot reach.
- Previews, short failure feedback, undo, cancel, and reset make experiments inexpensive.
- The game view and controls support iPhone, iPad, Android, and desktop development. Touch uses large reachable targets; mouse and keyboard provide equivalent desktop input. Camera framing and controls adapt to safe areas and aspect ratio.
- Native Mac and unsigned iPhone/iPad Simulator builds run. Level 1 has passed automated replay and an agent-operated iPhone touch test. Physical iOS and Android checks and user playtests come later. See `VALIDATION.md` for actual checks and limits.

## Technical baseline

- Godot **4.7.2 stable**, typed GDScript, Compatibility renderer.
- Procedural 3D geometry is the current prototype approach. Blender assets come later.
- Level data is JSON and separate from scenes.
- Touch targets are at least 48 logical units. Controls use a bottom panel on narrow screens and a side panel when space permits. Both layouts respect safe areas.
- The camera is fixed orthographic: 45° azimuth and 30° downward. It frames allowed reflections.

## Agreed world rules

### Mirror and geometry

- The character starts in the original world. A mirror keeps original geometry on its source side and replaces the entire opposite side with reflections. Original geometry is clipped at the plane, including partial objects.
- The first prototype supports one axis-aligned mirror: a vertical X/Z plane or a horizontal Y plane. Mirror positions use half-unit offsets and level-defined ranges.
- Reflected structures are real interactive geometry. An absolute is one shared object across worlds; mirrors cannot copy, move, or cut it away.
- The character crosses the plane wherever supported surfaces connect. Mirror changes leave the character at the same world position. Absolute platforms provide stable resting points.
- Pure AABB source clipping and reflection are shared by preview and collision. Absolute geometry has priority.
- Deactivating a mirror removes its reflections and restores the original geometry it replaced. Gravity always points downward; reflection does not reverse it.

### Movement and changes

- The character is a `CharacterBody3D` with downward gravity.
- Flat-surface navigation uses `AStar3D` for tap/click movement. Ladders are not implemented yet.
- While previewing a mirror change, the character is frozen. Applying checks support at the final position and rejects any change that embeds a wall in the character.
- Applying a physics-boundary change rebuilds navigation and clears the current route.
- Losing support starts a fall. Original, reflected, or absolute geometry can provide support, including original geometry restored on deactivation. Landing is safe at any height in this milestone; passing the level's lower boundary causes failure.
- Undo stores the pre-action mirror, character, and goal state for each accepted walk or edit. Cancel discards the current preview. Reset clears history.

## Delivered first prototype

Level 1, “Rest, then rebuild the route” (shown as “A place to stand” in the game), uses unit-width original platforms at 0, 1, and 2, an absolute resting platform at 5, and an absolute goal at 8. Mirror offsets run from 2.5 to 4.0. At 2.5, walk to the rest platform. At 4.0, walk from it to the goal. Safe alternative routes, including successive overlapping reflections, are valid. Completion depends only on reaching the goal.

Six selectable test fixtures cover partial cut, source selection, absolute support, deactivation, wall conflict, and horizontal reflection. The horizontal fixture starts beside reflected high ground, then disables the mirror so the character falls to safe original ground.

Later levels:

- **Reveal the exit:** Use a reflection to reach a position, then disable it. Original support returns and reveals the exit and its final approach.
- **The useful fall:** Reflect a ladder vertically to reach high ground. Remove support, collect an absolute key during the fall, and land beside a locked goal door. Ladder sections join across the plane. Test automatic pickup and forgiving alignment.

## First playtest observations and questions

- Check whether players understand which source side is selected, what partial clipping does, and why absolutes remain.
- Check whether preview support, final-position support, wall rejection, route clearing, and fall feedback are clear.
- Check whether tap/click navigation and half-unit mirror movement feel predictable on phone, tablet, and desktop.
- Check whether the fixed camera keeps original, reflected, absolute, and goal geometry readable in both portrait and landscape safe areas.
- Check horizontal reflection with unchanged downward gravity and a safe landing. No scores or timers are planned.
- Record goal recognition, useful placement predictions, stable-support recognition, recovery, confusion, and alternative solutions. Observe before explaining the intended route.

## Visual and sound direction

- Use clear 3D forms, soft colour and lighting differences between original and reflected space, and a consistent absolute material that does not rely on colour alone.
- The mirror boundary may be portal-like or translucent. Keep affected regions and plane orientation readable.
- The current test compares a thin plane outline with a soft translucent plane. Original surfaces are warm, reflections are cooler, and absolutes keep a visible stripe pattern. Walking surfaces remain solid.
- Watercolour-like modular forms, soft piano, muffled percussion, and subtle boundary changes remain candidates. Validate readability before adding effects.

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

- Test representative physical iOS and Android devices. Compare performance and touch input with the Simulator checks.
- Play the six fixtures and the Level 1 route; use observations to tune clarity and safe boundaries.
- Build Level 2 and Level 3 after the current prototype rules are stable.
- Choose a visual treatment and develop story scenes after concrete playtests.
