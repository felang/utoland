# 游戏精简实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将游戏从 10 武器 + 15 塔精简为 3 武器 + 3 塔，移除羁绊和稀有度系统。

**Architecture:** 按原子操作分组——每个 Task 完成后项目不会出现解析错误。先创建新武器（避免引用不存在的类），再删除旧文件并同步更新所有引用。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

**重要原则:** 删除带 `class_name` 的脚本和更新引用这些类的代码必须在同一个 Task 中完成，否则项目会因为类型引用不存在而无法解析。

---

## Chunk 1: 创建新武器（先建后拆）

### Task 1: 创建弓武器 (Bow)

**Files:**
- Create: `scripts/entities/weapons/bow_weapon.gd`
- Create: `resources/weapons/bow.tres`

- [ ] **Step 1: 创建 BowWeapon 脚本**

写入 `scripts/entities/weapons/bow_weapon.gd`：

```gdscript
# BowWeapon — 单发射击的基础远程武器
class_name BowWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		push_error("BowWeapon: owner has no parent scene")
		return
	var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	bullet.speed = weapon_data.bullet_speed
	scene_parent.add_child(bullet)
	bullet.setup(base_damage, weapon_data.knockback_force, owner_node.global_position, direction)
	AudioManager.play("shoot")
```

- [ ] **Step 2: 创建 bow.tres 资源**

创建 `resources/weapons/bow.tres`：
- id = "bow", display_name = "弓", weapon_type = "bow", projectile_type = "bullet"
- damage_per_level: [8, 18, 34]
- fire_rate_per_level: [0.12, 0.10, 0.08]
- weapon_range_per_level: [150, 170, 200]
- sell_price_per_level: [3, 7, 21]
- bullet_speed: 300, knockback_force: 40

- [ ] **Step 3: Commit**

```bash
git add scripts/entities/weapons/bow_weapon.gd resources/weapons/bow.tres && git commit -m "feat: 新增弓武器 (Bow)"
```

---

### Task 2: 创建剑武器 (Sword)

**Files:**
- Create: `scripts/entities/weapons/sword_weapon.gd`
- Create: `resources/weapons/sword.tres`

- [ ] **Step 1: 创建 SwordWeapon 脚本**

写入 `scripts/entities/weapons/sword_weapon.gd`：

```gdscript
# SwordWeapon — 前方扇形挥砍近战武器
class_name SwordWeapon
extends Weapon

const SLASH_ANGLE: float = 90.0  # 扇形角度（度）

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var attack_range: float = get_weapon_range()
	var half_angle: float = deg_to_rad(SLASH_ANGLE / 2.0)

	# 查找扇形范围内的敌人
	if not owner_node.is_inside_tree():
		return
	var enemies: Array[Node] = owner_node.get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	for enemy in enemies:
		if enemy is Node2D:
			var to_enemy: Vector2 = enemy.global_position - owner_node.global_position
			var dist: float = to_enemy.length()
			if dist > attack_range:
				continue
			var angle: float = direction.angle_to(to_enemy.normalized())
			if absf(angle) <= half_angle:
				if enemy.has_node("Hurtbox"):
					var hurtbox: Hurtbox = enemy.get_node("Hurtbox")
					hurtbox.take_hit(base_damage, direction * weapon_data.knockback_force)
				EffectsManager.spawn_hit_sparks(enemy.global_position)
	AudioManager.play("shoot")
```

- [ ] **Step 2: 创建 sword.tres 资源**

创建 `resources/weapons/sword.tres`：
- id = "sword", display_name = "剑", weapon_type = "sword", projectile_type = ""
- damage_per_level: [20, 38, 65]
- fire_rate_per_level: [0.4, 0.32, 0.24]
- weapon_range_per_level: [60, 72, 90]
- sell_price_per_level: [3, 7, 21]
- knockback_force: 80

- [ ] **Step 3: Commit**

```bash
git add scripts/entities/weapons/sword_weapon.gd resources/weapons/sword.tres && git commit -m "feat: 新增剑武器 (Sword) — 前方扇形挥砍"
```

---

## Chunk 2: 原子化移除羁绊系统

**关键：** 删除羁绊文件（`SynergyManager`、`SynergyEffectProcessor`、`PairSynergyManager`、`SynergyData`）的同时，必须同步清理所有引用它们的代码，否则 Godot 会因类型不存在而报解析错误。

