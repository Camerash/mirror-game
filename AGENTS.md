# Project instructions

- Use `GAME_DESIGN.md` as the current design record.
- Update it when the user confirms a correction, clarification, or new decision. Replace conflicting statements; use Git history for previous decisions.
- Keep agreed rules separate from proposals and open playtest questions. Keep the document concise.
- Design the game view and controls for iPhone, iPad, and Android. Keep layouts responsive and provide equivalent desktop input for development and possible PC support.
- Rapid-prototype validation defaults to Mac runtime checks. Keep touch-complete responsive phone, tablet, and desktop design.
- Run relevant headless checks and Mac window-size checks. Skip routine Simulator and physical-device checks.
- Run one focused Simulator pass only when an unchecked platform-specific feature could cause substantial rework, such as renderer or shader support, a native plugin, export architecture, or critical touch or safe-area behavior. State the concrete risk before that exception, and do not run broad repeated Simulator matrices.
- An explicit user request can also require a Simulator check.
- Use the `godot-runtime` MCP server for Mac scene inspection, input, and screenshots when available. Call `stop_project` after testing. Before export or commit, confirm that its temporary `McpBridge` autoload and `mcp_bridge.gd` are removed. Keep `.mcp/` output out of Git and exports.
