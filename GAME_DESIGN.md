# Mirror — Living Game Design

Updated: 2026-09-08

This document records agreed design decisions and proposals that still need playtests. Update it when the user confirms a correction or clarification. Replace conflicting text so only the current decision remains; Git preserves the history. Level layouts and story concepts are candidates, not finished content.

## Experience

- A calm spatial puzzle game built around discovery and creative experiments.
- Players change reflected structures to reach places that ordinary paths cannot reach.
- Clear previews, short failure animations, undo, and quick resets keep experiments inexpensive.
- iPhone and iPad are the primary playtest devices. Android support is required. PC support remains a potential release target.

## Platforms and responsive design

- Design the game view and interface for phone, tablet, and resizable desktop screens from the start.
- Adapt camera framing and control layout to the available area, aspect ratio, and device safe areas. Keep relevant original, reflected, and absolute structures visible as the mirror changes.
- Keep text readable and touch targets large. Controls must remain reachable without covering the route, mirror boundary, or objectives.
- Provide touch controls for mobile and equivalent mouse and keyboard actions for desktop tests. Essential actions must work without hover.
- Test portrait and landscape layouts, narrow phones, iPad proportions, and desktop window resizing. Final orientation policy and minimum supported devices remain open.
- Run the first device playtests on iOS and iPadOS, with Android checks early enough to detect rendering and input differences.

## Technical baseline

