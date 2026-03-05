# Phase 2: Refactor Existing Code - Implementation Plan

> **For Claude:** Execute tasks sequentially. Each task has bite-sized steps (2-5 minutes each).

**Goal:** Eliminate hardcoded values, refactor all code to use SceneFactory, ensure zero technical debt

**Estimated Time:** ~6 hours

---

## Task 1: Refactor placement.gd

**Files:**
- Modify: `scripts/ui/placement.gd`

### Step 1: Remove hardcoded tower_scenes dictionary

Delete lines 7-11:
```gdscript
var tower_scenes = {
	"shooter": preload("res://scenes/towers/tower_shooter.tscn"),
	"wall": preload("res://scenes/towers/tower_wall.tscn"),
	"slow": preload("res://scenes/towers/tower_slow.tscn")
}
```

### Step 2: Remove hardcoded tower_costs dictionary

Delete lines 12-16:
```gdscript
var tower_costs = {
	"shooter": 30,
	"wall": 40,
	"slow": 35
}
```

### Step 3: Refactor select_tower() to use SceneFactory

Replace lines 56-66:
```gdscript
func select_tower(type: String):
	var cost = SceneFactory.get_tower_cost(type)
	if GameData.coins < cost:
		return

	selected_tower_type = type
	if preview_tower:
		preview_tower.queue_free()

	preview_tower = SceneFactory.create_tower(type)
	preview_tower.modulate = Color(1, 1, 1, 0.5)
	add_child(preview_tower)
```

### Step 4: Refactor place_tower() to use SceneFactory

Replace line 72:
```gdscript
func place_tower():
	if not can_place_at(preview_tower.global_position):
		return

	var cost = SceneFactory.get_tower_cost(selected_tower_type)
	GameData.coins -= cost
	preview_tower.modulate = Color(1, 1, 1, 1)
	preview_tower.add_to_group("towers")
	preview_tower = null
	selected_tower_type = ""
	update_ui()
```

### Step 5: Refactor tower restoration in _ready()

Replace lines 22-30:
```gdscript
	# 恢复之前布置的塔
	for tower_data in GameData.tower_inventory:
		var tower_type = tower_data["type"]
		var tower_pos = tower_data["position"]

		var tower = SceneFactory.create_tower(tower_type)
		if tower:
			tower.global_position = tower_pos
			tower.add_to_group("towers")
			add_child(tower)
```

### Step 6: Refactor purchased towers conversion

Replace lines 33-35:
```gdscript
	# 将商店购买的塔添加到金币中（作为可用资源）
	for tower_type in GameData.purchased_towers:
		var cost = SceneFactory.get_tower_cost(tower_type)
		GameData.coins += cost
	GameData.purchased_towers.clear()
```

### Step 7: Refactor update_ui() button states

Replace lines 113-115:
```gdscript
func update_ui():
	$UI/CoinsLabel.text = "金币: %d" % GameData.coins

	# 更新按钮状态
	$UI/TowerButtons/ShooterButton.disabled = GameData.coins < SceneFactory.get_tower_cost("shooter")
	$UI/TowerButtons/WallButton.disabled = GameData.coins < SceneFactory.get_tower_cost("wall")
	$UI/TowerButtons/SlowButton.disabled = GameData.coins < SceneFactory.get_tower_cost("slow")
```

### Step 8: Verify no hardcoded values remain

```bash
grep -n "30\|40\|35" scripts/ui/placement.gd
# Expected: No matches (except in comments)
```

### Step 9: Run game to test placement

In Godot: F5 → Character → Weapon → Map → Placement
Expected: Tower selection and placement works correctly

### Step 10: Commit

```bash
git add scripts/ui/placement.gd
git commit -m "refactor: placement.gd uses SceneFactory, removes hardcoded values"
```

---

## Task 2: Refactor main.gd

**Files:**
- Modify: `scripts/ui/main.gd`

### Step 1: Remove hardcoded tower scene preloads

