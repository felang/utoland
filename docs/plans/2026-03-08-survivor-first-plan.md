# 类幸存者优先 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 跳过塔布置阶段，过滤塔相关商店物品，新增 12 个角色/武器/生存类商店物品，形成类幸存者核心玩法循环。

**Architecture:** 修改场景跳转（map_select → main, shop → main），在商店生成时按 effect_type 过滤塔物品，新增 GameData 字段和 Enums 常量支撑新物品效果，在 player.gd / bullet_weapon.gd / bullet_projectile.gd / coin.gd / item_effect_manager.gd 中接入效果逻辑。

**Tech Stack:** Godot 4.6 / GDScript / GUT 测试框架

---

## 塔相关 effect_type 黑名单

以下 effect_type 在商店物品池中过滤掉：
- `tower_stat`
- `tower_link`
- `wave_heal_towers`
- `tower_regen`
- `symbiosis`
- `war_machine`（tower_mult 加成无塔可用，且扣血代价不值）

---

## Task 1: 场景流程跳转修改

**Files:**
- Modify: `scripts/ui/map_select.gd:32`
- Modify: `scripts/systems/shop_manager.gd:325`
- Modify: `scripts/ui/main.gd:3-14`

**Step 1: 修改 map_select.gd — 跳过 placement 直接进 main**

```gdscript
# map_select.gd:32 — 改 PLACEMENT 为 MAIN
SceneManager.go_to(Enums.Scene.MAIN)
```

**Step 2: 修改 shop_manager.gd — 确认后直接进 main**

```gdscript
# shop_manager.gd:325 — 改 PLACEMENT 为 MAIN
func _on_confirm_pressed() -> void:
	SceneManager.go_to(Enums.Scene.MAIN)
```

**Step 3: 修改 main.gd — 跳过塔恢复逻辑**

```gdscript
# main.gd — 注释掉塔恢复，后续加回
extends Node2D

func _ready() -> void:
	# 塔防阶段暂时跳过（后续版本恢复）
	# for tower_data: Dictionary in GameData.tower_inventory:
	# 	var tower_type: String = tower_data["type"]
	# 	var tower_pos: Vector2 = tower_data["position"]
	# 	var tower: Node2D = SceneFactory.create_tower(tower_type)
	# 	if tower:
	# 		tower.global_position = tower_pos
	# 		add_child(tower)
	pass
```

**Step 4: 运行项目验证流程**

运行游戏，验证：选择角色 → 选择地图 → 直接进入战斗 → 波次结束进商店 → 确认后直接进下一波战斗。

**Step 5: 提交**

```bash
git add scripts/ui/map_select.gd scripts/systems/shop_manager.gd scripts/ui/main.gd
git commit -m "feat: 跳过塔布置阶段，场景流程改为 map_select → main → shop → main"
```

---

## Task 2: 商店过滤塔相关物品

**Files:**
- Modify: `scripts/systems/shop_manager.gd:88-133`

**Step 1: 在 _generate_shop() 中添加塔物品过滤**

在 `_generate_shop()` 方法的物品分组循环中，过滤掉塔相关 effect_type：

```gdscript
# shop_manager.gd — 在 _generate_shop() 开头添加塔 effect_type 黑名单
const TOWER_EFFECT_TYPES: Array = [
	Enums.ItemEffect.TOWER_STAT,
	Enums.ItemEffect.TOWER_LINK,
	Enums.ItemEffect.WAVE_HEAL_TOWERS,
	Enums.ItemEffect.TOWER_REGEN,
	Enums.ItemEffect.SYMBIOSIS,
	Enums.ItemEffect.WAR_MACHINE,
]
```

在 `by_rarity` 分组循环中添加过滤：

```gdscript
# 原来：
for item in GameConfig.items.values():
	if by_rarity.has(item.rarity):
		by_rarity[item.rarity].append(item)

# 改为：
for item in GameConfig.items.values():
	if item.effect_type in TOWER_EFFECT_TYPES:
		continue
	if by_rarity.has(item.rarity):
		by_rarity[item.rarity].append(item)
```

**Step 2: 运行项目验证商店不出现塔物品**

打开商店刷新多次，确认不出现塔相关物品（如加固、联动、纳米修复等）。

**Step 3: 提交**

```bash
git add scripts/systems/shop_manager.gd
git commit -m "feat: 商店过滤塔相关 effect_type 物品"
```

---

