# Fix Project Startup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all issues preventing the utoland Godot project from starting and running through the complete game flow.

**Architecture:** The project has two blocking issues: (1) `class_name SceneFactory` conflicts with the autoload singleton of the same name, causing a parser error at startup; (2) `tower_shooter.tscn` is missing from `scenes/towers/` (only exists in `scenes/backup/`), causing preload failure. There is also a minor warning about an unused parameter.

**Tech Stack:** Godot 4.6, GDScript

---

## Issues Found

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | CRITICAL | `scripts/core/scene_factory.gd:2` | `class_name SceneFactory` conflicts with autoload singleton name |
| 2 | CRITICAL | `scenes/towers/tower_shooter.tscn` | File missing (exists in `scenes/backup/`) |
| 3 | WARNING  | `scripts/entities/enemy.gd:91` | Unused parameter `slow_percent` in `remove_slow()` |

---

### Task 1: Remove class_name from SceneFactory (fixes startup crash)

**Files:**
- Modify: `scripts/core/scene_factory.gd:2`

**Step 1: Remove the class_name declaration**

In `scripts/core/scene_factory.gd`, remove line 2 (`class_name SceneFactory`). The script is already registered as an autoload singleton named `SceneFactory` in `project.godot`, so the `class_name` is redundant and causes the error:

```
Parser Error: Class "SceneFactory" hides an autoload singleton.
```

The file should start with:
```gdscript
extends Node

# Scene preloads - centralized
```

**Step 2: Verify no code depends on SceneFactory as a class_name**

Search the codebase for `SceneFactory` usage. All usages are as an autoload singleton (e.g., `SceneFactory.create_tower()`), which will continue to work after removing `class_name`.

---

### Task 2: Restore tower_shooter.tscn to correct location

**Files:**
- Copy: `scenes/backup/tower_shooter.tscn` -> `scenes/towers/tower_shooter.tscn`

**Step 1: Copy the backup file**

```bash
cp scenes/backup/tower_shooter.tscn scenes/towers/tower_shooter.tscn
```

The backup file correctly references `res://scripts/entities/towers/tower_shooter.gd` and has the proper node structure (StaticBody2D with DetectArea and ShootTimer).

**Step 2: Verify the tower_shooter.gd script exists**

The script at `scripts/entities/towers/tower_shooter.gd` already exists and is correct. It extends `Tower`, reads config from `GameConfig.TOWERS["shooter"]`, and implements shooting logic.

---

### Task 3: Fix unused parameter warning in enemy.gd

**Files:**
- Modify: `scripts/entities/enemy.gd:91`

**Step 1: Prefix unused parameter with underscore**

Change line 91 from:
```gdscript
func remove_slow(slow_percent: float):
```
to:
```gdscript
func remove_slow(_slow_percent: float):
```

The function resets speed to `base_speed` regardless of the slow percent value, so the parameter is intentionally unused.

---

### Task 4: Run project and verify startup

**Step 1: Run the project using gdai-mcp**

Use `run_project` tool to launch the project. Verify:
- No parser errors
- Start menu loads correctly
- No crash on startup

**Step 2: Check debug output**

Use `get_debug_output` to confirm no errors appear.

---

### Task 5: Test complete game flow

**Step 1: Verify scene flow manually**

Test each transition in the flow:
```
start_menu -> character_selection -> weapon_select -> map_select -> placement -> main (battle)
```

At minimum, verify the project starts without errors and the initial scenes load.

**Step 2: Commit fixes**

```bash
git add scripts/core/scene_factory.gd scenes/towers/tower_shooter.tscn scripts/entities/enemy.gd
git commit -m "fix: resolve startup crash and missing scene

- Remove class_name SceneFactory that conflicts with autoload singleton
- Restore tower_shooter.tscn from backup to scenes/towers/
- Fix unused parameter warning in enemy.gd remove_slow()"
```