### Task 3: 移除羁绊系统（删除文件 + 清理所有引用）

**Files:**
- Delete: `scripts/systems/synergy_manager.gd`
- Delete: `scripts/systems/synergy_effect_processor.gd`
- Delete: `scripts/systems/pair_synergy_manager.gd`
- Delete: `scripts/resources/synergy_data.gd`
- Delete: `resources/synergies/` (全目录)
- Delete: `tests/unit/test_synergy_manager.gd`
- Delete: `tests/unit/test_synergy_effect_processor.gd`
- Delete: `tests/unit/test_pair_synergy.gd`
- Modify: `scripts/core/game_data.gd` — 移除羁绊字段和 recalculate 调用
- Modify: `scripts/core/game_config.gd` — 移除 synergies 加载
- Modify: `scripts/core/event_bus.gd` — 移除羁绊信号
- Modify: `scripts/entities/weapons/weapon.gd` — 移除 synergy/frenzy 逻辑
- Modify: `scripts/entities/towers/tower.gd` — 移除 _apply_synergy_bonus()
- Modify: `scripts/entities/enemy.gd` — 移除 synergy processor 引用
- Modify: `scripts/components/slow_handler.gd` — 移除 chain freeze 逻辑
- Modify: `scripts/entities/player.gd` — 移除 pair synergy 引用
- Modify: `scripts/ui/main.gd` — 移除 SynergyEffectProcessor 创建

- [ ] **Step 1: 删除羁绊系统文件和测试**

```bash
rm scripts/systems/synergy_manager.gd
rm scripts/systems/synergy_effect_processor.gd
rm scripts/systems/pair_synergy_manager.gd
rm scripts/resources/synergy_data.gd
rm -rf resources/synergies/
rm tests/unit/test_synergy_manager.gd
rm tests/unit/test_synergy_effect_processor.gd
rm tests/unit/test_pair_synergy.gd
```

- [ ] **Step 2: 清理 GameData（`scripts/core/game_data.gd`）**

删除以下字段：
- `synergy_tag_counts: Dictionary = {}`（第 42 行）
- `synergy_active_tiers: Dictionary = {}`（第 43 行）
- `active_pair_synergies: Array[String] = []`（第 44 行）
- `_synergy_manager: SynergyManager`（第 57 行）
- `_pair_synergy_manager: PairSynergyManager`（第 59 行）

删除 `_ready()` 中（第 105-106 行）：
```gdscript
_synergy_manager = SynergyManager.new()
_pair_synergy_manager = PairSynergyManager.new()
```

删除 `reset()` 中（第 148-152 行）：
```gdscript
synergy_tag_counts = {}
synergy_active_tiers = {}
active_pair_synergies = []
_synergy_manager = SynergyManager.new()
_pair_synergy_manager = PairSynergyManager.new()
```

删除所有方法中的 recalculate 调用（出现在 `deploy_weapon`、`undeploy_weapon`、`deploy_tower`、`undeploy_tower`、`_apply_sell`、`_check_merge` 中，共 12 行）：
```gdscript
_synergy_manager.recalculate()
_pair_synergy_manager.recalculate()
```

更新注释：将 `## 商店栏位 [{id, type, rarity, cost}] x4` 改为 `## 商店栏位 [{id, type, cost}] x4`。

- [ ] **Step 3: 清理 GameConfig（`scripts/core/game_config.gd`）**

删除 `synergies` 变量声明（第 135 行）。
删除 `_ready()` 中的 `_load_synergies()` 调用（第 149 行）。
删除 `_load_synergies()` 方法（第 213-226 行）。

- [ ] **Step 4: 清理 EventBus（`scripts/core/event_bus.gd`）**

删除第 40-46 行的 4 个羁绊信号：
```gdscript
signal synergy_changed(tag: String, old_tier: int, new_tier: int)
signal synergy_effect_triggered(tag: String, effect_id: String)
signal pair_synergy_activated(synergy_id: String)
signal pair_synergy_deactivated(synergy_id: String)
```

- [ ] **Step 5: 清理 weapon.gd（`scripts/entities/weapons/weapon.gd`）**