## Task 3: 新增 Enums 常量和 GameData 字段

**Files:**
- Modify: `scripts/core/enums.gd:93-108` — 新增 ItemEffect 常量
- Modify: `scripts/core/game_data.gd` — 新增运行时字段

**Step 1: 新增 ItemEffect 常量**

在 `Enums.ItemEffect` 中追加：

```gdscript
const BULLET_SPEED     = "bullet_speed"       # 弹速提升
const WEAPON_RANGE     = "weapon_range"        # 射程增加
const CRIT             = "crit"               # 暴击
const SPLIT            = "split"              # 弹道分裂
const WAVE_SHIELD      = "wave_shield"        # 每波护盾
const WAVE_HEAL_PLAYER = "wave_heal_player"   # 每波回血
const DAMAGE_REDUCTION = "damage_reduction"   # 减伤
const DODGE            = "dodge"              # 闪避
const MAGNET           = "magnet"             # 磁铁
const SLOW_AURA        = "slow_aura"          # 减速光环
const AUTO_DASH        = "auto_dash"          # 自动冲刺
```

**Step 2: 新增 GameData 字段**

在 `GameData` 中添加（在 `tower_cost_mult` 之后）：

```gdscript
## 弹速倍率（1.0 = 不变）
var bullet_speed_mult: float = 1.0
## 武器射程倍率
var weapon_range_mult: float = 1.0
## 暴击率（0.0-1.0）
var crit_chance: float = 0.0
## 暴击伤害倍率
var crit_damage_mult: float = 2.0
## 弹道分裂数（0 = 不分裂）
var split_count: int = 0
## 每波护盾层数（每波开始重置）
var wave_shield_count: int = 0
## 当前护盾层数
var current_shield: int = 0
## 每波回血比例（最大HP的百分比）
var wave_heal_ratio: float = 0.0
## 减伤比例（0.0-1.0）
var damage_reduction: float = 0.0
## 闪避率（0.0-1.0）
var dodge_chance: float = 0.0
## 金币磁铁范围倍率
var coin_magnet_mult: float = 1.0
## 减速光环：是否激活 + 减速比例
var slow_aura_active: bool = false
var slow_aura_ratio: float = 0.0
var slow_aura_range: float = 100.0
## 自动冲刺
var auto_dash_active: bool = false
var auto_dash_interval: float = 10.0
var auto_dash_distance: float = 80.0
```

**Step 3: 在 reset() 中重置新字段**

```gdscript
# 在 reset() 方法的 tower_cost_mult = 1.0 之后追加：
bullet_speed_mult = 1.0
weapon_range_mult = 1.0
crit_chance = 0.0
crit_damage_mult = 2.0
split_count = 0
wave_shield_count = 0
current_shield = 0
wave_heal_ratio = 0.0
damage_reduction = 0.0
dodge_chance = 0.0
coin_magnet_mult = 1.0
slow_aura_active = false
slow_aura_ratio = 0.0
slow_aura_range = 100.0
auto_dash_active = false
auto_dash_interval = 10.0
auto_dash_distance = 80.0
```

**Step 4: 提交**

```bash
git add scripts/core/enums.gd scripts/core/game_data.gd
git commit -m "feat: 新增 11 个 ItemEffect 常量和对应 GameData 字段"
```

---

## Task 4: shop_manager 接入新物品效果分发

**Files:**
- Modify: `scripts/systems/shop_manager.gd:152-195` — `_apply_item_effect()` 新增 match 分支

**Step 1: 在 _apply_item_effect() 中添加新效果处理**

在 `Enums.ItemEffect.DESTINY` 之前追加：

