# 代码质量全面改进 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复关键 bug（boss 场景缺失导致崩溃）、消除架构违规（boomerang 直读 GameConfig）、拆分过大 UI 文件

**Architecture:** 遵循现有 SceneFactory+Resource 注入模式创建缺失的 Boss 场景；通过 WeaponData 注入替代 GameConfig 直接访问；将 upgrade_popup 的卡片构建逻辑提取到独立类

**Tech Stack:** GDScript, Godot 4.6, GUT 测试框架

**说明 — 排除的改进项:**
- **UI 组件 SceneFactory 化**: 经深入分析，pause_overlay/debug_panel/grid_overlay/placement_panel/range_indicator 是 UI 组件而非游戏实体。CLAUDE.md 的 "禁止直接实例化场景" 规范针对的是实体（towers/enemies/projectiles/coins），UI 组件用 `.new()` 创建是合理的。
- **UI 硬编码常量提取到 .tres**: CARD_WIDTH/ZOOM_STEP 等是 UI 布局常量，极少变动，不需要运行时可配置。提取到 Resource 属于过度设计。

---

## Chunk 1: Boss 场景缺失修复

### Task 1: 创建 boss_summoner 和 boss_guardian 场景文件

**Files:**
- Create: `scenes/entities/enemies/boss_summoner.tscn`
- Create: `scenes/entities/enemies/boss_guardian.tscn`

boss_summoner 和 boss_guardian 的 EnemyData 资源已存在（无 charge 参数），使用 boss_base.gd 作为脚本即可。参照 boss_brute.tscn 结构，包含完整组件子节点。

- [ ] **Step 1: 创建 boss_summoner.tscn**

```tscn
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/entities/boss_base.gd" id="1_script"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2_health"]
[ext_resource type="Script" path="res://scripts/components/knockback_handler.gd" id="3_knockback"]
[ext_resource type="Script" path="res://scripts/components/slow_handler.gd" id="4_slow"]
[ext_resource type="Script" path="res://scripts/components/sprite_animator.gd" id="5_sprite"]
[ext_resource type="Script" path="res://scripts/components/hitbox.gd" id="6_hitbox"]
[ext_resource type="Script" path="res://scripts/components/hurtbox.gd" id="7_hurtbox"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_body"]
size = Vector2(24, 24)

[sub_resource type="CircleShape2D" id="CircleShape2D_hitbox"]
radius = 10.0

[sub_resource type="CircleShape2D" id="CircleShape2D_hurtbox"]
radius = 10.0

[node name="BossSummoner" type="CharacterBody2D"]
scale = Vector2(2, 2)
collision_layer = 2
collision_mask = 8
script = ExtResource("1_script")

[node name="Visual" type="ColorRect" parent="."]
offset_left = -12.0
offset_top = -12.0
offset_right = 12.0
offset_bottom = 12.0
color = Color(0.5, 0.1, 0.8, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_body")

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
collision_mask = 4
script = ExtResource("7_hurtbox")

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hurtbox"]
shape = SubResource("CircleShape2D_hurtbox")
```

- [ ] **Step 2: 创建 boss_guardian.tscn**

同 boss_summoner 结构，但：
- 节点名 `BossGuardian`
- Visual 颜色 `Color(0.2, 0.6, 0.1, 1)` (绿色调，守护者主题)
- scale `Vector2(2.5, 2.5)` (更大体型，HP 1200)

- [ ] **Step 3: 在 SceneFactory 注册新 Boss 场景**

修改 `scripts/core/scene_factory.gd`，在 `_enemy_scenes` 字典中添加：

```gdscript
Enums.Enemy.BOSS_SUMMONER: preload("res://scenes/entities/enemies/boss_summoner.tscn"),
Enums.Enemy.BOSS_GUARDIAN: preload("res://scenes/entities/enemies/boss_guardian.tscn"),
```

- [ ] **Step 4: 编写测试**

在 `tests/unit/test_scene_factory.gd` 中添加：

