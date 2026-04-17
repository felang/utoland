# #3 塔耐久 + 拆塔者 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tower durability mechanics (HP damage, visual feedback, wave heal) and a new "tower breaker" enemy type that targets towers instead of the player.

**Architecture:** Data-driven approach — add `targets_towers: bool` to EnemyData, extend enemy.gd base class with tower-targeting AI branch. Tower visual feedback via `_draw()` health bar and modulate tinting. Wave heal in main.gd's wave_completed listener. Tower destruction cleanup through EventBus signal with deploy_id.

**Tech Stack:** Godot 4.6, GDScript, GUT test framework

**Spec:** `docs/superpowers/specs/2026-04-17-tower-durability-breaker-design.md`

---

## File Structure

**Create:**
- `resources/enemies/tower_breaker.tres` — tower breaker EnemyData
- `scenes/entities/enemies/enemy_tower_breaker.tscn` — tower breaker scene
- `tests/unit/test_tower_breaker.gd` — tower breaker targeting unit tests
- `tests/unit/test_tower_durability.gd` — tower HP, heal, visual unit tests
- `tests/integration/test_tower_breaker_flow.gd` — end-to-end integration test

**Modify:**
- `scripts/resources/enemy_data.gd:19` — add `targets_towers: bool`
- `scripts/core/enums.gd:32` — add `TOWER_BREAKER` constant
- `scripts/entities/enemy.gd` — tower targeting AI in `_physics_process`
- `scripts/entities/towers/tower.gd` — deploy_id, health bar draw, low-HP tint, updated death
- `scripts/core/event_bus.gd:33` — update `tower_destroyed` signal (add deploy_id param)
- `scripts/core/inventory_manager.gd` — add `remove_destroyed_tower(deploy_id)`
- `scripts/systems/drag_manager.gd:187-191` — inject deploy_id; add `untrack_tower(deploy_id)`
- `scripts/ui/main.gd` — tower_destroyed handler + wave heal
- `scripts/core/scene_factory.gd:54-61` — register tower_breaker scene
- `scripts/core/game_config.gd:62-104` — add tower_breaker sprite config
- `resources/waves/forest/wave_08.tres` through `wave_20.tres` — add tower_breaker weights

---

### Task 1: EnemyData.targets_towers + Enums.TOWER_BREAKER

**Files:**
- Modify: `scripts/resources/enemy_data.gd:19`
- Modify: `scripts/core/enums.gd:32`
- Test: `tests/unit/test_tower_breaker.gd`

- [ ] **Step 1: Write failing test**

Create `tests/unit/test_tower_breaker.gd`:

```gdscript
extends GutTest

func test_enemy_data_has_targets_towers_field():
	var data := EnemyData.new()
	assert_eq(data.targets_towers, false, "targets_towers 默认应为 false")

func test_enemy_data_targets_towers_settable():
	var data := EnemyData.new()
	data.targets_towers = true
	assert_eq(data.targets_towers, true, "targets_towers 应可设为 true")

func test_enums_has_tower_breaker():
	assert_eq(Enums.Enemy.TOWER_BREAKER, "tower_breaker")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_breaker.gd -gexit`
Expected: FAIL — `targets_towers` not defined, `TOWER_BREAKER` not defined

- [ ] **Step 3: Add targets_towers to EnemyData**

In `scripts/resources/enemy_data.gd`, after line 19 (`@export var is_boss: bool = false`), add:

```gdscript
# 拆塔者标识：优先追塔
@export var targets_towers: bool = false
```

- [ ] **Step 4: Add TOWER_BREAKER to Enums**

In `scripts/core/enums.gd`, inside `class Enemy` after line 32 (`const BOSS_GUARDIAN = "boss_guardian"`), add:

```gdscript
const TOWER_BREAKER = "tower_breaker"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_breaker.gd -gexit`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/resources/enemy_data.gd scripts/core/enums.gd tests/unit/test_tower_breaker.gd
git commit -m "feat(#3): EnemyData.targets_towers 字段 + Enums.TOWER_BREAKER 常量"
```

---

### Task 2: EventBus signal update + tower.gd deploy_id + DragManager wiring

**Files:**
- Modify: `scripts/core/event_bus.gd:33`
- Modify: `scripts/entities/towers/tower.gd:1-9,125-127`
- Modify: `scripts/systems/drag_manager.gd:187-191`
- Test: `tests/unit/test_tower_durability.gd`

- [ ] **Step 1: Write failing test**

Create `tests/unit/test_tower_durability.gd`:

```gdscript
extends GutTest