```gdscript
Enums.ItemEffect.BULLET_SPEED:
	GameData.bullet_speed_mult += p.get("mult", 0.2)
Enums.ItemEffect.WEAPON_RANGE:
	GameData.weapon_range_mult += p.get("mult", 0.15)
Enums.ItemEffect.CRIT:
	GameData.crit_chance += p.get("chance", 0.10)
Enums.ItemEffect.SPLIT:
	GameData.split_count += p.get("count", 2)
Enums.ItemEffect.WAVE_SHIELD:
	GameData.wave_shield_count += p.get("count", 1)
Enums.ItemEffect.WAVE_HEAL_PLAYER:
	GameData.wave_heal_ratio += p.get("ratio", 0.10)
Enums.ItemEffect.DAMAGE_REDUCTION:
	GameData.damage_reduction += p.get("ratio", 0.10)
Enums.ItemEffect.DODGE:
	GameData.dodge_chance += p.get("chance", 0.15)
Enums.ItemEffect.MAGNET:
	GameData.coin_magnet_mult += p.get("mult", 0.50)
Enums.ItemEffect.SLOW_AURA:
	GameData.slow_aura_active = true
	GameData.slow_aura_ratio += p.get("ratio", 0.15)
	GameData.slow_aura_range = max(GameData.slow_aura_range, p.get("range", 100.0))
Enums.ItemEffect.AUTO_DASH:
	GameData.auto_dash_active = true
	GameData.auto_dash_interval = min(GameData.auto_dash_interval, p.get("interval", 10.0))
	GameData.auto_dash_distance = max(GameData.auto_dash_distance, p.get("distance", 80.0))
```

**Step 2: 提交**

```bash
git add scripts/systems/shop_manager.gd
git commit -m "feat: shop_manager 接入 11 种新物品效果分发"
```

---

## Task 5: 创建 12 个新物品 .tres 文件

**Files:**
- Create: `resources/items/` 下 12 个 .tres 文件

所有文件遵循相同格式模板。以下列出每个文件的具体内容：

**Step 1: 武器强化类（shooter 标签）**

`resources/items/shooter_bulletspeed.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "bullet_speed_boost"
display_name = "疾风弹"
description = "投射物速度+20%"
tags = PackedStringArray("shooter")
rarity = "common"
effect_type = "bullet_speed"
effect_params = {"mult": 0.2}
cost_min = 15
cost_max = 25
max_stack = 3
```

`resources/items/shooter_longrange.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "weapon_range_boost"
display_name = "鹰眼瞄准"
description = "武器射程+15%"
tags = PackedStringArray("shooter")
rarity = "common"
effect_type = "weapon_range"
effect_params = {"mult": 0.15}
cost_min = 15
cost_max = 25
max_stack = 3
```

`resources/items/shooter_critshot.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "crit_shot"
display_name = "致命精准"
description = "10%概率造成双倍伤害"
tags = PackedStringArray("shooter")
rarity = "rare"
effect_type = "crit"
effect_params = {"chance": 0.10}
cost_min = 30
cost_max = 45
max_stack = 3
```

`resources/items/shooter_split.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "bullet_split"
display_name = "裂变弹头"
description = "投射物命中后分裂为2个小弹"
tags = PackedStringArray("shooter")
rarity = "epic"
effect_type = "split"
effect_params = {"count": 2, "damage_mult": 0.5}
cost_min = 55
cost_max = 75
max_stack = 1
```

**Step 2: 生存防御类（universal 标签）**

`resources/items/universal_shield.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "wave_shield"
display_name = "能量护盾"
description = "每波开始获得1层护盾（挡1次伤害）"
tags = PackedStringArray("universal")
rarity = "rare"
effect_type = "wave_shield"
effect_params = {"count": 1}
cost_min = 30
cost_max = 45
max_stack = 3
```

`resources/items/universal_waveheal.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "wave_heal"
display_name = "战后修整"
description = "每波结束回复10%最大生命"
tags = PackedStringArray("universal")
rarity = "common"
effect_type = "wave_heal_player"
effect_params = {"ratio": 0.10}
cost_min = 15
cost_max = 25
max_stack = 3
```

`resources/items/universal_armor.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "damage_reduction"
display_name = "坚韧体魄"
description = "受到伤害降低10%"
tags = PackedStringArray("universal")
rarity = "rare"
effect_type = "damage_reduction"
effect_params = {"ratio": 0.10}
cost_min = 30
cost_max = 45
max_stack = 3
```

`resources/items/universal_dodge.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "dodge"
display_name = "幻影步法"
description = "15%概率闪避攻击"
tags = PackedStringArray("universal")
rarity = "rare"
effect_type = "dodge"
effect_params = {"chance": 0.15}
cost_min = 35
cost_max = 50
max_stack = 2
```

**Step 3: 移动机动类（universal 标签）**

`resources/items/universal_speedboost.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "speed_boost"
display_name = "加速靴"
description = "移动速度+12%"
tags = PackedStringArray("universal")
rarity = "common"
effect_type = "stat_boost"
effect_params = {"stat": "move_speed_mult", "value": 0.12}
cost_min = 15
cost_max = 25
max_stack = 3
```