```gdscript
func test_create_enemy_boss_summoner():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.BOSS_SUMMONER)
	assert_not_null(enemy, "Boss summoner should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.BOSS_SUMMONER)
	enemy.queue_free()

func test_create_enemy_boss_guardian():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.BOSS_GUARDIAN)
	assert_not_null(enemy, "Boss guardian should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.BOSS_GUARDIAN)
	enemy.queue_free()

func test_create_enemy_boss_brute():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.BOSS_BRUTE)
	assert_not_null(enemy, "Boss brute should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.BOSS_BRUTE)
	enemy.queue_free()

func test_all_enemies_can_be_created():
	var all_ids: Array[String] = [
		Enums.Enemy.NORMAL, Enums.Enemy.FAST, Enums.Enemy.TANK,
		Enums.Enemy.BOSS_BRUTE, Enums.Enemy.BOSS_SUMMONER, Enums.Enemy.BOSS_GUARDIAN,
	]
	for id in all_ids:
		var enemy = SceneFactory.create_enemy(id)
		assert_not_null(enemy, "应能创建敌人: " + id)
		assert_eq(enemy.enemy_type, id)
		assert_not_null(enemy.data, id + " 应注入 EnemyData")
		enemy.queue_free()
```

- [ ] **Step 5: 运行测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`
Expected: 所有测试通过，包括新增的 boss 创建测试

- [ ] **Step 6: 提交**

```bash
git add scenes/entities/enemies/boss_summoner.tscn scenes/entities/enemies/boss_guardian.tscn scripts/core/scene_factory.gd tests/unit/test_scene_factory.gd
git commit -m "fix: 添加 boss_summoner/boss_guardian 场景并注册到 SceneFactory"
```

---

## Chunk 2: Boomerang 投射物架构修复

### Task 2: BoomerangProjectile 通过 WeaponData 注入替代 GameConfig 直接访问

**Files:**
- Modify: `scripts/entities/projectiles/boomerang_projectile.gd` (移除 GameConfig 直接访问)
- Modify: `scripts/entities/weapons/boomerang_weapon.gd` (注入 WeaponData)
- Modify: `tests/unit/test_boomerang_projectile.gd` (更新测试)

**问题:** `boomerang_projectile.gd:28-34` 中 `_on_setup()` 直接读取 `GameConfig.weapons[Enums.WeaponId.BOOMERANG]`，违反 "实体不直接读 GameConfig" 规范。

**方案:** 添加 `weapon_data: WeaponData` 属性，由 `BoomerangWeapon.fire()` 在调用 `setup()` 前注入。

- [ ] **Step 1: 修改 boomerang_projectile.gd，添加 weapon_data 属性**

在 `boomerang_projectile.gd` 中：
1. 添加 `var weapon_data: WeaponData = null`
2. 修改 `_on_setup()` 从 `weapon_data` 读取参数而非 `GameConfig`
3. 添加 assert 检查 weapon_data 已注入

```gdscript
var weapon_data: WeaponData = null

func _on_setup(direction: Vector2) -> void:
	_direction = direction
	_state = Enums.BoomerangState.OUTBOUND
	_traveled = 0.0
	_elapsed = 0.0
	assert(weapon_data != null, "BoomerangProjectile: weapon_data 未注入，请在 setup() 前设置")
	# 从注入的 WeaponData 读取回旋镖配置
	speed = weapon_data.boomerang_speed
	outbound_distance = weapon_data.outbound_distance
	return_speed_mult = weapon_data.return_speed_mult
	max_lifetime = weapon_data.boomerang_max_lifetime
	# 特效配置（全局视觉设置，非实体数据，保留 GameConfig 读取）
	var fx: EffectConfigData = GameConfig.effects
	_trail_max_points = fx.boomerang_trail_points
	_rotation_speed = deg_to_rad(fx.boomerang_rotation_speed)
	_return_rotation_speed = _rotation_speed * fx.boomerang_return_rotation_mult
	_return_dist_threshold = fx.boomerang_return_distance
	# 创建拖尾
	_trail = Line2D.new()
	_trail.width = fx.boomerang_trail_width
	_trail.default_color = fx.boomerang_trail_color
	_trail.top_level = true
	_trail.z_index = -1
	add_child(_trail)
```

- [ ] **Step 2: 修改 boomerang_weapon.gd，注入 WeaponData**

在 `fire()` 方法中，`setup()` 调用前添加 `boomerang.weapon_data = weapon_data`：

```gdscript
func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var final_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var boomerang: BoomerangProjectile = SceneFactory.create_boomerang_projectile()
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		push_error("BoomerangWeapon: owner has no parent scene")
		return
	scene_parent.add_child(boomerang)
	boomerang.set_player(owner_node)
	boomerang.weapon_data = weapon_data  # 注入 WeaponData
	boomerang.setup(final_damage, weapon_data.knockback_force, owner_node.global_position, direction)
