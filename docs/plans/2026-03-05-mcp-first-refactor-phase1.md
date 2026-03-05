# Phase 1: Foundation - Implementation Plan

> **For Claude:** Execute tasks sequentially. Each task has bite-sized steps (2-5 minutes each).

**Goal:** Establish GUT testing framework, create SceneFactory, write development rules, reorganize directory structure

**Estimated Time:** ~4 hours

---

## Task 1: Install GUT Testing Framework

**Files:**
- Create: `addons/gut/` (via git or download)
- Modify: `project.godot` (enable plugin)

### Step 1: Download GUT plugin

Visit: https://github.com/bitwes/Gut/releases
Download latest release (v9.x recommended)

### Step 2: Extract to addons/

```bash
cd /Users/langtao/utoland
mkdir -p addons
# Extract gut-9.x.x.zip to addons/gut/
```

### Step 3: Enable plugin in Godot

Open Godot Editor → Project → Project Settings → Plugins → Enable "Gut"

### Step 4: Create test directory structure

```bash
mkdir -p tests/unit
mkdir -p tests/integration
```

### Step 5: Create GUT configuration

Create `.gutconfig.json`:

```json
{
  "dirs": ["res://tests/unit/", "res://tests/integration/"],
  "include_subdirs": true,
  "log_level": 1,
  "should_maximize": true
}
```

### Step 6: Verify GUT works

Run in Godot: Tools → Gut → Run All Tests
Expected: "No tests found" (but GUT runs successfully)

### Step 7: Commit

```bash
git add addons/gut/ tests/ .gutconfig.json project.godot
git commit -m "feat: install GUT testing framework"
```

---

## Task 2: Create Directory Structure

**Files:**
- Create: `scripts/core/`, `scripts/entities/`, `scripts/systems/`, `scripts/ui/`
- Create: `scripts/entities/towers/`

### Step 1: Create new directories

```bash
cd /Users/langtao/utoland
mkdir -p scripts/core
mkdir -p scripts/entities/towers
mkdir -p scripts/systems
mkdir -p scripts/ui
```

### Step 2: Move game_data.gd to core

```bash
git mv scripts/game_data.gd scripts/core/game_data.gd
```

### Step 3: Move entity scripts

```bash
git mv scripts/player.gd scripts/entities/player.gd
git mv scripts/enemy.gd scripts/entities/enemy.gd
git mv scripts/bullet.gd scripts/entities/bullet.gd
git mv scripts/coin.gd scripts/entities/coin.gd
git mv scripts/tower.gd scripts/entities/towers/tower.gd
git mv scripts/tower_shooter.gd scripts/entities/towers/tower_shooter.gd
git mv scripts/tower_slow.gd scripts/entities/towers/tower_slow.gd
```

### Step 4: Move system scripts

```bash
git mv scripts/wave_manager.gd scripts/systems/wave_manager.gd
git mv scripts/enemy_spawner.gd scripts/systems/enemy_spawner.gd
git mv scripts/shop_manager.gd scripts/systems/shop_manager.gd
```

### Step 5: Move UI scripts

```bash
git mv scripts/start_menu.gd scripts/ui/start_menu.gd
git mv scripts/character_selection.gd scripts/ui/character_selection.gd
git mv scripts/weapon_select.gd scripts/ui/weapon_select.gd
git mv scripts/map_select.gd scripts/ui/map_select.gd
git mv scripts/placement.gd scripts/ui/placement.gd
git mv scripts/main.gd scripts/ui/main.gd
git mv scripts/hud.gd scripts/ui/hud.gd
git mv scripts/result.gd scripts/ui/result.gd
```

### Step 6: Update project.godot autoload path

Modify `project.godot`:

```ini
[autoload]
GameData="*res://scripts/core/game_data.gd"
GameConfig="*res://game_config.gd"
```

### Step 7: Commit

```bash
git add -A
git commit -m "refactor: reorganize scripts directory structure"
```

---

## Task 3: Update Scene Script Paths

**Files:**
- Modify: All `.tscn` files that reference moved scripts

### Step 1: Find all scenes with script references

```bash
grep -r "res://scripts/" scenes/
```

### Step 2: Update player.tscn

Use MCP tool:
```
mcp__gdai-mcp__open_scene("res://scenes/player.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/entities/player.gd")
```

### Step 3: Update enemy scenes

```
mcp__gdai-mcp__open_scene("res://scenes/enemies/enemy_normal.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/entities/enemy.gd")

mcp__gdai-mcp__open_scene("res://scenes/enemies/enemy_fast.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/entities/enemy.gd")

mcp__gdai-mcp__open_scene("res://scenes/enemies/enemy_tank.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/entities/enemy.gd")
```

### Step 4: Update tower scenes

