# Project instructions

- Use `GAME_DESIGN.md` as the current design record.
- Update it when the user confirms a correction, clarification, or new decision. Replace conflicting statements; use Git history for previous decisions.
- Keep agreed rules separate from proposals and open playtest questions. Keep the document concise.
- Design the game view and controls for iPhone, iPad, and Android. Keep layouts responsive and provide equivalent desktop input for development and possible PC support.
- During prototype exploration, use only the smallest check needed for the changed behavior: a parse check, a focused rule check, or a short Mac visual check. Do not run the full suite, replay every level, export builds, or repeat layout/capture matrices for each idea. Apply this policy to the current session.
- After the user confirms a design decision, run the relevant full checks once as regression guardrails. Repeat or broaden them only for changed behavior, a failure, or a concrete unresolved risk. Record what was actually checked.
- Keep touch-complete responsive phone, tablet, and desktop design. Mac is the default runtime target; skip routine Simulator and physical-device checks.
- Run one focused Simulator pass only when an unchecked platform-specific feature could cause substantial rework, such as renderer or shader support, a native plugin, export architecture, or critical touch or safe-area behavior. State the concrete risk before that exception, and do not run broad repeated Simulator matrices.
- An explicit user request can also require a Simulator check.
- Use the `godot-runtime` MCP server for Mac scene inspection, input, and screenshots when available. Call `stop_project` after testing. Before export or commit, confirm that its temporary `McpBridge` autoload and `mcp_bridge.gd` are removed. Keep `.mcp/` output out of Git and exports.