- Use the latest stable Godot release at setup: **4.7.2**, verified on 2026-09-08 against the [official download page](https://godotengine.org/download/macos/). Keep the selected version fixed until an explicit upgrade is tested.
- Typed GDScript, procedural prototype geometry, and a later Blender art kit are the current implementation proposal. Renderer selection still needs device tests.
- Start a clean project. The old prototype is available at [Camerash/mirror](https://github.com/Camerash/mirror), with inspected revision `7d4c0bd`.
- Useful prototype references: orthographic camera at 45 degrees around the stage and 30 degrees downward; grid cell size `(2, 1, 2)`; mirror movement in 1-unit steps; 90-degree turns; movement and rotation animations of 0.1 and 0.2 seconds. These are test starting points, not fixed design rules.

## Agreed world rules

### Geometry and crossing

- The character starts in the original world.
- A mirror defines a plane. Original structures on its source side are reflected across that plane.
- The reflected side replaces an entire side of the level. Original geometry there is cut away, including the part of an object that crosses the plane.
- The alternate world starts empty. Mirrors supply its reflected structures.
- Reflected structures are real, interactive geometry. The character can cross the boundary wherever walkable surfaces connect.
- An absolute is one shared object across worlds. Mirrors cannot copy, move, or cut it away. Absolute platforms can provide stable resting places.
- Deactivating a mirror removes its reflections and immediately restores the original geometry it replaced.

### Character, support, and mirror changes

- Mirror changes leave the character at the same world position. Reflected platforms do not carry the character when a mirror moves.
- The character survives if supported after the change. Support can come from original geometry, reflected geometry, or an absolute.
- Restored original geometry can support the character after deactivation. Being in reflected space does not itself cause death.
- Losing support starts a fall. A fall can lead to a safe landing, an objective, or failure.
- Gravity keeps the same world direction, including after a horizontal-plane reflection. Reflection does not reverse gravity.
- The character can use connected ladder sections as one continuous ladder, including vertically reflected sections.
- Mirror controls remain available in reflected space. Safety depends on support.

### Changes and feedback to test

- Adjust a preview, then apply the selected mirror position. For the first tests, evaluate the completed configuration; transition animation does not carry or strike the character.
- Preview the resulting geometry and make loss of support clear. Apply the completed configuration, then resume gravity and movement.
- If a change would place a solid wall through the character, show the conflict and reject the change.
- After a fatal fall, show a short failure animation and offer undo or a quick reset.

### Multiple mirrors

Multiple mirrors and repeated reflections are a later exploration. Removing a source mirror can erase dependent reflections and leave the character unsupported. Reflection order, depth, and overlapping regions still need rules. A corridor that appears infinite remains a possible special scene.

## First proof-of-concept levels

### 1. Rest, then rebuild the route

**Goal:** Reach an absolute goal platform across two gaps.

Use one mirror position to connect the original starting platform to an absolute resting platform. Walk there, then change the mirror to create a route from that resting platform to the goal.

**Teaches:** Crossing the boundary, shared absolute support, and changing a route while staying in place.

**Check:** The resting platform is necessary for the intended solution. The character stays supported as the reflected route changes.

### 2. Reveal the exit

**Goal:** Reach an original exit that is cut away while the mirror is active.

Use a reflection to reach a position that cannot be reached in the original layout alone. Deactivate the mirror there. Original geometry returns beneath the character and reveals the exit and its final approach.

**Teaches:** Deactivation can provide support and complete a route.

**Check:** The exit is unreachable before using the reflection. Its restored floor supports the character immediately. The exact layout still needs validation.

### 3. The useful fall

**Goal:** Collect an absolute key during a fall, then use it to open the goal door.

Place a mirror with a horizontal plane to create reflected high ground. Connect original and vertically reflected ladder sections to climb there. From a suitable position, deactivate or change the mirror to remove support. Fall through the absolute key and land safely on a lower platform with a route to the door.

**Teaches:** Horizontal-plane reflection, ladder continuity, unchanged gravity, and useful falls.

**Check:** The intended route requires collecting the key during the fall. The landing is clear and safe, and the door requires the collected key. Test automatic pickup and forgiving alignment so the puzzle depends on planning the fall.

## Visual and sound direction

- Working proposal: actual 3D geometry with a fixed orthographic camera. Test vertical routes for visibility.
- Keep walkable surfaces and connections sharp and readable in both worlds.
- Distinguish original and reflected space through soft colour, lighting, and atmosphere changes.
- Keep absolutes recognisable through a consistent material and surface pattern. Do not depend on colour alone.
- The mirror boundary can use a portal-like or translucent shader. It does not need to look like a conventional mirror; the reflected structures already show its effect.
- Make the plane's position, source side, and affected region clear for both vertical and horizontal placements.
- Art candidate: simple modular forms, faded colours, and painted or watercolor-like surfaces. Test readability before adding strong effects.
- Sound candidates from the original notes: soft piano, muffled percussion, and subtle changes across the boundary. Final music and sound direction remain open.

## Pending story directions

All three directions remain open. Themes can overlap, but each candidate should first have a clear central relationship.

| Direction | Candidate story | Connection to play |
| --- | --- | --- |
| Connection and belonging | A traveller repairs paths between residents and gradually finds a place among them. | Creating routes brings people together; absolutes provide shared places. |
| Identity and possible lives | Someone returns to a place they left and explores how different choices could change their relationship with it. | The same source structures offer different routes and possibilities. |
| Loss and acceptance | Someone inherits unfinished work and gradually gives it a purpose of their own. | Familiar structures remain useful as paths and needs change. |

For each candidate, develop an opening scene, one relationship, one puzzle with emotional meaning, and a possible ending. Compare whether the player cares about someone, whether actions carry meaning, and whether the ending changes the meaning of an earlier action.

The workshop concept is one loss-and-acceptance candidate: the protagonist returns to close a deceased mentor's workshop, completes repairs for residents, and learns to adapt that work to present needs. Character identities and the ending remain open. A quiet protagonist and environmental storytelling are options from the old notes, not settled requirements.

## Playtests and level generation

First build and play the three hand-made levels. Check whether players can predict reflection, identify safe support, understand restored geometry, climb across the boundary, and plan a useful fall. Observe whether mirror adjustments create decisions or repeated searches for a working position.

Test the same layouts with simple visual treatments. Check small-screen readability, horizontal-plane boundaries, key visibility during a fall, and recognition of absolutes. Compare preview information with what players actually need. Repeat input and layout checks on iPhone, iPad, and Android; check desktop resizing and mouse/keyboard actions during development.

Proposed generation process: represent a small level and its legal actions as data, generate candidate layouts, search for solutions, and present candidates with solution replays for review. The game and solver should share the same rules. Include ladders, falls, keys, and mirror changes when those mechanics enter the generator. Solvability and solution length help select candidates; human playtests decide clarity and enjoyment.

## Open decisions and next work

- Confirm the language and renderer, select representative iPhone, iPad, and Android test devices, and initialise the new Godot project.
- Choose movement controls, mirror placement controls, position snapping, and allowed plane orientations. Horizontal planes are required for the third test level.
- Define partial-object collision and ladder connections so visible and playable geometry agree.
- Decide safe landing limits, key pickup behaviour, and undo behaviour during falls. Keep undo consistent across mirror, character, and key state.
- Define how reflected interactive objects share state with their sources when those objects are introduced.
- Select a visual treatment through side-by-side playtests before building a larger art kit.
- Develop the three story candidates alongside the mechanics. Choose the story after comparing concrete scenes.
