# Phase 3: Scene Reconstruction - Implementation Plan

> **For Claude:** Execute tasks sequentially. Use MCP tools exclusively for scene modifications.

**Goal:** Rebuild key scenes using MCP tools only, establishing MCP-first workflow

**Estimated Time:** ~3 hours

---

## Task 1: Document Current Scene Structures

**Files:**
- Create: `docs/scene-structures.md`

### Step 1: Document tower_shooter.tscn structure

Use MCP tool to inspect:
```
mcp__gdai-mcp__open_scene("res://scenes/towers/tower_shooter.tscn")
mcp__gdai-mcp__get_scene_tree()
```

Document the output:
```markdown
## tower_shooter.tscn

Root: StaticBody2D (script: tower_shooter.gd)
├── CollisionShape2D
├── Sprite2D
└── ShootTimer (Timer)

Properties:
- collision_layer: 2
- collision_mask: 1
```

### Step 2: Document tower_wall.tscn structure

```
mcp__gdai-mcp__open_scene("res://scenes/towers/tower_wall.tscn")
mcp__gdai-mcp__get_scene_tree()
```

Document the output

### Step 3: Document tower_slow.tscn structure

```
mcp__gdai-mcp__open_scene("res://scenes/towers/tower_slow.tscn")
mcp__gdai-mcp__get_scene_tree()
```

Document the output

### Step 4: Document enemy scenes structure

For each enemy type (normal, fast, tank):
```
mcp__gdai-mcp__open_scene("res://scenes/enemies/enemy_normal.tscn")
mcp__gdai-mcp__get_scene_tree()
```

Document the output

### Step 5: Save documentation

Save to: `docs/scene-structures.md`

### Step 6: Commit

```bash
git add docs/scene-structures.md
git commit -m "docs: document current scene structures before reconstruction"
```

---

## Task 2: Backup Current Scenes

**Files:**
- Create: `scenes/backup/` directory

### Step 1: Create backup directory

```bash
mkdir -p scenes/backup
```

### Step 2: Copy tower scenes

```bash
cp scenes/towers/tower_shooter.tscn scenes/backup/
cp scenes/towers/tower_wall.tscn scenes/backup/
cp scenes/towers/tower_slow.tscn scenes/backup/
```

### Step 3: Copy enemy scenes

```bash
cp scenes/enemies/enemy_normal.tscn scenes/backup/
cp scenes/enemies/enemy_fast.tscn scenes/backup/
cp scenes/enemies/enemy_tank.tscn scenes/backup/
```

### Step 4: Commit backup

```bash
git add scenes/backup/
git commit -m "backup: save current scenes before MCP reconstruction"
```

---

## Task 3: Reconstruct tower_shooter.tscn

**Files:**
- Modify: `scenes/towers/tower_shooter.tscn`

### Step 1: Delete current scene

```bash
rm scenes/towers/tower_shooter.tscn
```

### Step 2: Create new scene with MCP

```
mcp__gdai-mcp__create_scene("res://scenes/towers/tower_shooter.tscn", "StaticBody2D")
```

### Step 3: Attach script

```
mcp__gdai-mcp__open_scene("res://scenes/towers/tower_shooter.tscn")
mcp__gdai-mcp__attach_script(".", "res://scripts/entities/towers/tower_shooter.gd")
```

### Step 4: Add CollisionShape2D

```
mcp__gdai-mcp__add_node(".", "CollisionShape2D", "CollisionShape2D")
```

### Step 5: Add Sprite2D

```
mcp__gdai-mcp__add_node(".", "Sprite2D", "Sprite2D")
```

### Step 6: Add ShootTimer

```
mcp__gdai-mcp__add_node(".", "Timer", "ShootTimer")
```

### Step 7: Set collision properties

```
mcp__gdai-mcp__update_property(".", "collision_layer", 2)
mcp__gdai-mcp__update_property(".", "collision_mask", 1)
```

### Step 8: Test scene loads

In Godot: Open scene manually
Expected: Scene loads without errors

### Step 9: Commit

```bash
git add scenes/towers/tower_shooter.tscn
git commit -m "refactor: reconstruct tower_shooter.tscn using MCP tools"
```

---

## Task 4: Reconstruct tower_wall.tscn

**Files:**
- Modify: `scenes/towers/tower_wall.tscn`

### Step 1: Delete current scene

```bash
rm scenes/towers/tower_wall.tscn
```