`resources/items/universal_magnet.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "coin_magnet"
display_name = "磁力装置"
description = "金币拾取范围+50%"
tags = PackedStringArray("universal")
rarity = "common"
effect_type = "magnet"
effect_params = {"mult": 0.50}
cost_min = 10
cost_max = 20
max_stack = 3
```

`resources/items/universal_slowaura.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "slow_aura"
display_name = "寒霜领域"
description = "周围敌人减速15%"
tags = PackedStringArray("universal")
rarity = "rare"
effect_type = "slow_aura"
effect_params = {"ratio": 0.15, "range": 100.0}
cost_min = 35
cost_max = 50
max_stack = 2
```

`resources/items/universal_autodash.tres`:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "auto_dash"
display_name = "闪电冲锋"
description = "每10秒自动冲刺（冲刺时无敌）"
tags = PackedStringArray("universal")
rarity = "epic"
effect_type = "auto_dash"
effect_params = {"interval": 10.0, "distance": 80.0}
cost_min = 50
cost_max = 70
max_stack = 1
```

**Step 4: 提交**

```bash
git add resources/items/shooter_bulletspeed.tres resources/items/shooter_longrange.tres \
  resources/items/shooter_critshot.tres resources/items/shooter_split.tres \
  resources/items/universal_shield.tres resources/items/universal_waveheal.tres \
  resources/items/universal_armor.tres resources/items/universal_dodge.tres \
  resources/items/universal_speedboost.tres resources/items/universal_magnet.tres \
  resources/items/universal_slowaura.tres resources/items/universal_autodash.tres
git commit -m "feat: 新增 12 个类幸存者商店物品 .tres"
```

---

## Task 6: 简单效果接入 — 弹速/射程/暴击/减伤/闪避/磁铁

**Files:**
- Modify: `scripts/entities/projectiles/bullet_projectile.gd:16-18` — 弹速倍率
- Modify: `scripts/entities/weapons/weapon_manager.gd:26-29` — 射程倍率
- Modify: `scripts/entities/weapons/bullet_weapon.gd:11-14` — 暴击
- Modify: `scripts/entities/player.gd:80-86` — 减伤 + 闪避
- Modify: `scripts/entities/coin.gd:21` — 磁铁范围

**Step 1: 弹速倍率 — bullet_projectile.gd**

在 `_on_setup()` 末尾（`hitbox.area_entered.connect(...)` 之后）：

```gdscript
# 弹速倍率
speed *= GameData.bullet_speed_mult
```

注意：bullet_projectile.gd 的 `speed` 在 `_spawn_bullet()` 中通过 `bullet.speed = weapon_data.bullet_speed` 设置，晚于 `_on_setup()`。所以实际上应该在 `bullet_weapon.gd` 的 `_spawn_bullet()` 中修改：

```gdscript
# bullet_weapon.gd _spawn_bullet() — 在 bullet.speed 赋值后
bullet.speed = weapon_data.bullet_speed * GameData.bullet_speed_mult
```

**Step 2: 射程倍率 — weapon_manager.gd**

修改 `tick()` 中的射程计算（`weapon_manager.gd:26-29`）：

```gdscript
func tick(delta: float) -> void:
	var max_range: float = 0.0
	for weapon in _weapons:
		if weapon.weapon_data and weapon.weapon_data.weapon_range > max_range:
			max_range = weapon.weapon_data.weapon_range
	max_range *= GameData.weapon_range_mult
	var target: Node2D = _find_closest_enemy(max_range)
	for weapon in _weapons:
		weapon.tick(delta, target)
```

**Step 3: 暴击 — bullet_weapon.gd**

在 `fire()` 中，蓄力计算之后、联动计算之前，添加暴击判定：

```gdscript
# 暴击判定
if GameData.crit_chance > 0.0 and randf() < GameData.crit_chance:
	base_damage *= GameData.crit_damage_mult
```

**Step 4: 减伤 + 闪避 — player.gd**

修改 `_on_hurtbox_hit()` （`player.gd:80-86`）：

```gdscript
func _on_hurtbox_hit(damage: float, _knockback: Vector2) -> void:
	if invincible_timer > 0:
		return
	# 闪避判定
	if GameData.dodge_chance > 0.0 and randf() < GameData.dodge_chance:
		return
	# 护盾判定
	if GameData.current_shield > 0:
		GameData.current_shield -= 1
		return
	# 减伤
	var final_damage: float = damage * (1.0 - GameData.damage_reduction)
	health.take_damage_no_sparks(final_damage)
	_flash_white()
	invincible_timer = invincible_duration
	var fx: EffectConfigData = GameConfig.effects
	EventBus.camera_shake_requested.emit(fx.camera_shake_player_hit_intensity, fx.camera_shake_player_hit_duration)