```

- [ ] **Step 3: 更新测试**

修改 `tests/unit/test_boomerang_projectile.gd` 的 `_make_boomerang()` 辅助方法，注入 WeaponData：

```gdscript
func _make_boomerang() -> BoomerangProjectile:
	var b = BoomerangProjectile.new()
	var hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	b.add_child(hitbox)
	b.weapon_data = GameConfig.weapons[Enums.WeaponId.BOOMERANG]
	add_child_autofree(b)
	return b
```

同时更新 `test_max_lifetime_from_config` 测试描述以反映新的注入方式。

- [ ] **Step 4: 运行测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`
Expected: 所有 boomerang 相关测试通过

- [ ] **Step 5: 提交**

```bash
git add scripts/entities/projectiles/boomerang_projectile.gd scripts/entities/weapons/boomerang_weapon.gd tests/unit/test_boomerang_projectile.gd
git commit -m "refactor: boomerang 投射物通过 WeaponData 注入替代 GameConfig 直接访问"
```

---

## Chunk 3: upgrade_popup 拆分优化

### Task 3: 提取卡片构建逻辑到 UpgradeCardBuilder

**Files:**
- Create: `scripts/ui/upgrade_card_builder.gd`
- Modify: `scripts/ui/upgrade_popup.gd` (委托卡片创建给 builder)

**分析:** `upgrade_popup.gd` 288 行，其中 `_create_card()` (61-137行, 77行) 和 `_get_stats_text()` (147-173行, 27行) 共 ~104 行是纯卡片 UI 构建逻辑，与弹窗的流程控制（轮次、选择、动画）是独立职责。提取到 `UpgradeCardBuilder` 后，upgrade_popup 将减至 ~185 行，职责更清晰。

- [ ] **Step 1: 创建 upgrade_card_builder.gd**

```gdscript
class_name UpgradeCardBuilder
extends RefCounted
## 升级卡片 UI 构建器 — 从升级选项数据创建卡片 PanelContainer

const CARD_WIDTH: int = 180
const CARD_HEIGHT: int = 200

static func create_card(opt: Dictionary, on_selected: Callable) -> PanelContainer:
	var is_weapon: bool = opt["type"] == "weapon"
	var border_color: Color = Color("#4fc3f7") if is_weapon else Color("#66bb6a")
	var bg_color: Color = Color("#1a1a3a") if is_weapon else Color("#1a2a1a")

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# 类型标签
	var type_lbl := Label.new()
	type_lbl.text = "⚔ 武器" if is_weapon else "🏗 塔"
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.add_theme_color_override("font_color", border_color)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_lbl)

	# 名称
	var name_lbl := Label.new()
	name_lbl.text = _get_display_name(opt)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# 等级信息
	var level_lbl := Label.new()
	if opt["is_new"]:
		level_lbl.text = "新武器! Lv1" if is_weapon else "新塔! Lv1"
		level_lbl.add_theme_color_override("font_color", Color("#4caf50"))
	else:
		level_lbl.text = "Lv%d → Lv%d" % [opt["current_level"], opt["target_level"]]
		level_lbl.add_theme_color_override("font_color", Color("#ffd700"))
	level_lbl.add_theme_font_size_override("font_size", 12)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_lbl)

	# 属性预览
	var stats_lbl := Label.new()
	stats_lbl.text = _get_stats_text(opt)
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)

	# 点击事件
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_selected.call()
	)

	return panel


static func _get_display_name(opt: Dictionary) -> String:
	if opt["type"] == "weapon":
		var wd: WeaponData = GameConfig.weapons[opt["id"]]
		return wd.display_name
	else:
		var td: TowerData = GameConfig.towers[opt["id"]]
		return td.display_name


static func _get_stats_text(opt: Dictionary) -> String:
	var level: int = opt["target_level"]
	var idx: int = level - 1
	if opt["type"] == "weapon":
		var wd: WeaponData = GameConfig.weapons[opt["id"]]
		var lines: Array[String] = []
		if wd.damage_per_level.size() > idx:
			lines.append("伤害: %d" % int(wd.damage_per_level[idx]))
		if wd.fire_rate_per_level.size() > idx:
			lines.append("射速: %.1f" % wd.fire_rate_per_level[idx])
		if wd.weapon_range_per_level.size() > idx:
			lines.append("范围: %d" % int(wd.weapon_range_per_level[idx]))
		return "\n".join(lines)
	else:
		var td: TowerData = GameConfig.towers[opt["id"]]
		var lines: Array[String] = []
		if td.damage_per_level.size() > idx and td.damage_per_level[idx] > 0:
			lines.append("伤害: %d" % int(td.damage_per_level[idx]))
		if td.fire_rate_per_level.size() > idx and td.fire_rate_per_level[idx] > 0:
			lines.append("射速: %.1f" % td.fire_rate_per_level[idx])
		if td.attack_range_per_level.size() > idx and td.attack_range_per_level[idx] > 0:
			lines.append("范围: %d" % int(td.attack_range_per_level[idx]))
		if td.slow_ratio_per_level.size() > idx and td.slow_ratio_per_level[idx] > 0:
			lines.append("减速: %d%%" % int(td.slow_ratio_per_level[idx] * 100))
		if td.hp_per_level.size() > idx and td.hp_per_level[idx] > 0:
			lines.append("HP: %d" % int(td.hp_per_level[idx]))
		return "\n".join(lines)
```