var test_scene: Node2D

func before_each():
	test_scene = Node2D.new()
	add_child_autofree(test_scene)

func test_tower_has_deploy_id():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	assert_eq(tower.deploy_id, -1, "deploy_id 默认应为 -1")
	tower.deploy_id = 42
	assert_eq(tower.deploy_id, 42, "deploy_id 应可设置")

func test_tower_destroyed_emits_deploy_id():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	tower.deploy_id = 7
	var received_deploy_id: int = -1
	var _on_destroyed = func(_type: String, _pos: Vector2, did: int) -> void:
		received_deploy_id = did
	EventBus.tower_destroyed.connect(_on_destroyed)
	tower.take_damage(tower.health.max_hp + 10)
	assert_eq(received_deploy_id, 7, "tower_destroyed 应携带 deploy_id")
	EventBus.tower_destroyed.disconnect(_on_destroyed)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_durability.gd -gexit`
Expected: FAIL — `deploy_id` not defined on tower

- [ ] **Step 3: Update EventBus.tower_destroyed signal**

In `scripts/core/event_bus.gd`, change line 33:

From:
```gdscript
signal tower_destroyed(tower_type: String, position: Vector2)
```
To:
```gdscript
signal tower_destroyed(tower_type: String, position: Vector2, deploy_id: int)
```

- [ ] **Step 4: Add deploy_id to tower.gd and update _on_died**

In `scripts/entities/towers/tower.gd`, after line 8 (`var current_level: int = 1`), add:

```gdscript
var deploy_id: int = -1
```

Change `_on_died()` (line 125-127) from:
```gdscript
func _on_died() -> void:
	EventBus.tower_destroyed.emit(tower_type, global_position)
	queue_free()
```
To:
```gdscript
func _on_died() -> void:
	EventBus.tower_destroyed.emit(tower_type, global_position, deploy_id)
	queue_free()
```

- [ ] **Step 5: Inject deploy_id in DragManager.spawn_tower_node**

In `scripts/systems/drag_manager.gd`, change `spawn_tower_node` (line 187-191) from:
```gdscript
func spawn_tower_node(deploy_id: int, tower_id: String, level: int, grid_pos: Vector2i) -> void:
	var tower: Node2D = SceneFactory.create_tower(tower_id, level)
	tower.position = _grid_to_world(grid_pos)
	SceneFactory.get_entity_layer().add_child(tower)
	_tower_nodes[deploy_id] = tower
```
To:
```gdscript
func spawn_tower_node(deploy_id: int, tower_id: String, level: int, grid_pos: Vector2i) -> void:
	var tower: Node2D = SceneFactory.create_tower(tower_id, level)
	tower.deploy_id = deploy_id
	tower.position = _grid_to_world(grid_pos)
	SceneFactory.get_entity_layer().add_child(tower)
	_tower_nodes[deploy_id] = tower
```

- [ ] **Step 6: Add untrack_tower to DragManager**

In `scripts/systems/drag_manager.gd`, after `_remove_tower_node` (line 200), add:

```gdscript
func untrack_tower(deploy_id: int) -> void:
	_tower_nodes.erase(deploy_id)
```

- [ ] **Step 7: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_durability.gd -gexit`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add scripts/core/event_bus.gd scripts/entities/towers/tower.gd scripts/systems/drag_manager.gd tests/unit/test_tower_durability.gd
git commit -m "feat(#3): tower.deploy_id + tower_destroyed 信号携带 deploy_id + DragManager 注入"
```

---

### Task 3: InventoryManager.remove_destroyed_tower

**Files:**
- Modify: `scripts/core/inventory_manager.gd`
- Test: `tests/unit/test_tower_durability.gd`

- [ ] **Step 1: Write failing test**

Append to `tests/unit/test_tower_durability.gd`:

```gdscript
func test_inventory_remove_destroyed_tower():
	InventoryManager.reset()
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 10})
	InventoryManager.deployed_towers.append({id = "ice_flower", level = 1, grid_pos = Vector2i(6, 6), deploy_id = 11})
	assert_eq(InventoryManager.deployed_towers.size(), 2)
	InventoryManager.remove_destroyed_tower(10)
	assert_eq(InventoryManager.deployed_towers.size(), 1)
	assert_eq(InventoryManager.deployed_towers[0].deploy_id, 11, "只移除 deploy_id=10 的塔")