```
mcp__gdai-mcp__open_scene("res://scenes/towers/tower_shooter.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/entities/towers/tower_shooter.gd")

mcp__gdai-mcp__open_scene("res://scenes/towers/tower_wall.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/entities/towers/tower.gd")

mcp__gdai-mcp__open_scene("res://scenes/towers/tower_slow.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/entities/towers/tower_slow.gd")
```

### Step 5: Update bullet and coin scenes

```
mcp__gdai-mcp__open_scene("res://scenes/bullet.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/entities/bullet.gd")

mcp__gdai-mcp__open_scene("res://scenes/coin.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/entities/coin.gd")
```

### Step 6: Update UI scenes

```
mcp__gdai-mcp__open_scene("res://scenes/main.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/ui/main.gd")

mcp__gdai-mcp__open_scene("res://scenes/placement.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/ui/placement.gd")

mcp__gdai-mcp__open_scene("res://scenes/ui/hud.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/ui/hud.gd")

mcp__gdai-mcp__open_scene("res://scenes/ui/start_menu.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/ui/start_menu.gd")

mcp__gdai-mcp__open_scene("res://scenes/character_selection.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/ui/character_selection.gd")

mcp__gdai-mcp__open_scene("res://scenes/ui/weapon_select.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/ui/weapon_select.gd")

mcp__gdai-mcp__open_scene("res://scenes/ui/map_select.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/ui/map_select.gd")

mcp__gdai-mcp__open_scene("res://scenes/ui/shop.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/systems/shop_manager.gd")

mcp__gdai-mcp__open_scene("res://scenes/ui/result.tscn")
mcp__gdai-mcp__update_property(".", "script", "res://scripts/ui/result.gd")
```

### Step 7: Verify game still runs

Run game in Godot: F5
Expected: Game loads without errors

### Step 8: Commit

```bash
git add scenes/
git commit -m "refactor: update scene script paths to new structure"
```

---

## Task 4: Create SceneFactory.gd

**Files:**
- Create: `scripts/core/scene_factory.gd`

### Step 1: Create SceneFactory skeleton

```gdscript
extends Node
class_name SceneFactory

# Scene preloads - centralized
static var _tower_scenes = {
	"shooter": preload("res://scenes/towers/tower_shooter.tscn"),
	"wall": preload("res://scenes/towers/tower_wall.tscn"),
	"slow": preload("res://scenes/towers/tower_slow.tscn")
}

static var _enemy_scenes = {
	"normal": preload("res://scenes/enemies/enemy_normal.tscn"),
	"fast": preload("res://scenes/enemies/enemy_fast.tscn"),
	"tank": preload("res://scenes/enemies/enemy_tank.tscn")
}

static var _bullet_scene = preload("res://scenes/bullet.tscn")
static var _coin_scene = preload("res://scenes/coin.tscn")
```

### Step 2: Add tower creation methods

```gdscript
# Tower creation
static func create_tower(type: String) -> Node2D:
	if not _tower_scenes.has(type):
		push_error("Unknown tower type: " + type)
		return null

	var tower = _tower_scenes[type].instantiate()
	var config = GameConfig.TOWERS[type]

	# Apply config
	tower.tower_type = type
	tower.max_hp = config["hp"]

	# Type-specific config
	if type == "shooter":
		tower.damage = config["damage"]
		tower.fire_rate = config["fire_rate"]
		tower.range = config["range"]
	elif type == "slow":
		tower.range = config["range"]
		tower.slow_percent = config["slow_percent"]

	return tower

static func get_tower_cost(type: String) -> int:
	if not GameConfig.TOWERS.has(type):
		push_error("Unknown tower type: " + type)
		return 0

	var config = GameConfig.TOWERS[type]
	return randi_range(config["shop_price_min"], config["shop_price_max"])
```

### Step 3: Add enemy creation methods

```gdscript
# Enemy creation
static func create_enemy(type: String) -> CharacterBody2D:
	if not _enemy_scenes.has(type):
		push_error("Unknown enemy type: " + type)
		return null

	var enemy = _enemy_scenes[type].instantiate()
	enemy.enemy_type = type
	# Config is applied in enemy._ready()

	return enemy
```

### Step 4: Add bullet and coin creation

```gdscript
# Bullet creation
static func create_bullet() -> Area2D:
	return _bullet_scene.instantiate()

# Coin creation
static func create_coin() -> Area2D:
	return _coin_scene.instantiate()
```

### Step 5: Save file

Save to: `scripts/core/scene_factory.gd`

### Step 6: Add to project.godot as autoload

Modify `project.godot`:

```ini
[autoload]
GameData="*res://scripts/core/game_data.gd"
GameConfig="*res://game_config.gd"
SceneFactory="*res://scripts/core/scene_factory.gd"
```

### Step 7: Commit

```bash
git add scripts/core/scene_factory.gd project.godot
git commit -m "feat: create SceneFactory for centralized scene instantiation"
```