Replace lines 3-20 with SceneFactory usage:
```gdscript
func _ready():
	# 恢复布置的塔
	for tower_data in GameData.tower_inventory:
		var tower_type = tower_data["type"]
		var tower_pos = tower_data["position"]

		var tower = SceneFactory.create_tower(tower_type)
		if tower:
			tower.global_position = tower_pos
			add_child(tower)

	# 不再清空 tower_inventory，保留已布置的塔数据供下次布置场景使用
```

### Step 2: Verify no preload() calls remain

```bash
grep -n "preload" scripts/ui/main.gd
# Expected: No matches
```

### Step 3: Run game to test combat

In Godot: F5 → Character → Weapon → Map → Placement → Start Battle
Expected: Towers restored correctly in combat scene

### Step 4: Commit

```bash
git add scripts/ui/main.gd
git commit -m "refactor: main.gd uses SceneFactory for tower restoration"
```

---

## Task 3: Refactor enemy.gd

**Files:**
- Modify: `scripts/entities/enemy.gd`

### Step 1: Remove hardcoded coin scene preload

Replace line 78:
```gdscript
func drop_coins():
	var parent = get_parent()
	if not parent:
		return

	# 从配置读取金币掉落数量
	var enemy_data = GameConfig.ENEMIES[enemy_type]
	var coin_count = randi_range(enemy_data["coin_drop_min"], enemy_data["coin_drop_max"])
	for i in coin_count:
		var coin = SceneFactory.create_coin()
		coin.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		parent.call_deferred("add_child", coin)
```

### Step 2: Verify no preload() calls remain

```bash
grep -n "preload" scripts/entities/enemy.gd
# Expected: No matches
```

### Step 3: Run game to test coin drops

In Godot: F5 → Play until enemy dies
Expected: Coins drop correctly

### Step 4: Commit

```bash
git add scripts/entities/enemy.gd
git commit -m "refactor: enemy.gd uses SceneFactory for coin creation"
```

---

## Task 4: Refactor player.gd

**Files:**
- Modify: `scripts/entities/player.gd`

### Step 1: Read current player.gd

```bash
cat scripts/entities/player.gd
```

### Step 2: Find and replace bullet preload

Look for: `preload("res://scenes/bullet.tscn")`
Replace with: `SceneFactory.create_bullet()`

### Step 3: Update shoot() method

If there's a line like:
```gdscript
var bullet = bullet_scene.instantiate()
```

Replace with:
```gdscript
var bullet = SceneFactory.create_bullet()
```

### Step 4: Verify no preload() calls remain

```bash
grep -n "preload" scripts/entities/player.gd
# Expected: No matches
```

### Step 5: Run game to test shooting

In Godot: F5 → Play and shoot
Expected: Bullets fire correctly

### Step 6: Commit

```bash
git add scripts/entities/player.gd
git commit -m "refactor: player.gd uses SceneFactory for bullet creation"
```

---

## Task 5: Refactor tower_shooter.gd

**Files:**
- Modify: `scripts/entities/towers/tower_shooter.gd`

### Step 1: Read current tower_shooter.gd

```bash
cat scripts/entities/towers/tower_shooter.gd
```

### Step 2: Find and replace bullet preload

Look for: `preload("res://scenes/bullet.tscn")`
Replace with: `SceneFactory.create_bullet()`

### Step 3: Update shoot() method

If there's a line like:
```gdscript
var bullet = bullet_scene.instantiate()
```

Replace with:
```gdscript
var bullet = SceneFactory.create_bullet()
```

### Step 4: Verify no preload() calls remain

```bash
grep -n "preload" scripts/entities/towers/tower_shooter.gd
# Expected: No matches
```

### Step 5: Run game to test tower shooting

In Godot: F5 → Place shooter tower → Start battle
Expected: Tower shoots correctly

### Step 6: Commit

```bash
git add scripts/entities/towers/tower_shooter.gd
git commit -m "refactor: tower_shooter.gd uses SceneFactory for bullet creation"
```

---

