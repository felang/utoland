# 武器系统扩展实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将武器系统从 3 把同质直线射击武器（步枪/霰弹枪/狙击枪）重构为 3 把手感差异巨大的武器（步枪/回旋镖/激光枪），删除霰弹枪和狙击枪。

**Architecture:** 采用"多弹道脚本 + 配置标记"方案。每种弹道行为对应独立脚本（bullet.gd / boomerang.gd / laser_beam.gd）。player.gd 根据 `projectile_type` 字段分发不同的射击逻辑。回旋镖使用 Area2D + 状态机实现去程/回程穿透；激光使用射线查询做瞬间伤害 + Line2D 视觉效果。

**Tech Stack:** Godot 4.6 GDScript, PhysicsDirectSpaceState2D (射线查询), Line2D + Tween (激光视觉), GUT (测试)

---

### Task 1: 更新 GameConfig 武器配置

**Files:**
- Modify: `game_config.gd:37-60`

**Step 1: 写失败测试**

创建测试文件 `tests/unit/test_weapon_config.gd`:

```gdscript
extends GutTest

# 验证 GameConfig.WEAPONS 包含正确的武器配置

func test_weapons_has_rifle():
	assert_true(GameConfig.WEAPONS.has("rifle"), "应包含 rifle")

func test_weapons_has_boomerang():
	assert_true(GameConfig.WEAPONS.has("boomerang"), "应包含 boomerang")

func test_weapons_has_laser():
	assert_true(GameConfig.WEAPONS.has("laser"), "应包含 laser")

func test_weapons_no_shotgun():
	assert_false(GameConfig.WEAPONS.has("shotgun"), "不应包含 shotgun")

func test_weapons_no_sniper():
	assert_false(GameConfig.WEAPONS.has("sniper"), "不应包含 sniper")

func test_weapons_count():
	assert_eq(GameConfig.WEAPONS.size(), 3, "应有 3 把武器")

func test_rifle_has_projectile_type():
	assert_eq(GameConfig.WEAPONS["rifle"]["projectile_type"], "bullet", "步枪弹道类型应为 bullet")

func test_boomerang_has_projectile_type():
	assert_eq(GameConfig.WEAPONS["boomerang"]["projectile_type"], "boomerang", "回旋镖弹道类型应为 boomerang")

func test_laser_has_projectile_type():
	assert_eq(GameConfig.WEAPONS["laser"]["projectile_type"], "laser", "激光枪弹道类型应为 laser")

func test_boomerang_has_required_fields():
	var b: Dictionary = GameConfig.WEAPONS["boomerang"]
	assert_true(b.has("speed"), "回旋镖应有 speed")
	assert_true(b.has("outbound_distance"), "回旋镖应有 outbound_distance")
	assert_true(b.has("return_speed_mult"), "回旋镖应有 return_speed_mult")

func test_laser_has_required_fields():
	var l: Dictionary = GameConfig.WEAPONS["laser"]
	assert_true(l.has("beam_range"), "激光应有 beam_range")
	assert_true(l.has("beam_width"), "激光应有 beam_width")
	assert_true(l.has("beam_duration"), "激光应有 beam_duration")
```

**Step 2: 运行测试确认失败**

Run: Godot GUT 运行 `tests/unit/test_weapon_config.gd`
Expected: FAIL — shotgun/sniper 仍存在，boomerang/laser 不存在

**Step 3: 修改 GameConfig.WEAPONS**

将 `game_config.gd:37-60` 替换为：

```gdscript
# 武器配置
const WEAPONS = {
	"rifle": {
		"name": "步枪",
		"projectile_type": "bullet",
		"fire_rate": 0.1,
		"damage": 10.0,
		"bullet_count": 1,
		"bullet_speed": 600,
		"range": 300.0
	},
	"boomerang": {
		"name": "回旋镖",
		"projectile_type": "boomerang",
		"fire_rate": 0.8,
		"damage": 15.0,
		"speed": 350.0,
		"outbound_distance": 200.0,
		"return_speed_mult": 1.3,
		"range": 200.0
	},
	"laser": {
		"name": "激光枪",
		"projectile_type": "laser",
		"fire_rate": 0.15,
		"damage": 8.0,
		"beam_range": 400.0,
		"beam_width": 2.0,
		"beam_duration": 0.08,
		"range": 400.0
	}
}
```