```

同步修改 `take_damage()` 方法（`player.gd:90-97`），应用相同的闪避/护盾/减伤逻辑：

```gdscript
func take_damage(amount: float) -> void:
	if invincible_timer > 0:
		return
	if GameData.dodge_chance > 0.0 and randf() < GameData.dodge_chance:
		return
	if GameData.current_shield > 0:
		GameData.current_shield -= 1
		return
	var final_damage: float = amount * (1.0 - GameData.damage_reduction)
	health.take_damage_no_sparks(final_damage)
	_flash_white()
	invincible_timer = invincible_duration
	var fx: EffectConfigData = GameConfig.effects
	EventBus.camera_shake_requested.emit(fx.camera_shake_player_hit_intensity, fx.camera_shake_player_hit_duration)
```

**Step 5: 磁铁范围 — coin.gd**

修改 `_process()` 中的 `attract_range` 检查（`coin.gd:21`）：

```gdscript
# 原来：
if global_position.distance_to(player.global_position) < attract_range:

# 改为：
if global_position.distance_to(player.global_position) < attract_range * GameData.coin_magnet_mult:
```

**Step 6: 提交**

```bash
git add scripts/entities/weapons/bullet_weapon.gd scripts/entities/weapons/weapon_manager.gd \
  scripts/entities/projectiles/bullet_projectile.gd scripts/entities/player.gd \
  scripts/entities/coin.gd
git commit -m "feat: 接入弹速/射程/暴击/减伤/闪避/磁铁效果"
```

---

## Task 7: 波次效果接入 — 每波回血 + 每波护盾

**Files:**
- Modify: `scripts/systems/item_effect_manager.gd:28-40` — 波次结束回血、波次开始护盾

**Step 1: 在 _on_wave_completed() 中添加玩家回血**

在金矿逻辑之后：

```gdscript
# 波次回血：回复玩家最大HP的百分比
if GameData.wave_heal_ratio > 0.0:
	var players: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.PLAYER)
	if not players.is_empty():
		var player: Node = players[0]
		if player.get("health") != null:
			var heal_amount: float = player.health.max_hp * GameData.wave_heal_ratio
			player.health.heal(heal_amount)
```

**Step 2: 在 _on_wave_started() 中添加护盾重置**

在战争机器逻辑之前：

```gdscript
# 护盾：每波开始重置
if GameData.wave_shield_count > 0:
	GameData.current_shield = GameData.wave_shield_count
```

**Step 3: 提交**

```bash
git add scripts/systems/item_effect_manager.gd
git commit -m "feat: item_effect_manager 接入每波回血和每波护盾"
```

---

## Task 8: 复杂效果接入 — 弹道分裂

**Files:**
- Modify: `scripts/entities/projectiles/bullet_projectile.gd:51-62` — 命中时分裂

**Step 1: 在 _on_hitbox_area_entered() 中添加分裂逻辑**

在吸血逻辑之后、穿甲判定之前：

```gdscript
# 弹道分裂：命中后生成小弹（仅主弹分裂，防止无限递归）
if GameData.split_count > 0 and not get_meta("is_split", false):
	_spawn_split_bullets()
```

添加分裂方法：

```gdscript
func _spawn_split_bullets() -> void:
	var scene_parent: Node = get_parent()
	if not scene_parent:
		return
	var split_damage: float = hitbox.damage * 0.5
	for i in GameData.split_count:
		var angle: float = randf_range(-PI / 2, PI / 2)
		var split_dir: Vector2 = _direction.rotated(angle)
		var split_bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
		split_bullet.speed = speed * 0.8
		split_bullet.lifetime = 1.5
		split_bullet.set_meta("is_split", true)
		scene_parent.add_child(split_bullet)
		split_bullet.setup(split_damage, hitbox.knockback_force * 0.5, global_position, split_dir)