## Task 6: Refactor enemy_spawner.gd

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd`

### Step 1: Read current enemy_spawner.gd

```bash
cat scripts/systems/enemy_spawner.gd
```

### Step 2: Find enemy scene preloads

Look for lines like:
```gdscript
var enemy_normal = preload("res://scenes/enemies/enemy_normal.tscn")
var enemy_fast = preload("res://scenes/enemies/enemy_fast.tscn")
var enemy_tank = preload("res://scenes/enemies/enemy_tank.tscn")
```

### Step 3: Remove preload dictionary/variables

Delete all enemy scene preload lines

### Step 4: Update spawn_enemy() method

Replace enemy instantiation with:
```gdscript
func spawn_enemy(enemy_type: String):
	var enemy = SceneFactory.create_enemy(enemy_type)
	if enemy:
		# Set spawn position
		enemy.global_position = get_random_spawn_position()
		get_parent().add_child(enemy)
```

### Step 5: Verify no preload() calls remain

```bash
grep -n "preload" scripts/systems/enemy_spawner.gd
# Expected: No matches
```

### Step 6: Run game to test enemy spawning

In Godot: F5 → Start battle
Expected: Enemies spawn correctly

### Step 7: Commit

```bash
git add scripts/systems/enemy_spawner.gd
git commit -m "refactor: enemy_spawner.gd uses SceneFactory for enemy creation"
```

---

## Task 7: Verify Zero Hardcoded Values

**Files:**
- All scripts in `scripts/`

### Step 1: Search for preload() calls

```bash
grep -r "preload" scripts/
# Expected: No matches (all should be in SceneFactory)
```

### Step 2: Search for magic numbers

```bash
grep -rn "[0-9]\{2,\}" scripts/ | grep -v "# " | grep -v "//"
# Review each match, ensure it's from GameConfig
```

### Step 3: Search for hardcoded scene paths

```bash
grep -r "res://scenes" scripts/
# Expected: No matches (all should be in SceneFactory)
```

### Step 4: Create verification report

Document findings in a comment or file

### Step 5: Fix any remaining hardcoded values

If found, refactor to use GameConfig or SceneFactory

### Step 6: Commit if changes made

```bash
git add -A
git commit -m "refactor: eliminate remaining hardcoded values"
```

---

## Task 8: Write Integration Tests

**Files:**
- Create: `tests/integration/test_tower_placement.gd`
- Create: `tests/integration/test_wave_system.gd`

### Step 1: Create test_tower_placement.gd

```gdscript
extends GutTest

var placement_scene: PackedScene
var placement: Node2D

func before_each():
	placement_scene = load("res://scenes/placement.tscn")
	placement = placement_scene.instantiate()
	add_child_autofree(placement)

func test_tower_placement_costs_coins():
	var initial_coins = GameData.coins
	var tower_cost = SceneFactory.get_tower_cost("shooter")

	# Simulate tower placement
	placement.select_tower("shooter")
	placement.place_tower()

	assert_eq(GameData.coins, initial_coins - tower_cost, "Coins should decrease by tower cost")

func test_cannot_place_tower_without_coins():
	GameData.coins = 0
	placement.select_tower("shooter")

	assert_null(placement.preview_tower, "Should not create preview without coins")

func test_tower_added_to_inventory():
	var initial_count = GameData.tower_inventory.size()

	# Place a tower and start battle
	placement.select_tower("shooter")
	placement.place_tower()
	placement.start_battle()

	assert_gt(GameData.tower_inventory.size(), initial_count, "Tower should be added to inventory")
```

### Step 2: Create test_wave_system.gd

```gdscript
extends GutTest

func test_wave_config_exists():
	var wave_count = GameConfig.WAVES["total_waves"]
	assert_eq(wave_count, 10, "Should have 10 waves")

	var wave_configs = GameConfig.WAVES["wave_configs"]
	assert_eq(wave_configs.size(), 10, "Should have 10 wave configs")

func test_wave_config_structure():
	var wave_config = GameConfig.WAVES["wave_configs"][0]

	assert_has(wave_config, "duration", "Wave should have duration")
	assert_has(wave_config, "spawn_interval", "Wave should have spawn_interval")
	assert_has(wave_config, "enemy_types", "Wave should have enemy_types")