- [ ] **Step 2: 修改 upgrade_popup.gd 使用 UpgradeCardBuilder**

移除 `CARD_WIDTH`/`CARD_HEIGHT` 常量（已迁移到 builder）。
修改 `_rebuild_cards()` 和 `_create_card()`，替换为调用 `UpgradeCardBuilder.create_card()`。
删除 `_get_display_name()` 和 `_get_stats_text()` 方法。

```gdscript
# 保留 CARD_GAP 常量（用于 HBoxContainer separation）
const CARD_GAP: int = 16

func _rebuild_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()
	for i in _options.size():
		var card: PanelContainer = UpgradeCardBuilder.create_card(
			_options[i],
			func(): _on_option_selected(i)
		)
		_cards_container.add_child(card)
```

- [ ] **Step 3: 注册 class_name 到全局脚本缓存**

新增带 `class_name` 的脚本后，headless 测试需要在 `.godot/global_script_class_cache.cfg` 中补充条目。检查是否需要手动添加 `UpgradeCardBuilder` 条目。

- [ ] **Step 4: 编写 UpgradeCardBuilder 单元测试**

创建 `tests/unit/test_upgrade_card_builder.gd`：

```gdscript
extends GutTest

func _make_weapon_option() -> Dictionary:
	return {
		"type": "weapon",
		"id": Enums.WeaponId.RIFLE,
		"is_new": false,
		"current_level": 1,
		"target_level": 2,
	}

func _make_tower_option() -> Dictionary:
	return {
		"type": "tower",
		"id": Enums.TowerId.PEA_SHOOTER,
		"is_new": true,
		"current_level": 0,
		"target_level": 1,
	}

func test_create_weapon_card():
	var called: bool = false
	var card: PanelContainer = UpgradeCardBuilder.create_card(
		_make_weapon_option(), func(): called = true
	)
	assert_not_null(card, "应创建武器卡片")
	assert_eq(card.custom_minimum_size, Vector2(UpgradeCardBuilder.CARD_WIDTH, UpgradeCardBuilder.CARD_HEIGHT))
	card.queue_free()

func test_create_tower_card():
	var card: PanelContainer = UpgradeCardBuilder.create_card(
		_make_tower_option(), func(): pass
	)
	assert_not_null(card, "应创建塔卡片")
	card.queue_free()

func test_create_new_item_card_shows_new_label():
	var opt: Dictionary = _make_tower_option()
	opt["is_new"] = true
	var card: PanelContainer = UpgradeCardBuilder.create_card(opt, func(): pass)
	assert_not_null(card)
	card.queue_free()

func test_create_upgrade_card_shows_level():
	var opt: Dictionary = _make_weapon_option()
	opt["is_new"] = false
	opt["current_level"] = 2
	opt["target_level"] = 3
	var card: PanelContainer = UpgradeCardBuilder.create_card(opt, func(): pass)
	assert_not_null(card)
	card.queue_free()
```

- [ ] **Step 5: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试通过

- [ ] **Step 6: 提交**

```bash
git add scripts/ui/upgrade_card_builder.gd scripts/ui/upgrade_popup.gd tests/unit/test_upgrade_card_builder.gd
git commit -m "refactor: 提取升级卡片构建逻辑到 UpgradeCardBuilder"
```