**Step 4: 运行测试确认通过**

Run: Godot GUT 运行 `tests/unit/test_weapon_config.gd`
Expected: 全部 PASS

**Step 5: 提交**

```bash
git add tests/unit/test_weapon_config.gd game_config.gd
git commit -m "feat: 更新武器配置，删除霰弹枪/狙击枪，新增回旋镖/激光枪"
```

---

### Task 2: 创建回旋镖实体（脚本 + 场景）

**Files:**
- Create: `scripts/entities/boomerang.gd`
- Create: `scenes/boomerang.tscn`

**Step 1: 写失败测试**

创建 `tests/unit/test_boomerang.gd`:

```gdscript
extends GutTest

# 回旋镖实体测试

func test_boomerang_initial_state_is_outbound():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	assert_eq(boomerang._state, "OUTBOUND", "初始状态应为 OUTBOUND")
	boomerang.queue_free()

func test_boomerang_has_damage():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	# damage 由 player 设置，默认为 0
	assert_eq(boomerang.damage, 0.0, "默认伤害应为 0")
	boomerang.queue_free()

func test_boomerang_has_speed():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	assert_gt(boomerang.speed, 0.0, "速度应大于 0")
	boomerang.queue_free()

func test_boomerang_has_outbound_distance():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	assert_gt(boomerang.outbound_distance, 0.0, "去程距离应大于 0")
	boomerang.queue_free()

func test_boomerang_tracks_hit_enemies():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	assert_eq(boomerang._hit_outbound.size(), 0, "去程命中列表应为空")
	assert_eq(boomerang._hit_returning.size(), 0, "回程命中列表应为空")
	boomerang.queue_free()

func test_boomerang_max_lifetime():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	assert_eq(boomerang.max_lifetime, 5.0, "最大存活时间应为 5 秒")
	boomerang.queue_free()
```

**Step 2: 运行测试确认失败**

Run: Godot GUT 运行 `tests/unit/test_boomerang.gd`
Expected: FAIL — SceneFactory.create_boomerang() 不存在

**Step 3: 创建 boomerang.gd**

创建 `scripts/entities/boomerang.gd`:

```gdscript
extends Area2D

# 回旋镖弹道 — 去程穿透 + 回程追踪玩家
# 配置从 GameConfig.WEAPONS["boomerang"] 读取

var speed: float = 350.0
var direction: Vector2 = Vector2.RIGHT
var damage: float = 0.0  # 由 player 射击时设置
var outbound_distance: float = 200.0
var return_speed_mult: float = 1.3
var max_lifetime: float = 5.0
var player: Node2D = null  # 回程追踪目标

var _state: String = "OUTBOUND"
var _traveled: float = 0.0
var _elapsed: float = 0.0
var _hit_outbound: Array = []
var _hit_returning: Array = []

func _ready() -> void:
	# 从 GameConfig 读取配置
	var config: Dictionary = GameConfig.WEAPONS["boomerang"]
	speed = config["speed"]
	outbound_distance = config["outbound_distance"]
	return_speed_mult = config["return_speed_mult"]

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()
		return

	match _state:
		"OUTBOUND":
			_process_outbound(delta)
		"RETURNING":
			_process_returning(delta)

func _process_outbound(delta: float) -> void:
	var move_distance: float = speed * delta
	position += direction * move_distance
	_traveled += move_distance

	if _traveled >= outbound_distance:
		_state = "RETURNING"

func _process_returning(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return

	var return_speed: float = speed * return_speed_mult
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()

	if distance < 15.0:
		queue_free()
		return

	var move_dir: Vector2 = to_player.normalized()
	position += move_dir * return_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return

	match _state:
		"OUTBOUND":
			if body not in _hit_outbound:
				_hit_outbound.append(body)
				body.take_damage(damage)
		"RETURNING":
			if body not in _hit_returning:
				_hit_returning.append(body)
				body.take_damage(damage)
```

**Step 4: 创建 boomerang.tscn**