func test_enemy_types_valid():
	for wave_config in GameConfig.WAVES["wave_configs"]:
		for enemy_type in wave_config["enemy_types"]:
			assert_has(GameConfig.ENEMIES, enemy_type, "Enemy type should exist in config")
```

### Step 3: Run integration tests

In Godot: Tools → Gut → Run All Tests
Expected: All tests pass

### Step 4: Commit

```bash
git add tests/integration/
git commit -m "test: add integration tests for placement and wave systems"
```

---

## Task 9: Update GameConfig with Missing Values

**Files:**
- Modify: `game_config.gd`

### Step 1: Review GameConfig for completeness

Check that all tower types have shop_price_min and shop_price_max

### Step 2: Verify all configs are used

```bash
grep -r "GameConfig\." scripts/
# Verify all references are valid
```

### Step 3: Add any missing config values

If found, add to GameConfig.gd

### Step 4: Run tests to verify

In Godot: Tools → Gut → Run All Tests
Expected: All tests pass

### Step 5: Commit if changes made

```bash
git add game_config.gd
git commit -m "config: ensure all game values in GameConfig"
```

---

## Task 10: Full Game Playthrough Test

**Manual Testing Checklist:**

### Step 1: Start game

In Godot: F5

### Step 2: Character selection

- Select Warrior
- Verify stats display correctly
- Click "确认"

### Step 3: Weapon selection

- Select Rifle
- Click "确认"

### Step 4: Map selection

- Select Forest
- Verify preview shows
- Click "确认"

### Step 5: Placement scene

- Place shooter tower (verify cost deducted)
- Place wall tower
- Place slow tower
- Verify cannot place without coins
- Click "开始战斗"

### Step 6: Combat scene

- Verify towers restored correctly
- Verify player can shoot
- Verify enemies spawn
- Verify towers shoot enemies
- Verify coins drop from enemies
- Survive wave

### Step 7: Shop scene

- Verify coins carried over
- Purchase passive upgrade
- Purchase tower
- Click "继续"

### Step 8: Second placement

- Verify previous towers still there
- Place new tower from shop
- Start battle

### Step 9: Second combat

- Verify all towers present
- Complete wave

### Step 10: Document results

Create test report:
```
✅ Character selection works
✅ Weapon selection works
✅ Map selection works
✅ Tower placement works
✅ Tower costs from SceneFactory
✅ Combat scene works
✅ Towers restored correctly
✅ Shop works
✅ Multi-wave progression works
```

---

## Phase 2 Validation

### Checklist

- [ ] placement.gd refactored (no hardcoded values)
- [ ] main.gd refactored (uses SceneFactory)
- [ ] enemy.gd refactored (uses SceneFactory)
- [ ] player.gd refactored (uses SceneFactory)
- [ ] tower_shooter.gd refactored (uses SceneFactory)
- [ ] enemy_spawner.gd refactored (uses SceneFactory)
- [ ] Zero preload() calls outside SceneFactory
- [ ] Zero hardcoded values verified
- [ ] Integration tests written and passing
- [ ] Full game playthrough successful

### Verification Commands

```bash
# No preload outside SceneFactory
grep -r "preload" scripts/ | grep -v "scene_factory.gd"
# Expected: No matches

# No hardcoded scene paths
grep -r "res://scenes" scripts/ | grep -v "scene_factory.gd"
# Expected: No matches

# Run all tests
# In Godot: Tools → Gut → Run All Tests
# Expected: All tests pass
```

---

## Commit Phase 2 Completion

```bash
git add -A
git commit -m "feat: complete Phase 2 - Refactor Existing Code

- Refactored placement.gd to use SceneFactory
- Refactored main.gd tower restoration
- Refactored all entity scripts to use SceneFactory
- Eliminated all hardcoded values
- Added integration tests
- Verified full game playthrough"
```

---

**Phase 2 Complete!**

Next: Read `2026-03-05-mcp-first-refactor-phase3.md` for Phase 3 tasks.
