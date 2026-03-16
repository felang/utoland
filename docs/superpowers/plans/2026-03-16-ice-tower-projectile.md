# 冰花塔投射物化 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将冰花塔从 Area2D 持续减速改为射击型，弹道命中敌人造成低伤害+持续时间减速。

**Architecture:** 复用 `tower_shooter.gd` 射击逻辑，扩展支持可选的减速参数。`BulletProjectile` 已内置 `slow_on_hit`/`slow_duration`，无需修改弹道类。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

---

## File Map

| 操作 | 文件 | 职责 |
|------|------|------|
| Modify | `scripts/resources/tower_data.gd` | 新增 `slow_duration_per_level` 字段 |
| Modify | `resources/towers/ice_flower.tres` | 新增 `damage_per_level`、`fire_rate_per_level`、`slow_duration_per_level`，更新描述 |
| Modify | `scripts/entities/towers/tower_shooter.gd` | 移除硬编码 `tower_type`，新增减速弹道支持 |
| Modify | `scripts/entities/towers/tower_generator.gd` | 移除硬编码 `tower_type`（一致性修复） |
| Rewrite | `scenes/entities/towers/tower_ice_flower.tscn` | 改用 `tower_shooter.gd`，替换 SlowArea 为 DetectArea+ShootTimer |
| Delete | `scripts/entities/towers/tower_slow.gd` | 不再使用 |
| Modify | `tests/unit/test_tower_level.gd` | 更新冰花塔测试 |
| Modify | `tests/unit/test_scene_factory.gd` | 更新 `test_create_tower_slow` 测试名和断言 |

---

### Task 1: TowerData 新增 slow_duration_per_level 字段

**Files:**
- Modify: `scripts/resources/tower_data.gd:17` (在 `slow_ratio_per_level` 之后)

- [ ] **Step 1: 在 `tower_data.gd` 的 `slow_ratio_per_level` 后新增字段**

在第 17 行 `slow_ratio_per_level` 之后添加：

```gdscript
@export var slow_duration_per_level: PackedFloat32Array = []
```

- [ ] **Step 2: Commit**

```bash
git add scripts/resources/tower_data.gd
git commit -m "feat: TowerData 新增 slow_duration_per_level 字段"
```

---

### Task 2: 更新 ice_flower.tres 资源数据

**Files:**
- Modify: `resources/towers/ice_flower.tres`

- [ ] **Step 1: 更新 ice_flower.tres**

完整内容（保留 Godot 资源格式头）：

```
[gd_resource type="Resource" script_class="TowerData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/tower_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "ice_flower"
display_name = "冰花"
description = "射出寒冰弹，命中敌人造成伤害并减速。"
icon_path = "res://assets/towers/ice_flower/sprite.png"
max_level = 3
hp_per_level = PackedFloat32Array(70, 125, 200)
damage_per_level = PackedFloat32Array(3, 5, 8)
fire_rate_per_level = PackedFloat32Array(0.8, 0.7, 0.6)
attack_range_per_level = PackedFloat32Array(100, 120, 150)
slow_ratio_per_level = PackedFloat32Array(0.3, 0.4, 0.5)
slow_duration_per_level = PackedFloat32Array(1.5, 2.0, 2.5)
sell_price_per_level = PackedInt32Array(3, 7, 21)
```

- [ ] **Step 2: Commit**

```bash
git add resources/towers/ice_flower.tres
git commit -m "feat: ice_flower.tres 新增 damage/fire_rate/slow_duration 数据"
```

---

### Task 3: tower_shooter.gd 移除硬编码 tower_type + 新增减速支持

**Files:**
- Modify: `scripts/entities/towers/tower_shooter.gd`
- Modify: `scripts/entities/towers/tower_generator.gd:12` (同步移除硬编码)

- [ ] **Step 1: 修改 tower_shooter.gd**

移除 `_ready()` 中第 12 行 `tower_type = Enums.TowerId.PEA_SHOOTER`。

新增两个成员变量（在现有 `@export` 之后）：

```gdscript
var slow_on_hit: float = 0.0
var slow_duration: float = 0.0
```

在 `_apply_level_stats()` 末尾追加减速数据读取：

```gdscript
	# 减速弹道（仅冰花塔有这些字段）
	if data.slow_ratio_per_level.size() > 0:
		slow_on_hit = data.slow_ratio_per_level[idx]
	if data.slow_duration_per_level.size() > 0:
		slow_duration = data.slow_duration_per_level[idx]
```

在 `_shoot_nearest_enemy()` 中，`bullet.setup(...)` 之后、`play_attack_animation()` 之前追加：

```gdscript
		if slow_on_hit > 0.0:
			bullet.slow_on_hit = slow_on_hit
			bullet.slow_duration = slow_duration
```

- [ ] **Step 2: 修改 tower_generator.gd**

移除 `_ready()` 中第 12 行 `tower_type = Enums.TowerId.SUNFLOWER`。

`tower_type` 由 `SceneFactory.create_tower()` 在实例化时注入（在 `_ready()` 之前），不需要脚本中硬编码。

- [ ] **Step 3: Commit**