用 MCP 工具创建场景（Area2D 根节点 + CollisionShape2D + ColorRect）。结构参考 `scenes/bullet.tscn`：
- 根节点: Area2D, collision_layer = 4, collision_mask = 2, 挂载 `scripts/entities/boomerang.gd`
- 子节点 ColorRect: offset -4 到 4, 颜色 Color(0.2, 0.8, 1.0, 1) 蓝色
- 子节点 CollisionShape2D: CircleShape2D, radius = 4

或手写 `scenes/boomerang.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/entities/boomerang.gd" id="1"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 4.0

[node name="Boomerang" type="Area2D"]
collision_layer = 4
collision_mask = 2
script = ExtResource("1")

[node name="ColorRect" type="ColorRect" parent="."]
offset_left = -4.0
offset_top = -4.0
offset_right = 4.0
offset_bottom = 4.0
color = Color(0.2, 0.8, 1.0, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")
```

**Step 5: 运行测试确认通过**

注意：此步需先完成 Task 3（SceneFactory 注册），测试才能通过。先跳到 Task 3 注册 create_boomerang，再回来验证。

**Step 6: 提交**

```bash
git add scripts/entities/boomerang.gd scenes/boomerang.tscn tests/unit/test_boomerang.gd
git commit -m "feat: 新增回旋镖实体（去程穿透 + 回程追踪）"
```

---

### Task 3: 创建激光视觉效果实体（脚本 + 场景）

**Files:**
- Create: `scripts/entities/laser_beam.gd`
- Create: `scenes/laser_beam.tscn`

**Step 1: 写失败测试**

创建 `tests/unit/test_laser_beam.gd`:

```gdscript
extends GutTest

# 激光视觉效果测试

func test_laser_beam_creation():
	var beam: Node2D = SceneFactory.create_laser_beam()
	assert_not_null(beam, "激光应被创建")
	beam.queue_free()

func test_laser_beam_has_line2d():
	var beam: Node2D = SceneFactory.create_laser_beam()
	add_child_autofree(beam)
	var line: Line2D = beam.get_node("Line2D")
	assert_not_null(line, "激光应包含 Line2D 子节点")

func test_laser_beam_default_duration():
	var beam: Node2D = SceneFactory.create_laser_beam()
	assert_eq(beam.beam_duration, 0.08, "默认持续时间应为 0.08 秒")
	beam.queue_free()
```

**Step 2: 运行测试确认失败**

Expected: FAIL — SceneFactory.create_laser_beam() 不存在

**Step 3: 创建 laser_beam.gd**

创建 `scripts/entities/laser_beam.gd`:

```gdscript
extends Node2D

# 激光视觉效果 — Line2D 显示 + Tween 淡出
# 只负责视觉，伤害在 player.gd 中通过射线查询结算

var beam_duration: float = 0.08

@onready var line: Line2D = $Line2D

func _ready() -> void:
	# 读取配置
	beam_duration = GameConfig.WEAPONS["laser"]["beam_duration"]

func fire(from: Vector2, to: Vector2) -> void:
	# 设置 Line2D 的两个端点（本地坐标）
	global_position = Vector2.ZERO
	line.clear_points()
	line.add_point(from)
	line.add_point(to)

	# Tween 淡出后自动销毁
	var tween: Tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, beam_duration)
	tween.tween_callback(queue_free)
```

**Step 4: 创建 laser_beam.tscn**

手写 `scenes/laser_beam.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/entities/laser_beam.gd" id="1"]

[node name="LaserBeam" type="Node2D"]
script = ExtResource("1")

[node name="Line2D" type="Line2D" parent="."]
width = 2.0
default_color = Color(1, 0.2, 0.2, 1)
```

**Step 5: 提交**

```bash
git add scripts/entities/laser_beam.gd scenes/laser_beam.tscn tests/unit/test_laser_beam.gd
git commit -m "feat: 新增激光视觉效果实体（Line2D + Tween 淡出）"
```

---

### Task 4: 注册 SceneFactory 工厂方法

**Files:**
- Modify: `scripts/core/scene_factory.gd`
- Modify: `tests/unit/test_scene_factory.gd`

**Step 1: 写失败测试**

在 `tests/unit/test_scene_factory.gd` 末尾追加：