### Step 2: Create new scene with MCP

```
mcp__gdai-mcp__create_scene("res://scenes/towers/tower_wall.tscn", "StaticBody2D")
```

### Step 3: Attach script

```
mcp__gdai-mcp__open_scene("res://scenes/towers/tower_wall.tscn")
mcp__gdai-mcp__attach_script(".", "res://scripts/entities/towers/tower.gd")
```

### Step 4: Add CollisionShape2D

```
mcp__gdai-mcp__add_node(".", "CollisionShape2D", "CollisionShape2D")
```

### Step 5: Add Sprite2D

```
mcp__gdai-mcp__add_node(".", "Sprite2D", "Sprite2D")
```

### Step 6: Set collision properties

```
mcp__gdai-mcp__update_property(".", "collision_layer", 2)
mcp__gdai-mcp__update_property(".", "collision_mask", 1)
```

### Step 7: Test scene loads

In Godot: Open scene manually
Expected: Scene loads without errors

### Step 8: Commit

```bash
git add scenes/towers/tower_wall.tscn
git commit -m "refactor: reconstruct tower_wall.tscn using MCP tools"
```

---

## Task 5: Reconstruct tower_slow.tscn

**Files:**
- Modify: `scenes/towers/tower_slow.tscn`

### Step 1: Delete current scene

```bash
rm scenes/towers/tower_slow.tscn
```

### Step 2: Create new scene with MCP

```
mcp__gdai-mcp__create_scene("res://scenes/towers/tower_slow.tscn", "StaticBody2D")
```

### Step 3: Attach script

```
mcp__gdai-mcp__open_scene("res://scenes/towers/tower_slow.tscn")
mcp__gdai-mcp__attach_script(".", "res://scripts/entities/towers/tower_slow.gd")
```

### Step 4: Add CollisionShape2D

```
mcp__gdai-mcp__add_node(".", "CollisionShape2D", "CollisionShape2D")
```

### Step 5: Add Sprite2D

```
mcp__gdai-mcp__add_node(".", "Sprite2D", "Sprite2D")
```

### Step 6: Add Area2D for slow effect

```
mcp__gdai-mcp__add_node(".", "Area2D", "SlowArea")
mcp__gdai-mcp__add_node("SlowArea", "CollisionShape2D", "CollisionShape2D")
```

### Step 7: Set collision properties

```
mcp__gdai-mcp__update_property(".", "collision_layer", 2)
mcp__gdai-mcp__update_property(".", "collision_mask", 1)
```

### Step 8: Test scene loads

In Godot: Open scene manually
Expected: Scene loads without errors

### Step 9: Commit

```bash
git add scenes/towers/tower_slow.tscn
git commit -m "refactor: reconstruct tower_slow.tscn using MCP tools"
```

---

## Task 6: Reconstruct enemy_normal.tscn

**Files:**
- Modify: `scenes/enemies/enemy_normal.tscn`

### Step 1: Delete current scene

```bash
rm scenes/enemies/enemy_normal.tscn
```

### Step 2: Create new scene with MCP

```
mcp__gdai-mcp__create_scene("res://scenes/enemies/enemy_normal.tscn", "CharacterBody2D")
```

### Step 3: Attach script

```
mcp__gdai-mcp__open_scene("res://scenes/enemies/enemy_normal.tscn")
mcp__gdai-mcp__attach_script(".", "res://scripts/entities/enemy.gd")
```

### Step 4: Add CollisionShape2D

```
mcp__gdai-mcp__add_node(".", "CollisionShape2D", "CollisionShape2D")
```

### Step 5: Add Sprite2D

```
mcp__gdai-mcp__add_node(".", "Sprite2D", "Sprite2D")
```

### Step 6: Set collision properties

```
mcp__gdai-mcp__update_property(".", "collision_layer", 1)
mcp__gdai-mcp__update_property(".", "collision_mask", 2)
```

### Step 7: Test scene loads

In Godot: Open scene manually
Expected: Scene loads without errors

### Step 8: Commit

```bash
git add scenes/enemies/enemy_normal.tscn
git commit -m "refactor: reconstruct enemy_normal.tscn using MCP tools"
```

---

## Task 7: Reconstruct enemy_fast.tscn

**Files:**
- Modify: `scenes/enemies/enemy_fast.tscn`

### Step 1: Delete current scene

```bash
rm scenes/enemies/enemy_fast.tscn
```

