# Dependencies

| Name | Version | License | Why | Replaced |
| --- | --- | --- | --- | --- |
| [Godot AI](https://github.com/hi-godot/godot-ai) (`addons/godot_ai`) | 4.3.1 (`35da2c2`) | MIT | Live editor access for agents; development only | Coding-Solo/godot-mcp, unmaintained since April 2026 |
| [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) (16 skills in `.claude/skills`) | `19d93f9` | Apache-2.0 | Godot 4.7 and game-design guidance for agents; not shipped | Nothing |
| [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) (`addons/gdUnit4`) | v6.2.2 (`0127a55`) | MIT | Test framework, ADR 0003; development only | Hand-written runner |
| [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) | 4.5.0 | MIT | Lint and format, ADR 0004; development only | Nothing |
| commons-prose (`.claude/skills/commons-prose`) | project-owned | See its NOTICE.md | Voice and AI-tell rules for all game text; adapted from blader/humanizer, hardikpandya/stop-slop and conorbronsdon/avoid-ai-writing; not shipped | Nothing |
| commons-bgm (`.claude/skills/commons-bgm`) | project-owned | See its NOTICE.md | Suno prompts and music planning; not shipped | Nothing |
| commons-sfx (`.claude/skills/commons-sfx`) | project-owned; tools from [game-sfx](https://github.com/GhazaGG/Game-Sound-Effect-for-Claude) at `0f287ed` | Skill text is ours; tools are MIT | Sound effect sourcing, licensing, synthesis and measurement; not shipped. Under the adoption bar (new, one author), accepted by the project owner after review | Nothing |

Godot AI must be excluded from export presets (`addons/godot_ai/*`). Its telemetry is disabled by `--disable-telemetry` in `.mcp.json` and the `GODOT_AI_DISABLE_TELEMETRY` user environment variable. Update it with its dock's Update button, then update the pin in `.mcp.json` and this table.

`uvx` installs of Godot AI fail on this machine when uv's cache is on C: (`pywin32`, os error 32), so `.mcp.json` and the `godot` launchers set `UV_CACHE_DIR=D:/uv-cache`.

Start a Claude Code session in this project before opening the Godot editor. The add-on then adopts the server that session started. If the editor opens first, its own server launch fails on this machine with `server start blocked`; restart the editor after the session is running.