func test_inventory_remove_destroyed_tower_nonexistent():
	InventoryManager.reset()
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 10})
	InventoryManager.remove_destroyed_tower(999)
	assert_eq(InventoryManager.deployed_towers.size(), 1, "不存在的 deploy_id 不影响数组")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_durability.gd -gexit`
Expected: FAIL — `remove_destroyed_tower` not defined

- [ ] **Step 3: Implement remove_destroyed_tower**

In `scripts/core/inventory_manager.gd`, after `sell_from_deployed_tower` method (after line 63), add:

```gdscript
func remove_destroyed_tower(deploy_id: int) -> void:
	for i in range(deployed_towers.size()):
		if deployed_towers[i].deploy_id == deploy_id:
			deployed_towers.remove_at(i)
			return
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_durability.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/inventory_manager.gd tests/unit/test_tower_durability.gd
git commit -m "feat(#3): InventoryManager.remove_destroyed_tower 方法"
```

---

### Task 4: Tower visual feedback (health bar + low-HP tint)

**Files:**
- Modify: `scripts/entities/towers/tower.gd`
- Test: `tests/unit/test_tower_durability.gd`

- [ ] **Step 1: Write failing test**

Append to `tests/unit/test_tower_durability.gd`:

```gdscript
func test_tower_low_hp_tint():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	await wait_frames(2)
	assert_eq(tower.visual.modulate, Color.WHITE, "满血时 modulate 应为白色")
	var low_hp_damage: float = tower.health.max_hp * 0.75
	tower.take_damage(low_hp_damage)
	assert_eq(tower.visual.modulate, Color(1, 0.5, 0.5), "HP < 30% 时应变红")

func test_tower_tint_recovers_on_heal():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	await wait_frames(2)
	tower.take_damage(tower.health.max_hp * 0.75)
	assert_eq(tower.visual.modulate, Color(1, 0.5, 0.5), "低血应变红")
	tower.heal(tower.health.max_hp * 0.5)
	assert_eq(tower.visual.modulate, Color.WHITE, "恢复后应恢复白色")

func test_health_component_heal_clamps():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	var max_hp: float = tower.health.max_hp
	tower.take_damage(10.0)
	tower.health.heal(max_hp)
	assert_almost_eq(tower.health.current_hp, max_hp, 0.01, "heal 不应超过 max_hp")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_durability.gd -gexit`
Expected: FAIL — `heal` method not on tower, visual modulate not changing

- [ ] **Step 3: Add visual feedback and heal wrapper to tower.gd**

In `scripts/entities/towers/tower.gd`, make these changes:

**a)** In `_ready()`, after `health.died.connect(_on_died)` (line 28), add:

```gdscript
health.damaged.connect(_on_damaged)
```

**b)** Add these new methods after `_on_died()`:

```gdscript
func heal(amount: float) -> void:
	health.heal(amount)
	_update_damage_visual()

func _on_damaged(_amount: float, _current_hp: float, _attacker: Node2D) -> void:
	_update_damage_visual()

func _update_damage_visual() -> void:
	var hp_ratio: float = health.current_hp / health.max_hp
	if visual:
		visual.modulate = Color(1, 0.5, 0.5) if hp_ratio < 0.3 else Color.WHITE
	queue_redraw()
```

**c)** Add `_draw()` for health bar, after `_update_damage_visual`:

```gdscript
func _draw() -> void:
	if health.current_hp >= health.max_hp:
		return
	var bar_width: float = 28.0
	var bar_height: float = 4.0
	var bar_y: float = -20.0
	var hp_ratio: float = health.current_hp / health.max_hp
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))
	var color: Color = Color.GREEN if hp_ratio > 0.3 else Color.RED
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width * hp_ratio, bar_height), color)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_durability.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/entities/towers/tower.gd tests/unit/test_tower_durability.gd
git commit -m "feat(#3): 塔受损视觉反馈 — 血条 + 低血量红色 tint"
```

---

### Task 5: main.gd tower_destroyed handler + wave heal

**Files:**
- Modify: `scripts/ui/main.gd`
- Test: `tests/unit/test_tower_durability.gd`

- [ ] **Step 1: Write failing test for wave heal**

Append to `tests/unit/test_tower_durability.gd`:

```gdscript
func test_tower_heal_between_waves():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	var max_hp: float = tower.health.max_hp
	tower.take_damage(max_hp * 0.5)
	var hp_before: float = tower.health.current_hp
	var expected_heal: float = max_hp * 0.3
	tower.heal(expected_heal)
	assert_almost_eq(tower.health.current_hp, hp_before + expected_heal, 0.01,
		"应恢复 30% max_hp")