### Step 2: Create new scene with MCP

```
mcp__gdai-mcp__create_scene("res://scenes/enemies/enemy_fast.tscn", "CharacterBody2D")
```

### Step 3: Attach script

```
mcp__gdai-mcp__open_scene("res://scenes/enemies/enemy_fast.tscn")
mcp__gdai-mcp__attach_script(".", "res://scripts/entities/enemy.gd")
```

### Step 4: Add CollisionShape2D

```
mcp__gdai-mcp__add_node(".", "CollisionShape2D", "CollisionShape2D")
```

### Step 5: Add Sprite2D

```
mcp__gdai-mcp__add_node(".", "Sprite2D", "Sprite2D")
```

### Step 6: Set collision properties

```
mcp__gdai-mcp__update_property(".", "collision_layer", 1)
mcp__gdai-mcp__update_property(".", "collision_mask", 2)
```

### Step 7: Test scene loads

In Godot: Open scene manually
Expected: Scene loads without errors

### Step 8: Commit

```bash
git add scenes/enemies/enemy_fast.tscn
git commit -m "refactor: reconstruct enemy_fast.tscn using MCP tools"
```

---

## Task 8: Reconstruct enemy_tank.tscn

**Files:**
- Modify: `scenes/enemies/enemy_tank.tscn`

### Step 1: Delete current scene

```bash
rm scenes/enemies/enemy_tank.tscn
```

### Step 2: Create new scene with MCP

```
mcp__gdai-mcp__create_scene("res://scenes/enemies/enemy_tank.tscn", "CharacterBody2D")
```

### Step 3: Attach script

```
mcp__gdai-mcp__open_scene("res://scenes/enemies/enemy_tank.tscn")
mcp__gdai-mcp__attach_script(".", "res://scripts/entities/enemy.gd")
```

### Step 4: Add CollisionShape2D

```
mcp__gdai-mcp__add_node(".", "CollisionShape2D", "CollisionShape2D")
```

### Step 5: Add Sprite2D

```
mcp__gdai-mcp__add_node(".", "Sprite2D", "Sprite2D")
```

### Step 6: Set collision properties

```
mcp__gdai-mcp__update_property(".", "collision_layer", 1)
mcp__gdai-mcp__update_property(".", "collision_mask", 2)
```

### Step 7: Test scene loads

In Godot: Open scene manually
Expected: Scene loads without errors

### Step 8: Commit

```bash
git add scenes/enemies/enemy_tank.tscn
git commit -m "refactor: reconstruct enemy_tank.tscn using MCP tools"
```

---

## Task 9: Add Regression Tests

**Files:**
- Create: `tests/integration/test_scene_reconstruction.gd`

### Step 1: Create test file

```gdscript
extends GutTest

func test_tower_scenes_load():
	var shooter = load("res://scenes/towers/tower_shooter.tscn")
	assert_not_null(shooter, "tower_shooter.tscn should load")

	var wall = load("res://scenes/towers/tower_wall.tscn")
	assert_not_null(wall, "tower_wall.tscn should load")

	var slow = load("res://scenes/towers/tower_slow.tscn")
	assert_not_null(slow, "tower_slow.tscn should load")

func test_enemy_scenes_load():
	var normal = load("res://scenes/enemies/enemy_normal.tscn")
	assert_not_null(normal, "enemy_normal.tscn should load")

	var fast = load("res://scenes/enemies/enemy_fast.tscn")
	assert_not_null(fast, "enemy_fast.tscn should load")

	var tank = load("res://scenes/enemies/enemy_tank.tscn")
	assert_not_null(tank, "enemy_tank.tscn should load")

func test_tower_scenes_instantiate():
	var shooter = SceneFactory.create_tower("shooter")
	assert_not_null(shooter, "Shooter tower should instantiate")
	assert_true(shooter is StaticBody2D, "Should be StaticBody2D")
	shooter.queue_free()

	var wall = SceneFactory.create_tower("wall")
	assert_not_null(wall, "Wall tower should instantiate")
	wall.queue_free()

	var slow = SceneFactory.create_tower("slow")
	assert_not_null(slow, "Slow tower should instantiate")
	slow.queue_free()

func test_enemy_scenes_instantiate():
	var normal = SceneFactory.create_enemy("normal")
	assert_not_null(normal, "Normal enemy should instantiate")
	assert_true(normal is CharacterBody2D, "Should be CharacterBody2D")
	normal.queue_free()

	var fast = SceneFactory.create_enemy("fast")
	assert_not_null(fast, "Fast enemy should instantiate")
	fast.queue_free()

	var tank = SceneFactory.create_enemy("tank")
	assert_not_null(tank, "Tank enemy should instantiate")
	tank.queue_free()

func test_reconstructed_scenes_have_scripts():
	var shooter = SceneFactory.create_tower("shooter")
	assert_not_null(shooter.get_script(), "Shooter should have script")
	shooter.queue_free()

	var enemy = SceneFactory.create_enemy("normal")
	assert_not_null(enemy.get_script(), "Enemy should have script")
	enemy.queue_free()
```

