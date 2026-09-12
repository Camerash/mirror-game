# Blender connection and review workflow

## Installed connection

Use the [official Blender Lab MCP](https://www.blender.org/lab/mcp-server/) with saved Blender Python scripts. MCP provides live scene access, API documentation, and screenshots. It does not replace modeling skill or multi-angle review.

Installed on this Mac on 2026-09-13:

- Blender 5.2.1 LTS; official `mcp` extension enabled in the local user repository.
- [Official source](https://projects.blender.org/lab/blender_mcp), pinned at `ff54e4d8f6b09502f2f466189cca0e52b4a91643`.
- Server package 1.0.2 in `~/.local/share/mirror-blender-mcp/.venv`.
- Codex server name: `blender-lab`. Transport: stdio. Blender bridge: `localhost:9876`.
- Bridge auto-start is off. Start it only for an active modeling session. Installation files and local client output stay outside Git.

With Blender closed, start a connected session:

```sh
rtk proxy open -a Blender --args --online-mode --python-expr 'import bpy; bpy.ops.blmcp.server_start()'
```

The official add-on requires Blender online access even for localhost. This command enables it for the launched session. In an existing Blender session, use Preferences → Add-ons → MCP → Start Server after enabling online access. Stop Server ends the bridge. Keep it bound to localhost.

Codex may need to reconnect its MCP servers before the new tools appear. The initial setup was verified through a standard Python MCP client: initialize, list 26 tools, read the live Blender version and scene, and capture the viewport. The current Codex session did not acquire the new tool list automatically.

## Why this connection

The [official Astra example](https://developers.openai.com/blog/architectural-visualization-with-astra) uses Blender Python and repeated render inspection. It does not establish a separate modeling interface or an MCP quality advantage.

The newer [Blender Compact MCP for Astra](https://github.com/mohakmalviya/blender-astra-mcp) reports a 47.77% reduction in command/result data for one batching benchmark within its own bridge. That does not measure model quality, total task time, or total token cost against our saved scripts. It was not installed. We selected the official connection for live inspection and kept direct Python for editable, repeatable construction.

## Character study

Keep Astra as the main coordinator and visual reviewer. A Terra worker may implement a bounded modeling step after its shape and interfaces are defined.

Start with simple geometry and plain material colours. Inspect the same model from front, side, back, three-quarter, and elevated game views. Correct shape and overlap errors before adding texture, a rig, or cloth motion. Save the editable Blender file and its construction script. Existing game assets remain until the replacement is approved.