```

**Step 2: 提交**

```bash
git add scripts/entities/projectiles/bullet_projectile.gd
git commit -m "feat: 弹道分裂效果接入"
```

---

## Task 9: 复杂效果接入 — 减速光环

**Files:**
- Modify: `scripts/entities/player.gd` — 在 _process 中周期检测周围敌人并减速

**Step 1: 添加减速光环逻辑**

在 `player.gd` 的 `_process()` 末尾添加：

```gdscript
# 减速光环
if GameData.slow_aura_active:
	_apply_slow_aura()
```

添加方法：

```gdscript
func _apply_slow_aura() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	for enemy in enemies:
		if enemy is Node2D:
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist <= GameData.slow_aura_range:
				if enemy.get("slow_handler") != null:
					enemy.slow_handler.apply_slow("slow_aura", GameData.slow_aura_ratio, 0.5)
```

注意：需要确认 SlowHandler.apply_slow() 的签名。

**Step 2: 验证 SlowHandler API**

读取 `scripts/components/slow_handler.gd`，确认 `apply_slow()` 方法签名和参数。如果签名不同，需要适配。

**Step 3: 提交**

```bash
git add scripts/entities/player.gd
git commit -m "feat: 减速光环效果接入"
```

---

## Task 10: 复杂效果接入 — 自动冲刺

**Files:**
- Modify: `scripts/entities/player.gd` — 添加冲刺计时器和冲刺逻辑

**Step 1: 添加冲刺相关变量**

在 `player.gd` 变量声明区：

```gdscript
var _dash_timer: float = 0.0
var _is_dashing: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_remaining: float = 0.0
var _dash_speed: float = 800.0
```

**Step 2: 在 _process() 中添加冲刺计时**

```gdscript
# 自动冲刺
if GameData.auto_dash_active:
	_update_auto_dash(delta)
```

添加方法：

```gdscript
func _update_auto_dash(delta: float) -> void:
	if _is_dashing:
		return
	_dash_timer += delta
	if _dash_timer >= GameData.auto_dash_interval:
		_dash_timer = 0.0
		_start_dash()

func _start_dash() -> void:
	# 向当前移动方向冲刺，无方向输入则随机方向
	var input_vec := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input_vec.length() > 0:
		_dash_direction = input_vec.normalized()
	else:
		_dash_direction = Vector2.RIGHT.rotated(randf() * TAU)
	_is_dashing = true
	_dash_remaining = GameData.auto_dash_distance
	invincible_timer = GameData.auto_dash_distance / _dash_speed + 0.1

func _end_dash() -> void:
	_is_dashing = false
```

**Step 3: 修改 _physics_process() 冲刺移动**

在 `_physics_process()` 开头插入冲刺检查：

```gdscript
func _physics_process(delta: float) -> void:
	# 冲刺移动覆盖
	if _is_dashing:
		velocity = _dash_direction * _dash_speed
		move_and_slide()
		_dash_remaining -= _dash_speed * delta
		if _dash_remaining <= 0:
			_end_dash()
		_sprite_animator.update_animation(velocity)
		return

	# 原来的移动逻辑...
```

**Step 4: 提交**

```bash
git add scripts/entities/player.gd
git commit -m "feat: 自动冲刺效果接入"
```

---

## Task 11: 运行测试 + 修复

**Step 1: 运行 headless 测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

**Step 2: 修复任何因改动导致的测试失败**

常见可能的失败：
- shop_manager 相关测试（如果测试依赖特定物品数量）
- player 相关测试（如果测试模拟受伤流程）
- 新增 Enum 常量后可能需要更新 `global_script_class_cache.cfg`（本次无新 class_name，应该不需要）

**Step 3: 提交修复**

```bash
git add -A
git commit -m "fix: 修复测试兼容问题"
```

---

## Task 12: 集成验证 + CLAUDE.md 更新

**Step 1: 运行游戏进行完整流程验证**

验证清单：
- [ ] 选择角色 → 选择地图 → 直接进战斗（无 placement 阶段）
- [ ] 战斗结束进商店，商店无塔相关物品
- [ ] 商店出现新物品（疾风弹、鹰眼瞄准、致命精准等）
- [ ] 购买新物品后效果生效（弹速更快、暴击触发、受伤减少等）
- [ ] 确认后直接进下一波战斗
- [ ] 全部波次通过后正常结算

**Step 2: 更新 CLAUDE.md**

在"游戏流程"部分更新：
- 移除 placement 步骤
- 注明塔防阶段暂时跳过

**Step 3: 提交**

```bash
git add CLAUDE.md
git commit -m "docs: 更新 CLAUDE.md 反映类幸存者优先流程变更"
```