```gdscript
# 回旋镖和激光创建测试
func test_create_boomerang():
	var boomerang = SceneFactory.create_boomerang()
	assert_not_null(boomerang, "Boomerang should be created")
	boomerang.queue_free()

func test_create_laser_beam():
	var beam = SceneFactory.create_laser_beam()
	assert_not_null(beam, "Laser beam should be created")
	beam.queue_free()
```

**Step 2: 运行测试确认失败**

Expected: FAIL — create_boomerang / create_laser_beam 方法不存在

**Step 3: 修改 scene_factory.gd**

在 `scripts/core/scene_factory.gd` 中添加 preload 和工厂方法：

在 `_coin_scene` 下方添加：
```gdscript
var _boomerang_scene: PackedScene = preload("res://scenes/boomerang.tscn")
var _laser_beam_scene: PackedScene = preload("res://scenes/laser_beam.tscn")
```

在 `create_coin()` 方法下方添加：
```gdscript
# Boomerang creation
func create_boomerang() -> Area2D:
	return _boomerang_scene.instantiate()

# Laser beam creation
func create_laser_beam() -> Node2D:
	return _laser_beam_scene.instantiate()
```

**Step 4: 运行所有 SceneFactory 测试确认通过**

Run: Godot GUT 运行 `tests/unit/test_scene_factory.gd`
Expected: 全部 PASS（包括新增的 2 个测试）

同时运行 Task 2 和 Task 3 的测试确认通过。

**Step 5: 提交**

```bash
git add scripts/core/scene_factory.gd tests/unit/test_scene_factory.gd
git commit -m "feat: SceneFactory 注册回旋镖和激光工厂方法"
```

---

### Task 5: 重构 player.gd 射击逻辑

**Files:**
- Modify: `scripts/entities/player.gd`

**Step 1: 写失败测试**

创建 `tests/unit/test_player_weapon.gd`:

```gdscript
extends GutTest

# 测试 player 武器分发逻辑
# 注意：这些测试验证配置读取和方法存在性，不测试实际射击（需要场景树）

func test_rifle_weapon_range():
	GameData.selected_weapon = "rifle"
	var range_val: float = GameConfig.WEAPONS["rifle"]["range"]
	assert_eq(range_val, 300.0, "步枪射程应为 300")

func test_boomerang_weapon_range():
	GameData.selected_weapon = "boomerang"
	var range_val: float = GameConfig.WEAPONS["boomerang"]["range"]
	assert_eq(range_val, 200.0, "回旋镖射程应为 200")

func test_laser_weapon_range():
	GameData.selected_weapon = "laser"
	var range_val: float = GameConfig.WEAPONS["laser"]["range"]
	assert_eq(range_val, 400.0, "激光枪射程应为 400")

func test_all_weapons_have_range():
	for weapon_id in GameConfig.WEAPONS:
		assert_true(GameConfig.WEAPONS[weapon_id].has("range"),
			"武器 %s 应有 range 字段" % weapon_id)

func test_all_weapons_have_projectile_type():
	for weapon_id in GameConfig.WEAPONS:
		assert_true(GameConfig.WEAPONS[weapon_id].has("projectile_type"),
			"武器 %s 应有 projectile_type 字段" % weapon_id)
```

**Step 2: 运行测试确认失败**

Expected: FAIL — range 字段不存在（rifle 旧配置没有 range）。如果 Task 1 已完成则应 PASS。

**Step 3: 重构 player.gd**

将 `scripts/entities/player.gd` 中的 `_ready()`、`auto_shoot()`、`shoot_bullet()` 修改如下：

`_ready()` — 读取 weapon_range：
```gdscript
func _ready() -> void:
	add_to_group("player")
	hp_regen_timer = 0.0

	max_hp = GameData.player_stats["max_hp"] * GameData.player_stats["hp_mult"]
	current_hp = max_hp
	speed = GameData.character_speed * GameData.player_stats["move_speed_mult"]

	if GameData.pending_heal > 0:
		current_hp = min(current_hp + GameData.pending_heal, max_hp)
		GameData.pending_heal = 0

	var weapon_data: Dictionary = GameConfig.WEAPONS[GameData.selected_weapon]
	fire_rate = weapon_data["fire_rate"] / GameData.player_stats["attack_speed_mult"]
	weapon_damage = weapon_data["damage"] * GameData.player_stats["damage_mult"]
	weapon_range = weapon_data["range"]

	coins = GameData.coins
```