---

## Task 5: Write Unit Tests for SceneFactory

**Files:**
- Create: `tests/unit/test_scene_factory.gd`

### Step 1: Create test file skeleton

```gdscript
extends GutTest

func before_each():
	# Setup runs before each test
	pass

func after_each():
	# Cleanup runs after each test
	pass
```

### Step 2: Write tower creation tests

```gdscript
func test_create_tower_shooter():
	var tower = SceneFactory.create_tower("shooter")
	assert_not_null(tower, "Tower should be created")
	assert_eq(tower.tower_type, "shooter", "Tower type should be shooter")
	assert_eq(tower.max_hp, GameConfig.TOWERS["shooter"]["hp"], "HP should match config")
	tower.queue_free()

func test_create_tower_wall():
	var tower = SceneFactory.create_tower("wall")
	assert_not_null(tower, "Tower should be created")
	assert_eq(tower.tower_type, "wall", "Tower type should be wall")
	assert_eq(tower.max_hp, GameConfig.TOWERS["wall"]["hp"], "HP should match config")
	tower.queue_free()

func test_create_tower_slow():
	var tower = SceneFactory.create_tower("slow")
	assert_not_null(tower, "Tower should be created")
	assert_eq(tower.tower_type, "slow", "Tower type should be slow")
	assert_eq(tower.max_hp, GameConfig.TOWERS["slow"]["hp"], "HP should match config")
	tower.queue_free()

func test_create_tower_invalid():
	var tower = SceneFactory.create_tower("invalid")
	assert_null(tower, "Invalid tower type should return null")
```

### Step 3: Write enemy creation tests

```gdscript
func test_create_enemy_normal():
	var enemy = SceneFactory.create_enemy("normal")
	assert_not_null(enemy, "Enemy should be created")
	assert_eq(enemy.enemy_type, "normal", "Enemy type should be normal")
	enemy.queue_free()

func test_create_enemy_fast():
	var enemy = SceneFactory.create_enemy("fast")
	assert_not_null(enemy, "Enemy should be created")
	assert_eq(enemy.enemy_type, "fast", "Enemy type should be fast")
	enemy.queue_free()

func test_create_enemy_tank():
	var enemy = SceneFactory.create_enemy("tank")
	assert_not_null(enemy, "Enemy should be created")
	assert_eq(enemy.enemy_type, "tank", "Enemy type should be tank")
	enemy.queue_free()
```

### Step 4: Write bullet and coin tests

```gdscript
func test_create_bullet():
	var bullet = SceneFactory.create_bullet()
	assert_not_null(bullet, "Bullet should be created")
	bullet.queue_free()

func test_create_coin():
	var coin = SceneFactory.create_coin()
	assert_not_null(coin, "Coin should be created")
	coin.queue_free()
```

### Step 5: Write tower cost test

```gdscript
func test_get_tower_cost():
	var cost = SceneFactory.get_tower_cost("shooter")
	var min_cost = GameConfig.TOWERS["shooter"]["shop_price_min"]
	var max_cost = GameConfig.TOWERS["shooter"]["shop_price_max"]
	assert_true(cost >= min_cost and cost <= max_cost, "Cost should be in range")
```

### Step 6: Run tests

In Godot: Tools → Gut → Run All Tests
Expected: All tests pass

### Step 7: Commit

```bash
git add tests/unit/test_scene_factory.gd
git commit -m "test: add unit tests for SceneFactory"
```

---

## Task 6: Write Development Rules Documentation

**Files:**
- Create: `.claude/rules/mcp-only.md`
- Create: `.claude/rules/no-hardcode.md`
- Create: `.claude/rules/scene-factory.md`
- Create: `.claude/rules/testing.md`

### Step 1: Create rules directory

```bash
mkdir -p .claude/rules
```

### Step 2: Write mcp-only.md

```markdown
# Rule: MCP-Only Scene Modifications

## Principle
Never manually edit .tscn files. All scene changes go through MCP tools.

## Workflow

### Adding a Node
Use: `mcp__gdai-mcp__add_node`

Example:
```
mcp__gdai-mcp__add_node("ParentNode", "Sprite2D", "MySprite")
```

### Changing a Property
Use: `mcp__gdai-mcp__update_property`

Example:
```
mcp__gdai-mcp__update_property("MySprite", "texture", "res://assets/sprite.png")
```

### Deleting a Node
Use: `mcp__gdai-mcp__delete_node`

Example:
```
mcp__gdai-mcp__delete_node("MySprite")
```

## Why This Matters
- Consistent, reproducible modifications
- AI-friendly (Claude can use MCP tools)
- Easier code review (GDScript diffs vs .tscn noise)
- Prevents merge conflicts

## Enforcement
- Pre-commit hook checks for manual .tscn edits
- Code review checklist includes MCP verification
```