func test_tower_heal_does_not_exceed_max():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	var max_hp: float = tower.health.max_hp
	tower.take_damage(5.0)
	tower.heal(max_hp)
	assert_almost_eq(tower.health.current_hp, max_hp, 0.01,
		"heal 不应超过 max_hp")
```

- [ ] **Step 2: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_durability.gd -gexit`
Expected: PASS (tower.heal already implemented in Task 4)

- [ ] **Step 3: Add tower_destroyed handler and wave heal to main.gd**

In `scripts/ui/main.gd`, add signal connections after the existing `EventBus.wave_started.connect` line (line 57):

```gdscript
EventBus.tower_destroyed.connect(_on_tower_destroyed)
EventBus.wave_completed.connect(_on_wave_completed_heal_towers)
```

Add handler methods at the end of the file (before `_exit_tree`):

```gdscript
func _on_tower_destroyed(_tower_type: String, _position: Vector2, deploy_id: int) -> void:
	InventoryManager.remove_destroyed_tower(deploy_id)
	_drag_manager.untrack_tower(deploy_id)

func _on_wave_completed_heal_towers(_wave_number: int) -> void:
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	for tower in towers:
		if tower.has_method("heal"):
			tower.heal(tower.health.max_hp * 0.3)
```

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/main.gd tests/unit/test_tower_durability.gd
git commit -m "feat(#3): 塔摧毁联动清理 + 波间恢复 30% 耐久"
```

---

### Task 6: enemy.gd tower targeting AI

**Files:**
- Modify: `scripts/entities/enemy.gd`
- Test: `tests/unit/test_tower_breaker.gd`

- [ ] **Step 1: Write failing tests**

Append to `tests/unit/test_tower_breaker.gd`:

```gdscript
var test_scene: Node2D

func before_each():
	test_scene = Node2D.new()
	add_child_autofree(test_scene)
	PlayerState.reset()

func _make_tower_breaker_data() -> EnemyData:
	var data := EnemyData.new()
	data.id = "tower_breaker"
	data.hp = 150.0
	data.speed = 100.0
	data.damage = 20.0
	data.exp_drop_min = 2
	data.exp_drop_max = 3
	data.targets_towers = true
	return data

func test_tower_breaker_targets_nearest_tower():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.data = _make_tower_breaker_data()
	enemy.data.targets_towers = true
	enemy.global_position = Vector2(100, 100)

	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	tower.global_position = Vector2(200, 100)

	# 强制刷新目标
	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)

	assert_eq(enemy._tower_target, tower, "应锁定最近的塔")

func test_tower_breaker_fallback_to_player():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.data = _make_tower_breaker_data()
	enemy.data.targets_towers = true

	# 没有塔
	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)

	assert_null(enemy._tower_target, "没有塔时 _tower_target 应为 null（退化追玩家）")

func test_tower_breaker_retargets_after_tower_destroyed():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.data = _make_tower_breaker_data()
	enemy.data.targets_towers = true
	enemy.global_position = Vector2(100, 100)

	var tower1 = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower1)
	tower1.global_position = Vector2(200, 100)

	var tower2 = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	test_scene.add_child(tower2)
	tower2.global_position = Vector2(300, 100)

	# 锁定 tower1
	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)
	assert_eq(enemy._tower_target, tower1)

	# 模拟 tower1 被摧毁
	tower1.queue_free()
	await wait_frames(2)

	# 强制重新搜索
	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)
	assert_eq(enemy._tower_target, tower2, "应切换到下一个塔")

func test_normal_enemy_ignores_towers():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	assert_eq(enemy.data.targets_towers, false, "普通敌人不追塔")
	assert_null(enemy._tower_target, "_tower_target 应为 null")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_breaker.gd -gexit`
Expected: FAIL — `_tower_target`, `_update_tower_target` not defined

- [ ] **Step 3: Implement tower targeting in enemy.gd**

In `scripts/entities/enemy.gd`, add new variables after `var _is_pooled: bool = false` (line 22):

```gdscript
var _tower_target: Node2D = null
var _target_refresh_timer: float = 0.0
const TARGET_REFRESH_INTERVAL: float = 0.5
```

Replace `_physics_process` (line 47-48) from:
```gdscript
func _physics_process(delta: float) -> void:
	_chase_player(delta)