`get_damage()` 方法删除羁绊加成（第 23-26 行），改为：
```gdscript
func get_damage() -> float:
	var base: float = weapon_data.damage_per_level[get_current_level() - 1]
	if GameData.new_passive_id == "swift_combo" and owner_node and owner_node.has_method("get_combo_damage_mult"):
		base *= owner_node.get_combo_damage_mult()
	if GameData.new_passive_id == "blood_rage" and owner_node and owner_node.has_method("get_blood_rage_mult"):
		base *= owner_node.get_blood_rage_mult()
	return base
```

`tick()` 删除狂热检查（第 46-48 行），改为：
```gdscript
func tick(delta: float, target: Node2D) -> void:
	_cooldown -= delta
	if _cooldown <= 0.0 and target:
		fire(target)
		var speed_mult: float = GameData.player_stats.get(Enums.Stat.ATTACK_SPEED_MULT, 1.0)
		_cooldown = get_fire_rate() / speed_mult
```

删除 `_is_frenzy_active()` 方法（第 55-64 行）。

- [ ] **Step 6: 清理 tower.gd（`scripts/entities/towers/tower.gd`）**

将 `tower_type` 默认值从 `Enums.TowerId.STUMP` 改为 `""`。
`_ready()` 中删除 `_apply_synergy_bonus()` 调用（第 19 行）。
删除整个 `_apply_synergy_bonus()` 方法（第 28-47 行）。

- [ ] **Step 7: 清理 enemy.gd（`scripts/entities/enemy.gd`）**

删除以下方法（第 186-219 行）：
- `_try_chain_freeze_from_root()` — 整个方法
- `_on_died_with_overkill()` — 整个方法
- `_apply_vulnerable_mult()` — 整个方法
- `_get_synergy_processor()` — 整个方法

更新调用点：
- 找到调用 `_try_chain_freeze_from_root()` 的位置（第 177 行），删除该调用
- 找到 `health.died_with_overkill.connect(_on_died_with_overkill)` 的连接（第 49 行），删除
- 找到 `amount = _apply_vulnerable_mult(amount)` 的调用（第 97 行），删除该行

- [ ] **Step 8: 清理 slow_handler.gd（`scripts/components/slow_handler.gd`）**

删除 `_try_chain_freeze()` 方法（第 43-56 行）。
删除 `_on_timed_slow_expired()` 中对 `_try_chain_freeze()` 的调用（第 38-41 行），简化为：
```gdscript
func _on_timed_slow_expired(source_id: String) -> void:
	_timed_slow_timers.erase(source_id)
	remove_slow(source_id)
```

- [ ] **Step 9: 清理 player.gd（`scripts/entities/player.gd`）**

删除 bloodthirst pair synergy 代码（第 48-50 行）：
```gdscript
if GameData.active_pair_synergies.has("bloodthirst"):
	EventBus.enemy_killed.connect(_on_bloodthirst_kill)
```
删除 `_on_bloodthirst_kill()` 方法（第 195-196 行）。

更新 `_count_fortify_units()` 方法（第 187-192 行），改为计数所有塔：
```gdscript
func _count_fortify_units() -> int:
	return get_tree().get_nodes_in_group(Enums.Group.TOWERS).size()
```

- [ ] **Step 10: 清理 main.gd（`scripts/ui/main.gd`）**

删除：
- `var _synergy_processor: SynergyEffectProcessor = null`（第 7 行）
- 创建 processor 的代码（第 27-30 行）
- `_synergy_processor.deactivate()`（第 51 行）
- `_synergy_processor.activate()`（第 58 行）

- [ ] **Step 11: Commit**

```bash
git add -A && git commit -m "refactor: 完整移除羁绊系统（删除文件 + 清理所有引用）"
```

---

## Chunk 3: 删除废弃武器/塔/投射物，更新枚举和核心系统

### Task 4: 删除废弃文件 + 更新 Enums + SceneFactory + WeaponManager

**Files:**
- Delete: 8 个武器脚本、9 个武器资源、5 个投射物（脚本+场景）、11 个塔脚本、12 个塔资源、12 个塔场景
- Delete: `tests/unit/test_weapon_balance.gd`, `test_laser_projectile.gd`, `test_laser_beam.gd`
- Modify: `scripts/core/enums.gd`
- Modify: `scripts/core/scene_factory.gd`
- Modify: `scripts/entities/weapons/weapon_manager.gd`

