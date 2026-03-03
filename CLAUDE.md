# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot 4.6 game project named "utoland" that uses the GDAI MCP plugin for AI-assisted game development. The project enables AI to control the Godot Editor through MCP (Model Context Protocol) to create scenes, nodes, scripts, and debug code.

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

- `mcp__godot__launch_editor` - Launch Godot editor
- `mcp__godot__run_project` - Run the project
- `mcp__godot__get_debug_output` - Get debug output and errors
- `mcp__godot__stop_project` - Stop running project
- `mcp__godot__create_scene` - Create new scene files
- `mcp__godot__add_node` - Add nodes to scenes
- `mcp__godot__load_sprite` - Load sprites into Sprite2D nodes
- `mcp__godot__save_scene` - Save scene changes
- `mcp__godot__get_project_info` - Get project metadata
- `mcp__godot__get_uid` - Get file UIDs
- `mcp__godot__update_project_uids` - Update UID references

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