### Step 2: Run tests

In Godot: Tools → Gut → Run All Tests
Expected: All tests pass

### Step 3: Commit

```bash
git add tests/integration/test_scene_reconstruction.gd
git commit -m "test: add regression tests for reconstructed scenes"
```

---

## Task 10: Full Game Test with Reconstructed Scenes

**Manual Testing Checklist:**

### Step 1: Test tower placement

In Godot: F5 → Character → Weapon → Map → Placement
- Place shooter tower
- Place wall tower
- Place slow tower
- Verify visuals appear correctly
- Start battle

### Step 2: Test combat with towers

- Verify shooter tower shoots
- Verify wall tower blocks enemies
- Verify slow tower slows enemies
- Verify towers take damage

### Step 3: Test enemy spawning

- Verify normal enemies spawn
- Verify fast enemies spawn
- Verify tank enemies spawn
- Verify enemies have correct behavior

### Step 4: Complete wave

- Survive full wave
- Verify coins drop
- Enter shop

### Step 5: Test second wave

- Purchase tower in shop
- Return to placement
- Verify previous towers still there
- Start second wave
- Verify all systems work

### Step 6: Document results

```
✅ Tower scenes load correctly
✅ Enemy scenes load correctly
✅ Towers function identically to before
✅ Enemies function identically to before
✅ No visual regressions
✅ No gameplay regressions
✅ MCP-created scenes work perfectly
```

---

## Task 11: Verify Git History Shows MCP Usage

**Files:**
- Git commit history

### Step 1: Check git log

```bash
git log --oneline --grep="MCP" -10
```

Expected: Multiple commits mentioning MCP tools

### Step 2: Check commit messages

```bash
git log --oneline -10
```

Expected: Commits like "reconstruct X using MCP tools"

### Step 3: Verify no manual .tscn edits

```bash
git diff HEAD~10 scenes/towers/tower_shooter.tscn
```

Expected: Changes show MCP-style modifications (clean, structured)

### Step 4: Document MCP usage

Create summary:
```
MCP Tools Used:
- mcp__gdai-mcp__create_scene: 6 times
- mcp__gdai-mcp__attach_script: 6 times
- mcp__gdai-mcp__add_node: 18+ times
- mcp__gdai-mcp__update_property: 12+ times
- mcp__gdai-mcp__open_scene: 6 times
```

---

## Phase 3 Validation

### Checklist

- [ ] Current scene structures documented
- [ ] Backup scenes created
- [ ] tower_shooter.tscn reconstructed via MCP
- [ ] tower_wall.tscn reconstructed via MCP
- [ ] tower_slow.tscn reconstructed via MCP
- [ ] enemy_normal.tscn reconstructed via MCP
- [ ] enemy_fast.tscn reconstructed via MCP
- [ ] enemy_tank.tscn reconstructed via MCP
- [ ] Regression tests added and passing
- [ ] Full game test successful
- [ ] Git history shows MCP usage

### Verification Commands

```bash
# Verify all scenes load
ls -la scenes/towers/
ls -la scenes/enemies/

# Run all tests
# In Godot: Tools → Gut → Run All Tests
# Expected: All tests pass

# Check git history
git log --oneline -10
# Expected: MCP reconstruction commits
```

---

## Commit Phase 3 Completion

```bash
git add -A
git commit -m "feat: complete Phase 3 - Scene Reconstruction

- Documented current scene structures
- Backed up original scenes
- Reconstructed all tower scenes using MCP tools
- Reconstructed all enemy scenes using MCP tools
- Added regression tests
- Verified identical functionality
- Established MCP-first workflow"
```

---

**Phase 3 Complete!**

Next: Read `2026-03-05-mcp-first-refactor-phase4.md` for Phase 4 tasks.