- [ ] **Step 1: 删除武器脚本**

```bash
rm scripts/entities/weapons/bullet_weapon.gd
rm scripts/entities/weapons/blade_weapon.gd
rm scripts/entities/weapons/shotgun_weapon.gd
rm scripts/entities/weapons/laser_weapon.gd
rm scripts/entities/weapons/ice_gun_weapon.gd
rm scripts/entities/weapons/rocket_weapon.gd
rm scripts/entities/weapons/lightning_weapon.gd
rm scripts/entities/weapons/flamethrower_weapon.gd
```

- [ ] **Step 2: 删除武器资源和废弃测试**

```bash
rm resources/weapons/rifle.tres resources/weapons/blade.tres resources/weapons/shotgun.tres
rm resources/weapons/laser.tres resources/weapons/minigun.tres resources/weapons/ice_gun.tres
rm resources/weapons/rocket.tres resources/weapons/lightning.tres resources/weapons/flamethrower.tres
rm tests/unit/test_weapon_balance.gd tests/unit/test_laser_projectile.gd tests/unit/test_laser_beam.gd
```

- [ ] **Step 3: 删除投射物**

```bash
rm scripts/entities/projectiles/laser_projectile.gd scenes/entities/projectiles/laser_projectile.tscn
rm scripts/entities/projectiles/rocket_projectile.gd scenes/entities/projectiles/rocket_projectile.tscn
rm scripts/entities/projectiles/chain_projectile.gd scenes/entities/projectiles/chain_projectile.tscn
rm scripts/entities/projectiles/flame_projectile.gd scenes/entities/projectiles/flame_projectile.tscn
rm scripts/entities/projectiles/melee_projectile.gd scenes/entities/projectiles/melee_projectile.tscn
```

- [ ] **Step 4: 删除塔脚本、资源、场景**

```bash
# 脚本
rm scripts/entities/towers/tower_sniper.gd scripts/entities/towers/tower_burst.gd
rm scripts/entities/towers/tower_aoe.gd scripts/entities/towers/tower_trap.gd
rm scripts/entities/towers/tower_knockback.gd scripts/entities/towers/tower_thorn.gd
rm scripts/entities/towers/tower_bomb.gd scripts/entities/towers/tower_grab.gd
rm scripts/entities/towers/tower_aura.gd scripts/entities/towers/tower_buff.gd
rm scripts/entities/towers/tower_heal.gd
# 资源
rm resources/towers/stump.tres resources/towers/cactus.tres resources/towers/rose.tres
rm resources/towers/mushroom.tres resources/towers/vine.tres resources/towers/dandelion.tres
rm resources/towers/pitcher.tres resources/towers/thorn.tres resources/towers/oak.tres
rm resources/towers/mint.tres resources/towers/heal_flower.tres resources/towers/bamboo.tres
# 场景
rm scenes/entities/towers/tower_stump.tscn scenes/entities/towers/tower_cactus.tscn
rm scenes/entities/towers/tower_rose.tscn scenes/entities/towers/tower_mushroom.tscn
rm scenes/entities/towers/tower_vine.tscn scenes/entities/towers/tower_dandelion.tscn
rm scenes/entities/towers/tower_pitcher.tscn scenes/entities/towers/tower_thorn.tscn
rm scenes/entities/towers/tower_oak.tscn scenes/entities/towers/tower_mint.tscn
rm scenes/entities/towers/tower_heal_flower.tscn scenes/entities/towers/tower_bamboo.tscn
```

- [ ] **Step 5: 更新 Enums（`scripts/core/enums.gd`）**

精简 WeaponId、TowerId、ProjectileId，删除 Tag、WeaponRarity、TowerRarity：

```gdscript
# WeaponId — 只保留 3 种
class WeaponId:
	const BOW = "bow"
	const BOOMERANG = "boomerang"
	const SWORD = "sword"

# TowerId — 只保留 3 种
class TowerId:
	const PEA_SHOOTER = "pea_shooter"
	const ICE_FLOWER = "ice_flower"
	const SUNFLOWER = "sunflower"

# ProjectileId — 只保留 2 种
class ProjectileId:
	const BULLET = "bullet"
	const BOOMERANG = "boomerang"
```

