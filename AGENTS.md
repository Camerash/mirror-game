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