```
To:
```gdscript
func _physics_process(delta: float) -> void:
	if data and data.targets_towers:
		_update_tower_target(delta)
		_chase_target(delta)
	else:
		_chase_player(delta)
```

Add new methods after `_chase_player` (after line 60):

```gdscript
func _update_tower_target(delta: float) -> void:
	_target_refresh_timer -= delta
	if _target_refresh_timer <= 0:
		_target_refresh_timer = TARGET_REFRESH_INTERVAL
		_tower_target = _find_nearest_tower()

func _find_nearest_tower() -> Node2D:
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for tower in towers:
		if not is_instance_valid(tower):
			continue
		var dist: float = global_position.distance_squared_to(tower.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = tower
	return nearest

func _chase_target(delta: float) -> void:
	var kb_vel: Vector2 = _knockback.tick(delta)
	if is_rooted:
		if kb_vel.length_squared() > 0:
			velocity = kb_vel
			move_and_slide()
		return
	if _tower_target and not is_instance_valid(_tower_target):
		_tower_target = null
		_target_refresh_timer = 0.0
	var target: Node2D = _tower_target if _tower_target else player
	if target and is_instance_valid(target):
		velocity = position.direction_to(target.global_position) * speed + kb_vel
		move_and_slide()
		_sprite_animator.update_animation_no_idle(velocity)
```

Update `reset_for_pool` to clear tower target state — add at end of method (before closing of function):

```gdscript
_tower_target = null
_target_refresh_timer = 0.0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_breaker.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/entities/enemy.gd tests/unit/test_tower_breaker.gd
git commit -m "feat(#3): enemy.gd 寻塔 AI — targets_towers 敌人优先追塔"
```

---

### Task 7: tower_breaker.tres + scene + SceneFactory + GameConfig

**Files:**
- Create: `resources/enemies/tower_breaker.tres`
- Create: `scenes/entities/enemies/enemy_tower_breaker.tscn`
- Modify: `scripts/core/scene_factory.gd:54-61`
- Modify: `scripts/core/game_config.gd:62-104`
- Test: `tests/unit/test_tower_breaker.gd`

- [ ] **Step 1: Write failing test**

Append to `tests/unit/test_tower_breaker.gd`:

```gdscript
func test_game_config_has_tower_breaker():
	assert_true(GameConfig.enemies.has("tower_breaker"), "GameConfig 应注册 tower_breaker")
	var data: EnemyData = GameConfig.enemies["tower_breaker"]
	assert_eq(data.targets_towers, true, "拆塔者 targets_towers 应为 true")
	assert_gt(data.hp, 100.0, "拆塔者 HP 应高于普通怪")

func test_scene_factory_creates_tower_breaker():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.TOWER_BREAKER)
	assert_not_null(enemy, "SceneFactory 应能创建 tower_breaker")
	test_scene.add_child(enemy)
	assert_eq(enemy.data.targets_towers, true, "创建的 tower_breaker 应有 targets_towers=true")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_breaker.gd -gexit`
Expected: FAIL — tower_breaker not in GameConfig/SceneFactory

- [ ] **Step 3: Create tower_breaker.tres**

Create `resources/enemies/tower_breaker.tres`:

```tres
[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/enemy_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "tower_breaker"
display_name = "拆塔者"
hp = 150.0
speed = 100.0
damage = 20.0
exp_drop_min = 2
exp_drop_max = 3
targets_towers = true
```

- [ ] **Step 4: Create enemy_tower_breaker.tscn**

Create `scenes/entities/enemies/enemy_tower_breaker.tscn` (based on enemy_normal.tscn with purple color):

```tscn
[gd_scene format=3]

[ext_resource type="Script" uid="uid://b1ohisgqjft26" path="res://scripts/entities/enemy.gd" id="1_onop2"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2_health"]
[ext_resource type="Script" path="res://scripts/components/knockback_handler.gd" id="3_knockback"]
[ext_resource type="Script" path="res://scripts/components/slow_handler.gd" id="4_slow"]
[ext_resource type="Script" path="res://scripts/components/sprite_animator.gd" id="5_sprite"]
[ext_resource type="Script" uid="uid://bx7m3k2vpqn4r" path="res://scripts/components/hitbox.gd" id="6_hitbox"]
[ext_resource type="Script" path="res://scripts/components/hurtbox.gd" id="7_hurtbox"]

[sub_resource type="CircleShape2D" id="CircleShape2D_body"]
radius = 14.0

[sub_resource type="CircleShape2D" id="CircleShape2D_hitbox"]
radius = 12.0

[sub_resource type="CircleShape2D" id="CircleShape2D_hurtbox"]
radius = 15.0

[node name="EnemyTowerBreaker" type="CharacterBody2D"]
y_sort_origin = 16
collision_layer = 2
collision_mask = 4
script = ExtResource("1_onop2")

[node name="Visual" type="ColorRect" parent="."]
offset_left = -16.0
offset_top = -16.0
offset_right = 16.0
offset_bottom = 16.0
color = Color(0.6, 0.2, 0.8, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_body")

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("2_health")

[node name="KnockbackHandler" type="Node" parent="."]
script = ExtResource("3_knockback")

[node name="SlowHandler" type="Node" parent="."]
script = ExtResource("4_slow")

[node name="SpriteAnimator" type="Node" parent="."]
script = ExtResource("5_sprite")

[node name="Hitbox" type="Area2D" parent="."]
collision_layer = 32
collision_mask = 64
script = ExtResource("6_hitbox")

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hitbox"]
shape = SubResource("CircleShape2D_hitbox")

[node name="Hurtbox" type="Area2D" parent="."]
collision_layer = 128
collision_mask = 16
script = ExtResource("7_hurtbox")

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hurtbox"]
shape = SubResource("CircleShape2D_hurtbox")
```

- [ ] **Step 5: Register in SceneFactory**

In `scripts/core/scene_factory.gd`, add to `_enemy_scenes` dict (after line 60, `Enums.Enemy.BOSS_GUARDIAN`):

```gdscript
Enums.Enemy.TOWER_BREAKER: preload("res://scenes/entities/enemies/enemy_tower_breaker.tscn"),
```

Note: tower_breaker is NOT pooled (not added to `_ready()` pool registration).

- [ ] **Step 6: Add sprite config to GameConfig**

In `scripts/core/game_config.gd`, inside `SPRITES.enemies` dict (after `boss_guardian` entry around line 103), add:

```gdscript
"tower_breaker": {
	"spritesheet": "res://assets/enemies/slime/sprite.png",
	"frame_size": Vector2(16, 16),
	"walk_frames": 4,
	"walk_directions": 4,
	"fps": 8.0
},
```

- [ ] **Step 7: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tower_breaker.gd -gexit`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add resources/enemies/tower_breaker.tres scenes/entities/enemies/enemy_tower_breaker.tscn scripts/core/scene_factory.gd scripts/core/game_config.gd tests/unit/test_tower_breaker.gd
git commit -m "feat(#3): 拆塔者敌人 — tres + tscn + SceneFactory + GameConfig 注册"
```

---

### Task 8: Wave config updates (waves 8-20)

**Files:**
- Modify: `resources/waves/forest/wave_08.tres` through `wave_20.tres`

- [ ] **Step 1: Add tower_breaker to wave 8-20 enemy_weights**

Update each wave file's `enemy_weights` dictionary to include `"tower_breaker"` with these weights:

| Wave | tower_breaker weight | Notes |
|------|---------------------|-------|
| 08 | 5 | First appearance, boss wave |
| 09 | 5 | |
| 10 | 5 | |
| 11 | 8 | |
| 12 | 8 | Boss wave |
| 13 | 10 | |
| 14 | 10 | |
| 15 | 10 | Boss wave |
| 16 | 12 | |
| 17 | 12 | |
| 18 | 12 | |
| 19 | 12 | |
| 20 | 15 | Final boss |

For each file, add `"tower_breaker": N` to the `enemy_weights = { ... }` dictionary. Example for wave_08.tres — change:

```
enemy_weights = {
"fast": 40,
"normal": 30,
"tank": 30
}
```

To:

```
enemy_weights = {
"fast": 40,
"normal": 30,
"tank": 25,
"tower_breaker": 5
}
```

Reduce existing weights proportionally to keep total roughly the same, or just add the tower_breaker weight (total weight increase is fine since `pick_weighted_enemy` normalizes).

- [ ] **Step 2: Verify waves load correctly**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gtest=test_wave_system.gd -gexit`
Expected: PASS (existing wave tests should still pass)

- [ ] **Step 3: Commit**

```bash
git add resources/waves/forest/
git commit -m "feat(#3): 波次 8-20 加入拆塔者权重 (5-15%)"
```

---

### Task 9: Integration test

**Files:**
- Create: `tests/integration/test_tower_breaker_flow.gd`

- [ ] **Step 1: Write integration test**

Create `tests/integration/test_tower_breaker_flow.gd`:

```gdscript
extends GutTest

var test_scene: Node2D

func before_each():
	test_scene = Node2D.new()
	add_child_autofree(test_scene)
	PlayerState.reset()
	InventoryManager.reset()

func test_tower_breaker_damages_and_destroys_tower():
	# 创建塔
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	tower.global_position = Vector2(200, 200)
	tower.deploy_id = 1
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1
	})

	var initial_hp: float = tower.health.current_hp
	assert_gt(initial_hp, 0.0, "塔应有初始血量")

	# 手动扣血模拟拆塔者接触伤害
	tower.take_damage(20.0)
	assert_lt(tower.health.current_hp, initial_hp, "塔应受伤")

	# 继续扣血直到摧毁
	var destroyed_signal_received := false
	var destroyed_deploy_id: int = -1
	var _handler = func(_type: String, _pos: Vector2, did: int) -> void:
		destroyed_signal_received = true
		destroyed_deploy_id = did
	EventBus.tower_destroyed.connect(_handler)
	tower.take_damage(tower.health.current_hp + 10)
	await wait_frames(2)

	assert_true(destroyed_signal_received, "应触发 tower_destroyed 信号")
	assert_eq(destroyed_deploy_id, 1, "tower_destroyed 应携带正确 deploy_id")
	assert_false(is_instance_valid(tower) and tower.is_inside_tree(), "塔应被移除")
	EventBus.tower_destroyed.disconnect(_handler)

func test_tower_breaker_full_targeting_flow():
	# 创建拆塔者
	var enemy = SceneFactory.create_enemy(Enums.Enemy.TOWER_BREAKER)
	test_scene.add_child(enemy)
	enemy.global_position = Vector2(100, 100)

	# 创建塔
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	tower.global_position = Vector2(300, 100)

	assert_eq(enemy.data.targets_towers, true, "拆塔者应有 targets_towers=true")

	# 刷新目标
	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)
	assert_eq(enemy._tower_target, tower, "应锁定塔")

	# 摧毁塔
	tower.queue_free()
	await wait_frames(2)

	# 重新搜索 — 没有塔了
	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)
	assert_null(enemy._tower_target, "塔被毁后应退化追玩家")

func test_wave_heal_restores_tower_hp():
	var tower = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	test_scene.add_child(tower)
	var max_hp: float = tower.health.max_hp
	tower.take_damage(max_hp * 0.5)
	var hp_before_heal: float = tower.health.current_hp
	tower.heal(max_hp * 0.3)
	assert_almost_eq(tower.health.current_hp, hp_before_heal + max_hp * 0.3, 0.01,
		"波间应恢复 30% 最大血量")
```

- [ ] **Step 2: Run integration test**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gtest=test_tower_breaker_flow.gd -gexit`
Expected: PASS

- [ ] **Step 3: Run full test suite**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: All tests PASS (pre-existing `test_knockback_changes_position` failure is known and unrelated)

- [ ] **Step 4: Commit**

```bash
git add tests/integration/test_tower_breaker_flow.gd
git commit -m "test(#3): 拆塔者流程集成测试 + 全套验证"
```

---

### Task 10: Final review + manual verification

- [ ] **Step 1: Run the game in Godot**

Use gdai-mcp `play_scene` tool or run from editor. Verify:
- Waves 1-7: no tower_breaker enemies appear
- Wave 8+: purple tower_breaker enemies appear, move toward towers (not player)
- Tower takes damage (red flash, health bar appears)
- Tower at low HP shows red tint
- Tower destroyed: death effect, removed from map and inventory
- With no towers: tower_breaker chases player instead
- Between waves: damaged towers heal 30% max_hp, tint resets if above 30%
- Selling/moving towers still works normally
- Existing enemies unchanged

- [ ] **Step 2: Fix any issues found during manual testing**

- [ ] **Step 3: Final commit if needed**

```bash
git add -A
git commit -m "fix(#3): 手工验证修复"
```