删除 `Tag` 类（第 92-98 行）、`WeaponRarity` 类（第 101-104 行）、`TowerRarity` 类（第 108-111 行）。
保持 Group、Scene、Character、Enemy、Map、Stat、BoomerangState、Anim 不变。

- [ ] **Step 6: 更新 SceneFactory（`scripts/core/scene_factory.gd`）**

`_tower_scenes` 只保留 3 种塔：
```gdscript
var _tower_scenes: Dictionary = {
	Enums.TowerId.PEA_SHOOTER: preload("res://scenes/entities/towers/tower_pea_shooter.tscn"),
	Enums.TowerId.ICE_FLOWER: preload("res://scenes/entities/towers/tower_ice_flower.tscn"),
	Enums.TowerId.SUNFLOWER: preload("res://scenes/entities/towers/tower_sunflower.tscn"),
}
```

删除废弃投射物预加载和工厂方法（`_laser_projectile_scene` + `create_laser_projectile()`、`_rocket_projectile_scene` + `create_rocket_projectile()`、`_chain_projectile_scene` + `create_chain_projectile()`、`_melee_projectile_scene` + `create_melee_projectile()`、`_flame_projectile_scene` + `create_flame_projectile()`）。

保留 `_bullet_projectile_scene` + `create_bullet_projectile()` 和 `_boomerang_projectile_scene` + `create_boomerang_projectile()`。

- [ ] **Step 7: 更新 WeaponManager（`scripts/entities/weapons/weapon_manager.gd`）**

`_create_weapon()` 方法改为：
```gdscript
func _create_weapon(weapon_type: String) -> Weapon:
	match weapon_type:
		"bow":       return BowWeapon.new()
		"boomerang": return BoomerangWeapon.new()
		"sword":     return SwordWeapon.new()
	push_error("WeaponManager: 未知 weapon_type: " + weapon_type)
	return null
```

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "refactor: 删除废弃武器/塔/投射物，更新 Enums/SceneFactory/WeaponManager"
```

---

## Chunk 4: 更新 Resource 类、商店系统、UI、数据文件

### Task 5: 更新 Resource 类（移除 tag/rarity 和废弃 export 组）

**Files:**
- Modify: `scripts/resources/weapon_data.gd`
- Modify: `scripts/resources/tower_data.gd`
- Modify: `scripts/resources/character_data.gd`

- [ ] **Step 1: 精简 WeaponData（`scripts/resources/weapon_data.gd`）**

- 删除 `@export var rarity: int = 0`（第 9 行）
- 删除 `@export var tag: String = ""`（第 12 行）
- 删除废弃 export 组：激光专有（第 34-37 行）、火箭专有（第 39-40 行）、火焰专有（第 42-43 行）、闪电专有（第 45-48 行）、冰冻专有（第 50-52 行）
- 保留：基础信息（id, display_name, description, icon_path, weapon_type, projectile_type）、等级系统、通用属性、子弹专有、回旋镖专有

- [ ] **Step 2: 精简 TowerData（`scripts/resources/tower_data.gd`）**

- 删除 `@export var rarity: int = 0`（第 9 行）
- 删除 `@export var tag: String = ""`（第 10 行）
- 删除废弃 export 组：玫瑰（第 21-23 行）、藤蔓（第 25-27 行）、蒲公英（第 29-31 行）、猪笼草（第 33-35 行）、荆棘（第 37-38 行）、橡树（第 40-41 行）、薄荷（第 47-49 行）、治愈花（第 51-53 行）、爆竹竹（第 55-58 行）
- 保留：基础信息、等级系统（含 slow_ratio_per_level）、向日葵专有

- [ ] **Step 3: 精简 CharacterData（`scripts/resources/character_data.gd`）**

- 删除 `@export var tag: String = ""` 字段

- [ ] **Step 4: Commit**

```bash
git add scripts/resources/ && git commit -m "refactor: Resource 类移除 tag/rarity 和废弃 export 组"
```

---

### Task 6: 更新商店系统（移除稀有度）

**Files:**
- Modify: `scripts/resources/shop_config.gd`
- Modify: `scripts/systems/shop_manager.gd`
- Modify: `resources/shop/shop_config.tres`

- [ ] **Step 1: 更新 ShopConfig（`scripts/resources/shop_config.gd`）**

改为：
```gdscript
class_name ShopConfig
extends Resource