```bash
git add scripts/entities/towers/tower_shooter.gd scripts/entities/towers/tower_generator.gd
git commit -m "feat: tower_shooter 支持减速弹道 + 移除各塔脚本硬编码 tower_type"
```

---

### Task 4: 重写 tower_ice_flower.tscn 场景

**Files:**
- Rewrite: `scenes/entities/towers/tower_ice_flower.tscn`

- [ ] **Step 1: 重写场景文件**

将 `tower_ice_flower.tscn` 改为使用 `tower_shooter.gd`，用 `DetectArea` + `ShootTimer` 替换 `SlowArea`。根节点改名为 `TowerShooter`（与脚本匹配）。

完整内容：

```
[gd_scene format=3 uid="uid://ucsglghc6mnm"]

[ext_resource type="Script" uid="uid://ckwxfmslcyshb" path="res://scripts/entities/towers/tower_shooter.gd" id="1_shooter"]
[ext_resource type="Texture2D" path="res://assets/towers/ice_flower/sprite.png" id="2_sprite"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="3_health"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_body"]
size = Vector2(16, 16)

[sub_resource type="CircleShape2D" id="CircleShape2D_detect"]
radius = 100.0

[sub_resource type="SpriteFrames" id="SpriteFrames_ice"]
animations = [{
"frames": [{
"duration": 1.0,
"texture": ExtResource("2_sprite")
}],
"loop": true,
"name": &"idle",
"speed": 5.0
}, {
"frames": [{
"duration": 1.0,
"texture": ExtResource("2_sprite")
}],
"loop": false,
"name": &"attack",
"speed": 5.0
}]

[node name="TowerShooter" type="StaticBody2D"]
collision_layer = 8
collision_mask = 2
script = ExtResource("1_shooter")

[node name="Visual" type="AnimatedSprite2D" parent="."]
sprite_frames = SubResource("SpriteFrames_ice")
animation = &"idle"
autoplay = "idle"

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_body")

[node name="DetectArea" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 2

[node name="CollisionShape2D" type="CollisionShape2D" parent="DetectArea"]
shape = SubResource("CircleShape2D_detect")

[node name="ShootTimer" type="Timer" parent="."]
wait_time = 0.8
one_shot = false
autostart = false

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("3_health")
```

注意：
- 保留原始 scene UID `uid://ucsglghc6mnm`
- `tower_shooter.gd` 的 UID 从 `tower_pea_shooter.tscn` 复制：`uid://ckwxfmslcyshb`
- DetectArea 初始半径 100（Lv1 attack_range），由 `_apply_level_stats()` 未直接更新碰撞形状，但 `get_overlapping_bodies()` 配合 `min_dist < attack_range` 过滤
- ShootTimer wait_time 0.8（Lv1 fire_rate），由 `_apply_level_stats()` 更新

- [ ] **Step 2: Commit**

```bash
git add scenes/entities/towers/tower_ice_flower.tscn
git commit -m "feat: tower_ice_flower.tscn 改用 tower_shooter 射击模式"
```

---

### Task 5: 删除 tower_slow.gd

**Files:**
- Delete: `scripts/entities/towers/tower_slow.gd`

- [ ] **Step 1: 删除文件**

```bash
git rm scripts/entities/towers/tower_slow.gd
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: 删除不再使用的 tower_slow.gd"
```

---

### Task 6: 更新测试

**Files:**
- Modify: `tests/unit/test_tower_level.gd`
- Modify: `tests/unit/test_scene_factory.gd`

- [ ] **Step 1: 更新 test_tower_level.gd**

在 `test_tower_ice_flower_has_level_fields()` 中增加新字段断言，将 `test_tower_slow_has_level_fields` 重命名：

```gdscript
func test_tower_ice_flower_has_level_fields():
	var td: TowerData = GameConfig.towers["ice_flower"]
	assert_eq(td.hp_per_level.size(), 3, "冰花塔应有 3 级 HP")
	assert_eq(td.damage_per_level.size(), 3, "冰花塔应有 3 级伤害")
	assert_eq(td.fire_rate_per_level.size(), 3, "冰花塔应有 3 级射速")
	assert_eq(td.slow_ratio_per_level.size(), 3, "冰花塔应有 3 级减速比例")
	assert_eq(td.slow_duration_per_level.size(), 3, "冰花塔应有 3 级减速持续")
```

删除原来的 `test_tower_slow_has_level_fields()` 函数（原第 21-23 行）。

- [ ] **Step 2: 更新 test_scene_factory.gd**

将 `test_create_tower_slow` 重命名为 `test_create_tower_ice_flower`：

```gdscript
func test_create_tower_ice_flower():
	var tower = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	assert_not_null(tower, "Ice flower tower should be created")
	assert_eq(tower.tower_type, Enums.TowerId.ICE_FLOWER, "Tower type should be 'ice_flower'")
	tower.queue_free()
```

- [ ] **Step 3: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部通过

- [ ] **Step 4: Commit**

```bash
git add tests/unit/test_tower_level.gd tests/unit/test_scene_factory.gd
git commit -m "test: 更新冰花塔相关测试（适配射击模式重设计）"
```
