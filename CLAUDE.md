# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot 4.6 game project named "utoland" - a 2D tower defense + survival shooter hybrid. The project uses the GDAI MCP plugin for AI-assisted game development.

**Game Type**: Tower Defense + Survival Shooter
**Core Loop**: Character selection → Weapon selection → Tower placement → Wave combat → Shop upgrades → Repeat

## Key Architecture

### Game Systems

**Configuration-Driven Design**:
- All game values centralized in `game_config.gd`
- No hardcoding allowed - must read from GameConfig
- See `.claude/rules/no-hardcode.md`

**State Management**:
- Cross-scene state uses `GameData` AutoLoad singleton
- Scene transitions destroy nodes, data must persist
- See `.claude/rules/use-gamedata.md`

**Core Systems**:
- **Character System**: 3 playable characters (Warrior, Ranger, Tank) with unique stats
- **Weapon System**: 3 weapons (Rifle, Shotgun, Sniper) with different playstyles
- **Tower System**: 3 tower types (Shooter, Wall, Slow) for strategic placement
- **Wave System**: 10 waves with increasing difficulty
- **Shop System**: Between-wave upgrades for player stats and towers

**Scene Flow**:
```
Start Menu → Character Select → Weapon Select → Placement → Combat → Shop → Placement → Combat → ... → Result
```

## Key Architecture

### GDAI MCP Plugin Integration

The project has the GDAI MCP plugin installed at `addons/gdai-mcp-plugin-godot/`. This plugin:

- Provides an autoload singleton `GDAIMCPRuntime` that runs automatically
- Loads a native extension (`GDAIRuntimeServer`) that communicates with MCP clients
- Supports macOS, Windows, and Linux (arm64 and x86_64 architectures)
- Enables AI to programmatically create and manipulate Godot scenes, nodes, and scripts

### Project Structure

- `project.godot` - Main Godot project configuration
- `addons/gdai-mcp-plugin-godot/` - GDAI MCP plugin files
  - `gdai_mcp_plugin.gd` - Editor plugin entry point
  - `gdai_mcp_runtime.gd` - Runtime autoload that instantiates the MCP server
  - `bin/` - Platform-specific native libraries
  - `gdai_mcp_server.py` - Python MCP server script
- `.godot/` - Godot editor cache (auto-generated, not committed)

### Physics & Rendering

- Uses Jolt Physics for 3D physics simulation
- Rendering method: GL Compatibility (for broader device support)
- Windows uses D3D12 driver

## Working with MCP Tools

When working in this project, you have access to specialized Godot MCP tools:

- `mcp__gdai-mcp__get_scene_tree` - Get recursive tree view of all nodes in current scene
- `mcp__gdai-mcp__get_godot_errors` - Get errors from Godot (script errors, etc.)
- `mcp__gdai-mcp__get_filesystem_tree` - Get recursive tree view of project files
- `mcp__gdai-mcp__get_project_info` - Get project information from project.godot
- `mcp__gdai-mcp__get_scene_file_content` - Get raw content of current scene
- `mcp__gdai-mcp__search_files` - Search filesystem with fuzzy matching
- `mcp__gdai-mcp__get_open_scripts` - Get list of scripts open in editor
- `mcp__gdai-mcp__view_script` - View contents of a GDScript file
- `mcp__gdai-mcp__get_editor_screenshot` - Screenshot of Godot editor window
- `mcp__gdai-mcp__get_running_scene_screenshot` - Screenshot of running game window
- `mcp__gdai-mcp__add_node` - Add new node to parent in current scene
- `mcp__gdai-mcp__add_resource` - Add resource/subresource as property to node
- `mcp__gdai-mcp__add_scene` - Add scene as node to parent
- `mcp__gdai-mcp__create_script` - Create GDScript file with content
- `mcp__gdai-mcp__attach_script` - Attach script to node
- `mcp__gdai-mcp__create_scene` - Create new scene with root node
- `mcp__gdai-mcp__edit_file` - Edit file with find and replace
- `mcp__gdai-mcp__open_scene` - Open scene in editor
- `mcp__gdai-mcp__update_property` - Update property of node in scene
- `mcp__gdai-mcp__delete_node` - Delete node in current scene
- `mcp__gdai-mcp__delete_scene` - Delete scene file
- `mcp__gdai-mcp__play_scene` - Play current or main scene
- `mcp__gdai-mcp__execute_editor_script` - Execute arbitrary GDScript in editor
- `mcp__gdai-mcp__clear_output_logs` - Clear output logs in editor
- `mcp__gdai-mcp__stop_running_scene` - Stop currently running scene
- `mcp__gdai-mcp__set_anchor_preset` - Set anchor preset for Control node
- `mcp__gdai-mcp__duplicate_node` - Duplicate existing node
- `mcp__gdai-mcp__move_node` - Move node to different parent
- `mcp__gdai-mcp__simulate_input` - Simulate input actions in running game
- `mcp__gdai-mcp__get_input_map` - Get input actions defined in project

Use these tools to interact with the Godot project programmatically.

## Development Notes

- Godot version: 4.6.stable.official
- The GDAI MCP plugin is a commercial plugin from https://gdaimcp.com/
- Plugin should not be committed to public repositories (per plugin license)
- The plugin requires native binaries in `addons/gdai-mcp-plugin-godot/bin/` to function

## File Writing Guidelines

**CRITICAL**: When writing large documents or plans, you MUST split them into multiple smaller files to avoid Write tool content size limits.

**Strategy for large documents**:
1. Split by logical sections (e.g., Phase 1, Phase 2, Phase 3)
2. Create a main index file that links to all sections
3. Each section file should be under 3000 lines
4. Use clear naming: `plan-phase1.md`, `plan-phase2.md`, etc.

**Example structure for implementation plans**:
```
docs/plans/
├── 2026-03-03-feature-name.md (index/overview)
├── 2026-03-03-feature-name-phase1.md
├── 2026-03-03-feature-name-phase2.md
└── 2026-03-03-feature-name-phase3.md
```
