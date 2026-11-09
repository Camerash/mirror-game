# Project instructions

- Start with `HANDOFF.md`: the current state, what is blocked, and the traps.
  Keep it under about 150 lines of current state; Git history keeps the rest.
- Read `docs/VISION.md` before design or build work. It says what the game
  should feel like; `GAME_DESIGN.md` says the rules.
- Before any art or scene work, read `docs/art/STYLE.md` (once it exists) and
  look at the approved target frame it names.
- `GAME_DESIGN.md` is the design record. Update it when the owner confirms a
  correction, clarification or new decision. Replace conflicting statements;
  Git history keeps earlier ones. Keep agreed rules separate from proposals and
  open playtest questions. Keep it concise.
- Update the docs once per session, at the end, not after every step.
- Release on Steam first, then iPhone and iPad, then Android. Design the view
  and controls for all of them: complete mouse and keyboard input for Steam,
  touch-complete responsive layouts for phones and tablets.
- Use the Mobile renderer only, with Metal on Apple platforms. No
  Compatibility fallbacks or Simulator workarounds.

## Checks while prototyping

- Use the smallest check for the changed behaviour: a parse check, the one test
  file that covers it, or one capture. No full suite, no replay of every level,
  no exports and no capture matrices until a release candidate or the owner
  asks. Record what was actually checked.
- Tests guard rules, collision, budgets and invariants. They never assert a
  look (a shader, a texture, a colour). Pictures judge the look.

## The art gate

- A picture is the gate for art, not a test or a self-review. Every art change
  ends with an in-game capture beside the approved target frame.
- An independent reviewer agent, which did not make the change, compares the
  two and lists what still differs. The owner approves.
- Send review pictures to the owner directly; they read on a phone.

## Media in Git

- No video in Git. Keep review images as JPG, under about 400 KB each, and
  only the ones a doc needs. Raw captures go to the ignored `test-output/` or
  the session scratchpad.

## Generation tools

- Model names live in one file, `tools/gemini/models.json` (all vendors).
- Gemini: a Flash model for drafts (boards, explorations, iterations); a Pro
  model only for a final render the owner approved as final.
- AI 3D (Tripo, Meshy; keys `TRIPO_API_KEY`, `MESHY_API_KEY`): organic props
  only, never the gameplay ground. Treat the result as a draft: remesh or
  decimate it and repaint it in the project palette in Blender before it goes
  in the game. Record credits used.
- Keys stay in the environment. Never print them or write them to a file.

## Blender — required for all agents

- These rules apply to the main agent and every subagent that works on Blender
  assets. Include this file's absolute path in each Blender worker brief and
  require the worker to read it before edits. Send changed rules to an existing
  worker before it resumes.
- Work on the approved `.blend` in `art_sources/`. Preserve the approved
  baseline. Do not rebuild a whole asset from a generator script for a local
  correction; do not let an old generator overwrite accepted edits.
- In the cloud container, run Blender headless with short scripts:
  `blender -b file.blend --python script.py`. Eevee renders need
  `xvfb-run -a`. Bake ambient occlusion and bounce light in Cycles here;
  Godot's LightmapGI cannot bake headless.
- Use native operations, modifiers, rig controls and shape keys. Keep edits
  small and render the affected views before the next change. For animation,
  review reach, grip, head and hair clearance, and release poses.
- Keep the existing export and check scripts; run the focused one during an
  edit and the combined ones after integration.
- Worker reports state the source used, tools used, edits made, views
  inspected, checks run, and any fallback or unresolved defect. The main agent
  reviews this before accepting the work.

## Appendix: working on the owner's Mac

- Mac is the default runtime target for feel checks; defer physical-device
  checks. iOS Simulator is not a supported target.
- Use the `godot-runtime` MCP server for scene inspection, input and
  screenshots when available. Call `stop_project` after testing. Before export
  or commit, remove its temporary `McpBridge` autoload and `mcp_bridge.gd`.
  Keep `.mcp/` out of Git and exports.
- The Blender Lab MCP bridge is described in `docs/art/blender-workflow.md`.
  Use it when it is connected; otherwise use headless scripts as above.