@export var slot_count: int = 4
@export var refresh_cost: int = 2
@export var bag_capacity: int = 10
@export var item_cost: int = 3
@export var level_up_costs: PackedInt32Array = PackedInt32Array([4, 8, 12, 20, 28, 36])
@export var population_per_level: PackedInt32Array = PackedInt32Array([2, 3, 4, 5, 6, 7, 8])
```

- [ ] **Step 2: 更新 ShopManager（`scripts/systems/shop_manager.gd`）**

全文替换为：
```gdscript
class_name ShopManager
extends RefCounted

## 商店管理器 — 负责商店刷新、物品购买
## 由商店场景实例化（非 Autoload）。
## 直接读写 GameData 状态，通过 EventBus 发布事件。

func refresh_shop(is_first: bool = false) -> void:
	var config: ShopConfig = GameConfig.shop_config
	GameData.shop_slots = []
	var guaranteed_ids: Array[String] = []
	if is_first:
		if GameData._recommended_weapon != "" and _has_item(GameData._recommended_weapon):
			guaranteed_ids.append(GameData._recommended_weapon)
		if GameData._recommended_tower != "" and _has_item(GameData._recommended_tower):
			guaranteed_ids.append(GameData._recommended_tower)
	for i in config.slot_count:
		if i < guaranteed_ids.size():
			var item_id: String = guaranteed_ids[i]
			GameData.shop_slots.append({
				id = item_id,
				type = _get_item_type(item_id),
				cost = config.item_cost,
			})
		else:
			GameData.shop_slots.append(_generate_random_slot())

func manual_refresh() -> bool:
	var config: ShopConfig = GameConfig.shop_config
	if GameData.coins < config.refresh_cost:
		return false
	GameData.coins -= config.refresh_cost
	EventBus.coins_changed.emit(-config.refresh_cost, GameData.coins)
	refresh_shop()
	return true