`auto_shoot()` — 使用 weapon_range：
```gdscript
func auto_shoot() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node2D = null
	var min_distance: float = weapon_range

	for enemy in enemies:
		if enemy is Node2D:
			var distance: float = global_position.distance_to(enemy.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = enemy

	if closest_enemy:
		shoot_weapon(closest_enemy.global_position)

	shoot_timer = fire_rate
```

将 `shoot_bullet()` 重命名为 `shoot_weapon()` 并按 `projectile_type` 分发：
```gdscript
func shoot_weapon(target_pos: Vector2) -> void:
	var weapon_data: Dictionary = GameConfig.WEAPONS[GameData.selected_weapon]
	var projectile_type: String = weapon_data["projectile_type"]

	match projectile_type:
		"bullet":
			_shoot_bullet(target_pos)
		"boomerang":
			_shoot_boomerang(target_pos)
		"laser":
			_shoot_laser(target_pos)

func _shoot_bullet(target_pos: Vector2) -> void:
	var bullet: Area2D = SceneFactory.create_bullet()
	bullet.global_position = global_position
	bullet.direction = global_position.direction_to(target_pos)
	bullet.damage = weapon_damage
	var parent: Node = get_parent()
	if parent:
		parent.add_child(bullet)
	else:
		push_error("Player has no parent to add bullet to")
		bullet.queue_free()

func _shoot_boomerang(target_pos: Vector2) -> void:
	var boomerang: Area2D = SceneFactory.create_boomerang()
	boomerang.global_position = global_position
	boomerang.direction = global_position.direction_to(target_pos)
	boomerang.damage = weapon_damage
	boomerang.player = self
	var parent: Node = get_parent()
	if parent:
		parent.add_child(boomerang)
	else:
		push_error("Player has no parent to add boomerang to")
		boomerang.queue_free()

func _shoot_laser(target_pos: Vector2) -> void:
	var weapon_data: Dictionary = GameConfig.WEAPONS["laser"]
	var beam_range: float = weapon_data["beam_range"]
	var direction: Vector2 = global_position.direction_to(target_pos)
	var end_pos: Vector2 = global_position + direction * beam_range

	# 射线查询：检测线上所有敌人（贯穿）
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position, end_pos, 2  # collision_mask = 2 (enemies layer)
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	# 循环射线查询实现贯穿
	var hit_enemies: Array = []
	var from: Vector2 = global_position
	for i in range(20):  # 安全上限，防止无限循环
		query.from = from
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			break
		var collider: Node2D = result["collider"]
		if collider.is_in_group("enemies") and collider not in hit_enemies:
			hit_enemies.append(collider)
			if collider.has_method("take_damage"):
				collider.take_damage(weapon_damage)
		# 从命中点稍微偏移继续射线
		from = result["position"] + direction * 1.0
		query.exclude = query.exclude + [collider.get_rid()]

	# 生成视觉效果
	var beam: Node2D = SceneFactory.create_laser_beam()
	var parent: Node = get_parent()
	if parent:
		parent.add_child(beam)
		beam.fire(global_position, end_pos)
	else:
		push_error("Player has no parent to add laser beam to")
		beam.queue_free()
```

**Step 4: 运行所有测试确认通过**

Run: Godot GUT 运行全部测试
Expected: 全部 PASS

**Step 5: 提交**

```bash
git add scripts/entities/player.gd tests/unit/test_player_weapon.gd
git commit -m "feat: 重构射击逻辑，按 projectile_type 分发（bullet/boomerang/laser）"
```

---

### Task 6: 重构武器选择 UI

**Files:**
- Modify: `scripts/ui/weapon_select.gd`
- Modify: `scenes/ui/weapon_select.tscn`

**Step 1: 写失败测试**

创建 `tests/unit/test_weapon_select.gd`:

```gdscript
extends GutTest

# 武器选择 UI 数据驱动测试

func test_all_weapons_in_config_are_selectable():
	# 验证 GameConfig 中每个武器都有 name 字段用于 UI 显示
	for weapon_id in GameConfig.WEAPONS:
		assert_true(GameConfig.WEAPONS[weapon_id].has("name"),
			"武器 %s 应有 name 字段" % weapon_id)

func test_weapon_count_matches_config():
	assert_eq(GameConfig.WEAPONS.size(), 3, "应有 3 把武器可选")
```

**Step 2: 运行测试确认通过**

Expected: PASS（配置已在 Task 1 中更新）

**Step 3: 重写 weapon_select.gd 为数据驱动**

替换 `scripts/ui/weapon_select.gd` 全部内容：

```gdscript
extends Control

# 武器选择界面 — 数据驱动，从 GameConfig.WEAPONS 生成按钮

@onready var container: VBoxContainer = $VBoxContainer

func _ready() -> void:
	# 保留标题
	# 清除旧的硬编码按钮（保留 TitleLabel）
	for child in container.get_children():
		if child is Button:
			child.queue_free()

	# 从 GameConfig 动态生成武器按钮
	for weapon_id in GameConfig.WEAPONS:
		var weapon_data: Dictionary = GameConfig.WEAPONS[weapon_id]
		var button: Button = Button.new()
		button.text = weapon_data["name"]
		button.custom_minimum_size = GameConfig.UI_BUTTON_SIZE
		button.pressed.connect(_on_weapon_selected.bind(weapon_id))
		container.add_child(button)

func _on_weapon_selected(weapon_id: String) -> void:
	GameData.selected_weapon = weapon_id
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")
```

**Step 4: 修改 weapon_select.tscn — 删除硬编码按钮**

替换 `scenes/ui/weapon_select.tscn` 内容，只保留 Control + VBoxContainer + TitleLabel：

```
[gd_scene format=3 uid="uid://b1t3kht6tjtgi"]

[ext_resource type="Script" uid="uid://d3om02tgj5wxf" path="res://scripts/ui/weapon_select.gd" id="1_6yodv"]

[node name="WeaponSelect" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_6yodv")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 0
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -80.0
offset_right = 100.0
offset_bottom = 80.0

[node name="TitleLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "选择武器"
horizontal_alignment = 1
```

**Step 5: 运行测试确认通过**

Run: Godot GUT 运行全部测试
Expected: 全部 PASS

**Step 6: 提交**

```bash
git add scripts/ui/weapon_select.gd scenes/ui/weapon_select.tscn tests/unit/test_weapon_select.gd
git commit -m "refactor: 武器选择界面改为数据驱动，从 GameConfig 动态生成按钮"
```

---

### Task 7: 手动验收测试

**Files:** 无新增

**Step 1: 运行项目进行手动测试**

用 MCP `run_project` 或 Godot 编辑器运行项目。

验收清单：
1. 武器选择界面显示 3 个按钮：步枪、回旋镖、激光枪（无霰弹枪/狙击枪）
2. 选择步枪 → 进入战斗 → 自动发射直线子弹，命中敌人消失
3. 选择回旋镖 → 进入战斗 → 回旋镖飞出后折返，穿透敌人，回到玩家消失
4. 选择激光枪 → 进入战斗 → 红色激光线闪现，贯穿多个敌人
5. 回旋镖走位测试：发射后移动玩家，回程路径应追踪玩家新位置

**Step 2: 修复发现的问题**

根据手动测试结果修复 bug。

**Step 3: 运行全部单元测试**

Run: Godot GUT 运行全部测试
Expected: 全部 PASS

**Step 4: 提交修复（如有）**

```bash
git add -A
git commit -m "fix: 武器系统验收测试修复"
```

---

### Task 8: 运行全部测试 + 最终提交

**Step 1: 运行全部测试**

Run: Godot GUT 运行全部测试
Expected: 全部 PASS

**Step 2: 确认无遗留问题**

检查：
- `game_config.gd` 中无 shotgun/sniper 引用
- `player.gd` 中无 shotgun/sniper 硬编码
- `weapon_select.gd` 完全数据驱动
- SceneFactory 注册了 create_boomerang + create_laser_beam

**Step 3: 如有遗留，合并提交**

```bash
git add -A
git commit -m "chore: 武器系统扩展收尾清理"
```
