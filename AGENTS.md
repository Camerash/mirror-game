# Project instructions

- Use `GAME_DESIGN.md` as the current design record.
- Update it when the user confirms a correction, clarification, or new decision. Replace conflicting statements; use Git history for previous decisions.
- Keep agreed rules separate from proposals and open playtest questions. Keep the document concise.
- Design the game view and controls for iPhone, iPad, and Android. Keep layouts responsive and provide equivalent desktop input for development and possible PC support.
- During prototype exploration, use only the smallest check needed for the changed behavior: a parse check, a focused rule check, or a short Mac visual check. Do not run the full suite, replay every level, export builds, or repeat layout/capture matrices for each idea. Apply this policy to the current session.
- After the user confirms a design decision, run the relevant full checks once as regression guardrails. Repeat or broaden them only for changed behavior, a failure, or a concrete unresolved risk. Record what was actually checked.
- Keep touch-complete responsive phone, tablet, and desktop design. Mac is the default runtime target; defer routine physical-device checks.
- Use the Mobile renderer exclusively, with Metal on Apple platforms. Do not add Compatibility fallbacks or Simulator workarounds. iOS Simulator is not a supported target; use native Mac checks and later physical iOS/Android validation.
- Use the `godot-runtime` MCP server for Mac scene inspection, input, and screenshots when available. Call `stop_project` after testing. Before export or commit, confirm that its temporary `McpBridge` autoload and `mcp_bridge.gd` are removed. Keep `.mcp/` output out of Git and exports.

## Blender workflow — required for all agents

- These rules apply to the main agent and every subagent that works on Blender assets in this project. Include this file's absolute path in each Blender worker brief. Require the worker to read it before edits. Send changed rules to an existing worker before it resumes work.
- Use the approved `.blend` file as the working asset in a persistent Blender session. Preserve the approved baseline. Do not rebuild the whole character from a generator script for a local visual correction.
- Use the installed Blender Lab MCP tools first for scene summaries, object inspection, viewport images, and API or manual lookup. Inspect only the affected objects and views. Do not write custom inspection code when an available tool provides the result.
- Use native Blender operations, rig controls, modifiers, and shape keys for edits. Use short, focused Python scripts when the available tools cannot perform the required edit. MCP code execution is still Python; changing the transport alone is not a workflow improvement.
- Keep edits small and inspect their visual result before the next change. For animation, review reach, grip, head and hair clearance, and release poses before completing the motion. Do not add repeated coordinate corrections without diagnosing the failed shape or motion path.
- Keep existing export and validation scripts. Run focused checks during edits; run the agreed combined checks after integration. Do not regenerate full capture sets or export the full asset on each small edit unless a specific failure requires it.
- Save accepted edits in the editable Blender source. Keep export and validation tools consistent with that source; do not let an old generator overwrite accepted live edits.
- If Blender Lab cannot connect or lacks a required operation, report the specific limit. Use a short direct script where needed, but do not silently return to repeated full rebuilds. No additional installation is required for this workflow.
- Evaluate the workflow on one bounded correction before adding more tools. Record time, retries, and token usage when available. Mark unavailable measurements as unavailable; do not claim token savings without evidence.
- Worker reports must state the source used, tools used, edits made, views inspected, checks run, and any fallback or unresolved defect. The main agent must review this evidence before accepting the work.