func buy_item(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= GameData.shop_slots.size():
		return false
	var slot: Dictionary = GameData.shop_slots[slot_index]
	if slot.is_empty():
		return false
	if GameData.coins < slot.cost:
		return false
	if not GameData.can_buy():
		return false
	GameData.coins -= slot.cost
	var item := {id = slot.id, type = slot.type, level = 1}
	GameData.bag.append(item)
	GameData.shop_slots[slot_index] = {}
	EventBus.item_purchased.emit(item)
	EventBus.coins_changed.emit(-slot.cost, GameData.coins)
	GameData._check_merge(slot.id, 1)
	return true

func _generate_random_slot() -> Dictionary:
	var config: ShopConfig = GameConfig.shop_config
	var pool: Array[String] = _get_all_items()
	if pool.is_empty():
		return {}
	var item_id: String = pool[randi() % pool.size()]
	return {
		id = item_id,
		type = _get_item_type(item_id),
		cost = config.item_cost,
	}

func _get_all_items() -> Array[String]:
	var pool: Array[String] = []
	for id: String in GameConfig.weapons:
		pool.append(id)
	for id: String in GameConfig.towers:
		pool.append(id)
	return pool

func _has_item(item_id: String) -> bool:
	return GameConfig.weapons.has(item_id) or GameConfig.towers.has(item_id)

func _get_item_type(item_id: String) -> String:
	if GameConfig.weapons.has(item_id):
		return "weapon"
	return "tower"
```

- [ ] **Step 3: 更新 shop_config.tres**

手动编辑 `resources/shop/shop_config.tres`，移除 `cost_by_rarity` 和 `rarity_weights` 字段，添加 `item_cost = 3`。

- [ ] **Step 4: Commit**

```bash
git add scripts/resources/shop_config.gd scripts/systems/shop_manager.gd resources/shop/shop_config.tres && git commit -m "refactor: 商店系统移除稀有度，统一物品价格"
```

---

### Task 7: 更新 GameConfig SPRITES + UI 系统

**Files:**
- Modify: `scripts/core/game_config.gd`
- Modify: `scripts/ui/upgrade_card_builder.gd`
- Modify: `scripts/core/ui_constants.gd`

- [ ] **Step 1: 精简 GameConfig SPRITES["towers"]（`scripts/core/game_config.gd`）**

只保留 3 个塔的 region 定义：
```gdscript
"towers": {
	"tileset": "res://assets/towers/tileset_towers.png",
	"pea_shooter": {"region": Rect2(32, 0, 16, 16)},
	"ice_flower": {"region": Rect2(320, 0, 16, 16)},
	"sunflower": {"region": Rect2(144, 0, 16, 16)},
},
```

- [ ] **Step 2: 更新 UpgradeCardBuilder（`scripts/ui/upgrade_card_builder.gd`）**

删除 `RARITY_COLORS` 字典（第 7-11 行）。
将 `create_card()` 中的 `border_color` 逻辑简化为：
```gdscript
static func create_card(opt: Dictionary, on_selected: Callable) -> PanelContainer:
	var is_weapon: bool = opt["type"] == "weapon"
	var border_color: Color = Color("#4fc3f7") if is_weapon else Color("#4caf50")
	var bg_color: Color = Color("#1a1a3a") if is_weapon else Color("#1a2a1a")
```

不再引用 `wd.rarity` 或 `td.rarity`。

- [ ] **Step 3: 清理 UIConstants（`scripts/core/ui_constants.gd`）**

删除稀有度颜色常量（第 17-20 行）：
```gdscript
const COLOR_RARITY_COMMON := Color("#9e9e9e")
const COLOR_RARITY_RARE := Color("#4fc3f7")
const COLOR_RARITY_EPIC := Color("#ab47bc")
```

删除 `get_rarity_color()` 方法（第 49-56 行）。

- [ ] **Step 4: Commit**

```bash
git add scripts/core/game_config.gd scripts/ui/upgrade_card_builder.gd scripts/core/ui_constants.gd && git commit -m "refactor: 精简 SPRITES 字典，UI 移除稀有度颜色"
```

---

### Task 8: 更新数据文件（角色推荐 + 资源 tag/rarity）

**Files:**
- Modify: `resources/characters/dora.tres` — recommended_weapon → "bow", recommended_tower 保持 "pea_shooter"
- Modify: `resources/characters/gorg.tres` — recommended_weapon → "sword", recommended_tower → "pea_shooter"
- Modify: `resources/characters/kaze.tres` — recommended_weapon → "bow", recommended_tower 保持 "ice_flower"
- Modify: `resources/characters/merlin.tres` — recommended_weapon → "boomerang", recommended_tower → "sunflower"
- Modify: `resources/characters/nemo.tres` — recommended_weapon → "boomerang", recommended_tower 保持 "sunflower"
- Modify: `resources/weapons/boomerang.tres` — 删除 tag 和 rarity 字段
- Modify: `resources/towers/pea_shooter.tres`, `ice_flower.tres`, `sunflower.tres` — 删除 tag 和 rarity 字段

- [ ] **Step 1: 更新角色 .tres 文件**

编辑 5 个角色 `.tres` 文件：
- 修改 `recommended_weapon` 和 `recommended_tower` 为保留的武器/塔
- 删除 `tag` 字段行

- [ ] **Step 2: 更新 boomerang.tres**

删除 `tag` 和 `rarity` 字段行。

- [ ] **Step 3: 更新保留的塔 .tres 文件**

从 `pea_shooter.tres`、`ice_flower.tres`、`sunflower.tres` 中删除 `tag` 和 `rarity` 字段行。

- [ ] **Step 4: Commit**

```bash
git add resources/ && git commit -m "refactor: 更新角色推荐武器/塔，移除资源中的 tag/rarity"
```

---

## Chunk 5: 更新测试和最终验证

### Task 9: 更新测试文件

**Files:**
- Modify: `tests/unit/test_weapon_config.gd` — 武器数量 10→3，删除废弃武器测试
- Modify: `tests/unit/test_resource_loading.gd` — 武器数量 10→3，塔数量 15→3
- Modify: `tests/unit/test_scene_factory.gd` — 删除 12 种塔和废弃投射物测试
- Modify: `tests/unit/test_merge_system.gd` — rifle→bow, laser→sword
- Modify: `tests/unit/test_game_data_economy.gd` — rifle→bow, laser→sword, 删除 stump/rarity/synergy 引用
- Modify: `tests/unit/test_shop_manager.gd` — recommended_weapon rifle→bow, 移除 rarity
- Modify: `tests/unit/test_character_balance.gd` — 更新 recommended_weapon/tower 断言
- Modify: `tests/unit/test_tower_balance.gd` — 删除 bamboo/dandelion 测试
- Modify: `tests/unit/test_tower_buff.gd` — 更新 before_each（移除 synergy_active_tiers/synergy_tag_counts 引用）
- Modify: `tests/unit/test_weapon_level.gd` — rifle→bow
- Modify: `tests/unit/test_weapon_manager.gd` — 更新武器类型引用
- Modify: `tests/unit/test_tower_level.gd` — stump→pea_shooter
- Modify: `tests/unit/test_tower_data.gd` — 移除 rarity 引用
- Modify: `tests/unit/test_weapon_data.gd` — 移除 rarity 引用
- Modify: `tests/unit/test_shop_config.gd` — 移除 rarity_weights/cost_by_rarity 测试
- Modify: `tests/unit/test_ui_constants.gd` — 移除 rarity 颜色测试
- Modify: `tests/unit/test_upgrade_card_builder.gd` — 移除 RARITY_COLORS 引用

- [ ] **Step 1: 更新武器相关测试**

- `test_weapon_config.gd`：武器数量断言 10→3，删除废弃武器测试方法，添加 bow/sword 测试
- `test_weapon_level.gd`：替换 "rifle"→"bow"
- `test_weapon_manager.gd`：更新为 bow/boomerang/sword
- `test_weapon_data.gd`：删除 rarity 相关断言

- [ ] **Step 2: 更新塔相关测试**

- `test_tower_balance.gd`：删除 bamboo/dandelion 测试
- `test_tower_level.gd`：替换 "stump"→"pea_shooter"
- `test_tower_buff.gd`：更新 `before_each()` 移除 synergy_active_tiers/synergy_tag_counts 引用
- `test_tower_data.gd`：删除 rarity 相关断言

- [ ] **Step 3: 更新经济/商店测试**

- `test_merge_system.gd`：rifle→bow, laser→sword
- `test_game_data_economy.gd`：rifle→bow, laser→sword, 删除 stump 引用, 删除 synergy recalculate 测试, 更新 shop_slots（无 rarity）
- `test_shop_manager.gd`：recommended_weapon rifle→bow, 移除 rarity 断言
- `test_shop_config.gd`：移除 rarity_weights/cost_by_rarity 测试

- [ ] **Step 4: 更新其他测试**

- `test_resource_loading.gd`：武器 10→3, 塔 15→3, 删除废弃单位加载测试
- `test_scene_factory.gd`：删除 12 种废弃塔和废弃投射物创建测试
- `test_character_balance.gd`：更新 recommended_weapon/tower 断言
- `test_ui_constants.gd`：移除 rarity 颜色测试
- `test_upgrade_card_builder.gd`：移除 RARITY_COLORS 引用

- [ ] **Step 5: Commit**

```bash
git add tests/ && git commit -m "test: 更新测试用例适配精简后的武器/塔/商店系统"
```

---

### Task 10: 更新 global_script_class_cache.cfg

**Files:**
- Modify: `.godot/global_script_class_cache.cfg`

- [ ] **Step 1: 清理 class cache**

从 `.godot/global_script_class_cache.cfg` 中删除所有已删除脚本的 class_name 条目：
- SynergyManager, SynergyEffectProcessor, PairSynergyManager, SynergyData
- BulletWeapon, BladeWeapon, ShotgunWeapon, LaserWeapon, IceGunWeapon, RocketWeapon, LightningWeapon, FlamethrowerWeapon
- LaserProjectile, RocketProjectile, ChainProjectile, FlameProjectile, MeleeProjectile
- TowerSniper, TowerBurst, TowerAoe, TowerTrap, TowerKnockback, TowerThorn, TowerBomb, TowerGrab, TowerAura, TowerBuff, TowerHeal

添加新增脚本的条目：BowWeapon, SwordWeapon

- [ ] **Step 2: Commit**

```bash
git add .godot/global_script_class_cache.cfg && git commit -m "chore: 更新 global_script_class_cache.cfg"
```

---

### Task 11: 运行测试验证

- [ ] **Step 1: 运行全部测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

预期：所有测试通过，无解析错误。

- [ ] **Step 2: 修复任何失败的测试**

逐个修复失败测试，每次修复后重新运行验证。

- [ ] **Step 3: 最终 Commit**

```bash
git add -A && git commit -m "test: 修复精简后的测试问题"
```