### Step 3: Write no-hardcode.md

```markdown
# Rule: Zero Hardcoded Values

## Principle
All game values must come from GameConfig.

## What Counts as Hardcoded

### ❌ Bad Examples
```gdscript
if coins < 30:  # Magic number
var tower_costs = {"shooter": 30}  # Duplicate data
var path = "res://scenes/towers/tower_shooter.tscn"  # String literal
```

### ✅ Good Examples
```gdscript
if coins < GameConfig.TOWERS["shooter"]["shop_price_min"]:
var cost = SceneFactory.get_tower_cost("shooter")
var tower = SceneFactory.create_tower("shooter")
```

## Why This Matters
- Single source of truth
- Easy to balance gameplay
- Config changes don't require code changes
- Prevents inconsistencies

## Verification
Run: `grep -r "[0-9]\{2,\}" scripts/` to find magic numbers
```

### Step 4: Write scene-factory.md

```markdown
# Rule: Scene Factory Pattern

## Principle
All scene instantiation goes through SceneFactory.

## SceneFactory Responsibilities
- Centralized preload() calls
- Apply GameConfig at instantiation
- Validate scene types
- Provide type-safe creation methods

## Usage Examples

### Creating a Tower
```gdscript
var tower = SceneFactory.create_tower("shooter")
add_child(tower)
```

### Getting Tower Cost
```gdscript
var cost = SceneFactory.get_tower_cost("shooter")
if GameData.coins >= cost:
    # Purchase logic
```

### Creating an Enemy
```gdscript
var enemy = SceneFactory.create_enemy("normal")
add_child(enemy)
```

## Anti-Patterns to Avoid

### ❌ Don't Do This
```gdscript
var tower_scene = preload("res://scenes/towers/tower_shooter.tscn")
var tower = tower_scene.instantiate()
```

### ✅ Do This Instead
```gdscript
var tower = SceneFactory.create_tower("shooter")
```

## Why This Matters
- Single place to manage scene creation
- Config always applied correctly
- Easier to refactor paths
- Type safety and validation
```

### Step 5: Write testing.md

```markdown
# Rule: Testing Requirements

## Principle
Core systems must have automated tests.

## What Needs Tests

### ✅ Must Test
- SceneFactory - all creation methods
- GameConfig - validation logic
- GameData - state transitions
- Game systems - critical paths (placement, waves, shop)

### ⏸️ Don't Test (Yet)
- UI controllers (hard to test, low value)
- Visual/animation logic
- One-off utility functions

## Test Structure

### Unit Tests
Test individual components in isolation.

Location: `tests/unit/`

Example:
```gdscript
extends GutTest

func test_create_tower():
    var tower = SceneFactory.create_tower("shooter")
    assert_not_null(tower)
    assert_eq(tower.max_hp, GameConfig.TOWERS["shooter"]["hp"])
    tower.queue_free()
```

### Integration Tests
Test system interactions.

Location: `tests/integration/`

Example:
```gdscript
extends GutTest

func test_tower_placement():
    # Test placement logic + collision detection
    pass
```

## Running Tests

### All Tests
```bash
# In Godot: Tools → Gut → Run All Tests
```

### Specific Test
```bash
# In Godot: Tools → Gut → Select Test → Run
```

## Why This Matters
- Catch regressions early
- Confidence when refactoring
- Documentation of expected behavior
- Faster development long-term
```

### Step 6: Commit

```bash
git add .claude/rules/
git commit -m "docs: add development rules documentation"
```

---

## Phase 1 Validation

### Checklist

- [ ] GUT framework installed and working
- [ ] Directory structure reorganized (core/entities/systems/ui)
- [ ] All scene script paths updated
- [ ] SceneFactory.gd created with all methods
- [ ] SceneFactory added as autoload
- [ ] Unit tests written and passing
- [ ] Development rules documented

### Verification Commands

```bash
# Run tests
# In Godot: Tools → Gut → Run All Tests
# Expected: All tests pass

# Verify no hardcoded paths in scripts
grep -r "preload.*scenes" scripts/
# Expected: Only in SceneFactory

# Run game
# In Godot: Press F5
# Expected: Game loads without errors
```

### Manual Test

1. Start game
2. Select character
3. Select weapon
4. Select map
5. Verify placement scene loads

Expected: No errors, game works as before

---

## Commit Phase 1 Completion

```bash
git add -A
git commit -m "feat: complete Phase 1 - Foundation

- Installed GUT testing framework
- Reorganized scripts directory structure
- Created SceneFactory for centralized instantiation
- Added unit tests for SceneFactory
- Documented development rules"
```

---

**Phase 1 Complete!**

Next: Read `2026-03-05-mcp-first-refactor-phase2.md` for Phase 2 tasks.
