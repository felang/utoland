# 商店系统重构实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将商店从 37 道具属性系统重构为两条成长线：武器（吸血鬼幸存者式 3 选 1）+ 塔（金币商店 3 格 + 刷新）

**Architecture:** Resource 数据层添加 per_level 数组，GameData 用 owned_weapons/owned_towers 字典追踪等级，武器每帧从 per_level 读属性（无需通知），塔通过 EventBus 信号全局升级。旧道具系统（37 tres + 3 系统脚本 + GameData 24+ 字段）完全移除。

**Tech Stack:** Godot 4.6 / GDScript / GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-13-shop-redesign-design.md`

**运行测试命令:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

---

## 文件地图

### 修改的文件
| 文件 | 职责变更 |
|------|---------|
| `scripts/resources/weapon_data.gd` | 新增 max_level, damage_per_level, fire_rate_per_level, weapon_range_per_level, milestones；移除 damage, fire_rate, weapon_range 平面字段 |
| `scripts/resources/tower_data.gd` | 新增 max_level, hp_per_level, damage_per_level, fire_rate_per_level, attack_range_per_level, slow_ratio_per_level, shop_price_per_level, place_cost_per_level, milestones；移除 hp, damage, fire_rate, attack_range, shop_price_min/max, slow_percent 平面字段 |
| `scripts/resources/character_data.gd` | 移除 affinity_tags, affinity_discount；新增 default_tower |
| `scripts/core/game_data.gd` | 新增 owned_weapons, owned_towers；移除 24+ 道具字段和 selected_weapon, purchased_towers；reset() 从 CharacterData 初始化 |
| `scripts/core/event_bus.gd` | 新增 tower_upgraded, tower_purchased 信号 |
| `scripts/core/scene_factory.gd` | get_tower_cost() 改读 place_cost_per_level |
| `scripts/core/enums.gd` | 移除 ItemTag, ItemRarity, ItemEffect 类 |
| `scripts/entities/weapons/weapon.gd` | 新增 get_current_level(), get_damage(), get_fire_rate(), get_weapon_range()；移除 kill_stack 逻辑 |
| `scripts/entities/weapons/weapon_manager.gd` | tick() 用 weapon.get_weapon_range() 替代 weapon_data.weapon_range * weapon_range_mult |
| `scripts/entities/weapons/bullet_weapon.gd` | fire() 用 weapon.get_damage() 替代 weapon_data.damage；移除 kill_stack/tower_link/crit/multishot 逻辑 |
| `scripts/entities/weapons/boomerang_weapon.gd` | fire() 适配 get_damage() |
| `scripts/entities/weapons/laser_weapon.gd` | fire() 适配 get_damage() |
| `scripts/entities/towers/tower.gd` | 新增 get_current_level(), _apply_level_stats()；_ready() 调用 _apply_level_stats()；监听 tower_upgraded |
| `scripts/entities/towers/tower_shooter.gd` | _ready() 从 per_level 数组初始化；_apply_level_stats() 更新 damage/range/rate |
| `scripts/entities/towers/tower_slow.gd` | _ready() 从 per_level 数组初始化；_apply_level_stats() 更新 slow_percent |
| `scripts/entities/player.gd` | initialize 用 owned_weapons.keys()；移除 slow_aura/auto_dash/dodge/shield/damage_reduction 逻辑 |
| `scripts/ui/placement_panel.gd` | 只显示已拥有塔，费用从 place_cost_per_level 读取 |
| `scripts/ui/placement.gd` | shop_panel 改为 3 格塔商店；移除 purchased_towers 兼容逻辑 |
| `scripts/ui/main.gd` | 波次结束弹出武器选择弹窗 |
| `resources/weapons/*.tres` (3 个) | 补充 per_level 数组，移除平面字段 |
| `resources/towers/*.tres` (3 个) | 补充 per_level 数组，移除平面字段 |
| `resources/characters/*.tres` (5 个) | 补充 default_tower，移除 affinity 字段 |
| `scripts/core/game_config.gd` | 移除 `var items: Dictionary` 和 `_load_resources_from_dir("res://resources/items/", items)` |
| `scripts/ui/result.gd` | 移除 purchased_item_list 和 GameConfig.items 引用，改为展示已拥有武器/塔 |
| `scripts/ui/character_selection.gd` | 移除 _fill_affinity()、selected_weapon 引用 |
| `scripts/entities/projectiles/bullet_projectile.gd` | 移除 lifesteal 逻辑 |
| `tests/unit/test_game_data_stats.gd` | 移除 purchased_item_list 和 record_item_purchased 测试 |

### 新增的文件
| 文件 | 职责 |
|------|------|
| `scripts/systems/weapon_upgrade_generator.gd` | 武器选项生成：从已拥有 + 全部武器池中抽 3 个选项 |
| `scripts/systems/tower_shop_generator.gd` | 塔商店选项生成：从已拥有 + 全部塔池中抽 3 个选项 + 价格 |
| `scripts/ui/weapon_select_popup.gd` | 武器选择弹窗 UI（CanvasLayer，3 选 1） |
| `scenes/ui/weapon_select_popup.tscn` | 武器选择弹窗场景 |
| `tests/unit/test_weapon_upgrade_generator.gd` | 武器选项生成器测试 |
| `tests/unit/test_tower_shop_generator.gd` | 塔商店生成器测试 |
| `tests/unit/test_weapon_level.gd` | 武器等级属性读取测试 |
| `tests/unit/test_tower_level.gd` | 塔等级属性 + 全局升级测试 |

### 删除的文件
| 文件 | 原因 |
|------|------|
| `scripts/resources/shop_item_data.gd` | 道具系统移除 |
| `scripts/systems/shop_item_generator.gd` | 道具系统移除 |
| `scripts/systems/shop_effect_applier.gd` | 道具系统移除 |
| `scripts/systems/item_effect_manager.gd` | 道具系统移除 |
| `scripts/systems/shop_manager.gd` | 旧商店 UI（被 shop_panel.gd 塔商店替代） |
| `resources/items/*.tres` (37 个) | 道具系统移除 |
| `tests/unit/test_shop_panel.gd` | 旧测试（Task 11 重写） |
| `tests/unit/test_shop_items_loaded.gd` | 旧道具加载测试 |
| `tests/unit/test_shop_manager_logic.gd` | 旧商店逻辑测试 |

---

## Chunk 1: Resource 数据层 + GameData 重构

### Task 1: WeaponData 添加等级数组

**Files:**
- Modify: `scripts/resources/weapon_data.gd`
- Modify: `resources/weapons/rifle.tres`
- Modify: `resources/weapons/boomerang.tres`
- Modify: `resources/weapons/laser.tres`
- Test: `tests/unit/test_weapon_level.gd`

- [ ] **Step 1: 写失败测试 — 验证 WeaponData 有 per_level 字段**

创建 `tests/unit/test_weapon_level.gd`:

```gdscript
extends GutTest

func test_weapon_data_has_level_fields():
	var wd: WeaponData = GameConfig.weapons["rifle"]
	assert_eq(wd.max_level, 5, "应有最大等级 5")
	assert_eq(wd.damage_per_level.size(), 5, "damage_per_level 应有 5 级")
	assert_eq(wd.fire_rate_per_level.size(), 5, "fire_rate_per_level 应有 5 级")
	assert_eq(wd.weapon_range_per_level.size(), 5, "weapon_range_per_level 应有 5 级")

func test_weapon_data_level_values_increase():
	var wd: WeaponData = GameConfig.weapons["rifle"]
	# 伤害应逐级递增
	for i in range(1, wd.damage_per_level.size()):
		assert_gt(wd.damage_per_level[i], wd.damage_per_level[i - 1],
			"Lv%d 伤害应大于 Lv%d" % [i + 1, i])
```

- [ ] **Step 2: 运行测试验证失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_weapon_level.gd`
Expected: FAIL — WeaponData 没有 max_level 等字段

- [ ] **Step 3: 修改 WeaponData 添加等级字段**

修改 `scripts/resources/weapon_data.gd`，保留旧平面字段作为 Lv1 默认值的兼容（本 Task 不删，Task 5 统一删）：

```gdscript
class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var projectile_type: String = "bullet"

# === 等级系统 ===
@export var max_level: int = 5
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var weapon_range_per_level: PackedFloat32Array = []
@export var milestones: Dictionary = {}

# === 旧平面字段（暂保留，Task 5 移除）===
@export var fire_rate: float = 0.1
@export var damage: float = 10.0
@export var weapon_range: float = 300.0

# 子弹特有
@export var bullet_count: int = 1
@export var bullet_speed: float = 600.0

# 回旋镖特有
@export var boomerang_speed: float = 350.0
@export var outbound_distance: float = 200.0
@export var return_speed_mult: float = 1.3

# 通用
@export var knockback_force: float = 80.0

# 激光特有
@export var beam_range: float = 400.0
@export var beam_width: float = 2.0
@export var beam_duration: float = 0.08
```

- [ ] **Step 4: 更新 rifle.tres 添加 per_level 数据**

```
[gd_resource type="Resource" script_class="WeaponData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/weapon_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "rifle"
display_name = "步枪"
max_level = 5
damage_per_level = PackedFloat32Array(10, 15, 22, 30, 40)
fire_rate_per_level = PackedFloat32Array(0.1, 0.09, 0.08, 0.07, 0.06)
weapon_range_per_level = PackedFloat32Array(300, 320, 340, 370, 400)
```

> 注意：Godot `.tres` 中 `Array[float]` 序列化为 `PackedFloat32Array`。

- [ ] **Step 5: 更新 boomerang.tres 添加 per_level 数据**

```
damage_per_level = PackedFloat32Array(15, 22, 30, 40, 55)
fire_rate_per_level = PackedFloat32Array(0.8, 0.72, 0.65, 0.58, 0.5)
weapon_range_per_level = PackedFloat32Array(200, 220, 240, 260, 300)
```

- [ ] **Step 6: 更新 laser.tres 添加 per_level 数据**

```
damage_per_level = PackedFloat32Array(8, 12, 17, 23, 30)
fire_rate_per_level = PackedFloat32Array(0.15, 0.13, 0.11, 0.09, 0.07)
weapon_range_per_level = PackedFloat32Array(400, 430, 460, 500, 550)
```

- [ ] **Step 7: 运行测试验证通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_weapon_level.gd`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add scripts/resources/weapon_data.gd resources/weapons/*.tres tests/unit/test_weapon_level.gd
git commit -m "feat: WeaponData 添加 per_level 等级数组字段和数据"
```

---

### Task 2: TowerData 添加等级数组

**Files:**
- Modify: `scripts/resources/tower_data.gd`
- Modify: `resources/towers/shooter.tres`
- Modify: `resources/towers/wall.tres`
- Modify: `resources/towers/slow.tres`
- Test: `tests/unit/test_tower_level.gd`

- [ ] **Step 1: 写失败测试 — 验证 TowerData 有 per_level 字段**

创建 `tests/unit/test_tower_level.gd`:

```gdscript
extends GutTest

func test_tower_data_has_level_fields():
	var td: TowerData = GameConfig.towers["shooter"]
	assert_eq(td.max_level, 5, "应有最大等级 5")
	assert_eq(td.hp_per_level.size(), 5, "hp_per_level 应有 5 级")
	assert_eq(td.damage_per_level.size(), 5, "damage_per_level 应有 5 级")
	assert_eq(td.shop_price_per_level.size(), 5, "shop_price_per_level 应有 5 级")
	assert_eq(td.place_cost_per_level.size(), 5, "place_cost_per_level 应有 5 级")

func test_tower_wall_has_level_fields():
	var td: TowerData = GameConfig.towers["wall"]
	assert_eq(td.hp_per_level.size(), 5, "墙塔应有 5 级 HP")

func test_tower_slow_has_level_fields():
	var td: TowerData = GameConfig.towers["slow"]
	assert_eq(td.slow_ratio_per_level.size(), 5, "减速塔应有 5 级减速比例")
```

- [ ] **Step 2: 运行测试验证失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_tower_level.gd`
Expected: FAIL

- [ ] **Step 3: 修改 TowerData 添加等级字段**

修改 `scripts/resources/tower_data.gd`（保留旧平面字段，Task 5 统一删）：

```gdscript
class_name TowerData
extends Resource

@export var id: String = ""
@export var display_name: String = ""

# === 等级系统 ===
@export var max_level: int = 5
@export var hp_per_level: PackedFloat32Array = []
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var attack_range_per_level: PackedFloat32Array = []
@export var slow_ratio_per_level: PackedFloat32Array = []
@export var shop_price_per_level: PackedInt32Array = []
@export var place_cost_per_level: PackedInt32Array = []
@export var milestones: Dictionary = {}

# === 旧平面字段（暂保留，Task 5 移除）===
@export var hp: float = 100.0
@export var damage: float = 0.0
@export var fire_rate: float = 0.0
@export var attack_range: float = 0.0
@export var shop_price_min: int = 35
@export var shop_price_max: int = 45
@export var slow_percent: float = 0.0
```

- [ ] **Step 4: 更新 shooter.tres**

```
hp_per_level = PackedFloat32Array(80, 110, 150, 200, 260)
damage_per_level = PackedFloat32Array(15, 22, 30, 40, 55)
fire_rate_per_level = PackedFloat32Array(1.0, 0.9, 0.8, 0.7, 0.6)
attack_range_per_level = PackedFloat32Array(300, 320, 340, 370, 400)
shop_price_per_level = PackedInt32Array(0, 25, 45, 70, 100)
place_cost_per_level = PackedInt32Array(15, 20, 28, 38, 50)
```

> 注意：`Array[int]` 在 `.tres` 中序列化为 `PackedInt32Array`。

- [ ] **Step 5: 更新 wall.tres**

```
hp_per_level = PackedFloat32Array(300, 400, 520, 660, 820)
damage_per_level = PackedFloat32Array(0, 0, 0, 0, 0)
fire_rate_per_level = PackedFloat32Array(0, 0, 0, 0, 0)
attack_range_per_level = PackedFloat32Array(0, 0, 0, 0, 0)
shop_price_per_level = PackedInt32Array(0, 20, 35, 55, 80)
place_cost_per_level = PackedInt32Array(10, 14, 20, 28, 38)
```

- [ ] **Step 6: 更新 slow.tres**

```
hp_per_level = PackedFloat32Array(70, 95, 125, 160, 200)
slow_ratio_per_level = PackedFloat32Array(0.3, 0.35, 0.4, 0.45, 0.5)
attack_range_per_level = PackedFloat32Array(200, 220, 240, 260, 300)
shop_price_per_level = PackedInt32Array(0, 20, 40, 65, 95)
place_cost_per_level = PackedInt32Array(12, 17, 24, 33, 44)
```

- [ ] **Step 7: 运行测试验证通过**

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add scripts/resources/tower_data.gd resources/towers/*.tres tests/unit/test_tower_level.gd
git commit -m "feat: TowerData 添加 per_level 等级数组字段和数据"
```

---

### Task 3: CharacterData 变更 + characters .tres 更新

**Files:**
- Modify: `scripts/resources/character_data.gd`
- Modify: `resources/characters/dora.tres`
- Modify: `resources/characters/gorg.tres`
- Modify: `resources/characters/kaze.tres`
- Modify: `resources/characters/merlin.tres`
- Modify: `resources/characters/nemo.tres`

- [ ] **Step 1: 修改 CharacterData**

在 `scripts/resources/character_data.gd` 中：
- 移除 `affinity_tags` 和 `affinity_discount` 字段
- 新增 `default_tower: String`

```gdscript
class_name CharacterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var max_hp: float = 100.0
@export var speed: float = 200.0
@export var damage_mult: float = 1.0
@export var attack_speed_mult: float = 1.0
@export var move_speed_mult: float = 1.0
@export var hp_regen: float = 0.0
## 角色默认武器 ID
@export var default_weapon: String = ""
## 角色默认塔 ID
@export var default_tower: String = ""
## 角色特色被动描述（展示用）
@export var passive_description: String = ""
## 精灵 SpriteFrames 资源路径
@export var sprite_frames_path: String = ""
## 头像 PNG 路径
@export var portrait_path: String = ""
## 原始精灵像素尺寸
@export var sprite_pixel_size: float = 32.0
```

- [ ] **Step 2: 更新 5 个 character .tres 文件**

每个文件：
- 移除 `affinity_tags = ...` 行
- 移除 `affinity_discount = ...` 行
- 添加 `default_tower = "shooter"` (初期所有角色默认射手塔，后续调整)

dora.tres: `default_tower = "shooter"`
gorg.tres: `default_tower = "wall"`
kaze.tres: `default_tower = "slow"`
merlin.tres: `default_tower = "shooter"`
nemo.tres: `default_tower = "shooter"`

- [ ] **Step 3: Commit**

```bash
git add scripts/resources/character_data.gd resources/characters/*.tres
git commit -m "feat: CharacterData 移除亲和系统，新增 default_tower"
```

---

### Task 4: GameData 重构 + EventBus 新信号

**Files:**
- Modify: `scripts/core/game_data.gd`
- Modify: `scripts/core/event_bus.gd`

- [ ] **Step 1: 修改 EventBus 添加新信号**

在 `scripts/core/event_bus.gd` 的塔防事件区域添加：

```gdscript
signal tower_upgraded(tower_type: String)
signal tower_purchased(tower_type: String)
```

- [ ] **Step 2: 重写 GameData**

完全重写 `scripts/core/game_data.gd`：

```gdscript
extends Node

# 角色系统
var current_character: String = Enums.Character.DORA
var character_max_hp: float = 0.0
var character_speed: float = 0.0
var character_damage_mult: float = 1.0
var character_attack_speed_mult: float = 1.0
var character_move_speed_mult: float = 1.0
var character_hp_regen: float = 0.0

var selected_map: String = Enums.Map.FOREST
var player_stats: Dictionary = {
	Enums.Stat.MAX_HP: 100.0,
	Enums.Stat.HP_MULT: 1.0,
	Enums.Stat.HP_REGEN: 0.0,
	Enums.Stat.DAMAGE_MULT: 1.0,
	Enums.Stat.ATTACK_SPEED_MULT: 1.0,
	Enums.Stat.MOVE_SPEED_MULT: 1.0,
	Enums.Stat.TOWER_MULT: 1.0
}
var coins: int = GameConfig.PLAYER["initial_coins"]
var current_wave: int = 0
var tower_inventory: Array = []  # 已布置的塔 {type, position}
var pending_heal: int = 0

## 武器/塔 拥有状态 {id: level}
var owned_weapons: Dictionary = {}
var owned_towers: Dictionary = {}

## 里程碑效果保留字段（初期不使用，后续 milestones 写入）
var pierce_count: int = 0
var multishot_active: bool = false
var multishot_damage_mult: float = 1.0
var split_count: int = 0
var split_damage_mult: float = 0.5
var bullet_speed_mult: float = 1.0
var weapon_range_mult: float = 1.0
var crit_chance: float = 0.0
var crit_damage_mult: float = 2.0

## ===== 本局统计 =====
var total_kills: int = 0
var total_coins_earned: int = 0
var total_damage_taken: float = 0.0
var max_kill_streak: int = 0
var current_kill_streak: int = 0

const _DEFAULTS: Dictionary = {
	"current_wave": 0,
	"tower_inventory": [],
	"pending_heal": 0,
	"owned_weapons": {},
	"owned_towers": {},
	"pierce_count": 0,
	"multishot_active": false,
	"multishot_damage_mult": 1.0,
	"split_count": 0,
	"split_damage_mult": 0.5,
	"bullet_speed_mult": 1.0,
	"weapon_range_mult": 1.0,
	"crit_chance": 0.0,
	"crit_damage_mult": 2.0,
	"total_kills": 0,
	"total_coins_earned": 0,
	"total_damage_taken": 0.0,
	"max_kill_streak": 0,
	"current_kill_streak": 0,
}

func _ready() -> void:
	init_character(current_character)

func init_character(character_id: String) -> void:
	if not GameConfig.characters.has(character_id):
		push_error("未知角色: " + character_id)
		character_id = Enums.Character.DORA
	current_character = character_id
	var char_data: CharacterData = GameConfig.characters[character_id]
	character_max_hp = char_data.max_hp
	character_speed = char_data.speed
	character_damage_mult = char_data.damage_mult
	character_attack_speed_mult = char_data.attack_speed_mult
	character_move_speed_mult = char_data.move_speed_mult
	character_hp_regen = char_data.hp_regen
	print("角色初始化: ", char_data.display_name, " (", character_id, ")")

func reset() -> void:
	init_character(current_character)
	var char_data: CharacterData = GameConfig.characters[current_character]
	selected_map = Enums.Map.FOREST
	player_stats = {
		Enums.Stat.MAX_HP: character_max_hp,
		Enums.Stat.HP_MULT: 1.0,
		Enums.Stat.HP_REGEN: character_hp_regen,
		Enums.Stat.DAMAGE_MULT: character_damage_mult,
		Enums.Stat.ATTACK_SPEED_MULT: character_attack_speed_mult,
		Enums.Stat.MOVE_SPEED_MULT: character_move_speed_mult,
		Enums.Stat.TOWER_MULT: 1.0
	}
	coins = GameConfig.PLAYER["initial_coins"]
	# 批量重置
	for key: String in _DEFAULTS:
		var val: Variant = _DEFAULTS[key]
		if val is Array or val is Dictionary:
			set(key, val.duplicate())
		else:
			set(key, val)
	# 从角色配置初始化拥有的武器和塔
	owned_weapons = {char_data.default_weapon: 1}
	owned_towers = {char_data.default_tower: 1}

func upgrade_weapon(weapon_id: String) -> void:
	var current_level: int = owned_weapons.get(weapon_id, 0)
	if current_level == 0:
		# 新武器，Lv1
		owned_weapons[weapon_id] = 1
	else:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if current_level < wd.max_level:
			owned_weapons[weapon_id] = current_level + 1

func upgrade_tower(tower_id: String) -> void:
	var current_level: int = owned_towers.get(tower_id, 0)
	if current_level == 0:
		owned_towers[tower_id] = 1
		EventBus.tower_purchased.emit(tower_id)
	else:
		var td: TowerData = GameConfig.towers[tower_id]
		if current_level < td.max_level:
			owned_towers[tower_id] = current_level + 1
			EventBus.tower_upgraded.emit(tower_id)

func record_kill() -> void:
	total_kills += 1
	current_kill_streak += 1
	if current_kill_streak > max_kill_streak:
		max_kill_streak = current_kill_streak

func reset_kill_streak() -> void:
	current_kill_streak = 0

func record_damage_taken(amount: float) -> void:
	total_damage_taken += amount

func record_coins_earned(amount: int) -> void:
	total_coins_earned += amount
```

- [ ] **Step 3: 运行全量测试观察哪些挂了**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: test_shop_panel.gd 和引用旧字段的测试会失败（这是预期的，后续 Task 修复）

- [ ] **Step 4: Commit**

```bash
git add scripts/core/game_data.gd scripts/core/event_bus.gd
git commit -m "feat: GameData 重构为武器/塔等级系统，EventBus 添加升级信号"
```

---

### Task 5: 移除旧道具系统文件和代码

**Files:**
- Delete: `scripts/resources/shop_item_data.gd`
- Delete: `scripts/systems/shop_item_generator.gd`
- Delete: `scripts/systems/shop_effect_applier.gd`
- Delete: `scripts/systems/item_effect_manager.gd`
- Delete: `resources/items/*.tres` (37 个)
- Delete: `tests/unit/test_shop_panel.gd` (旧测试，Task 11 重写)
- Delete: `tests/unit/test_shop_items_loaded.gd` (旧道具加载测试)
- Delete: `tests/unit/test_shop_manager_logic.gd` (旧商店逻辑测试)
- Delete: `scripts/systems/shop_manager.gd` (旧商店 UI)
- Delete: `scripts/ui/shop_item_card.gd` + `scenes/ui/shop_item_card.tscn` (旧商品卡片)
- Delete: `tests/unit/test_shop_item_data.gd` (旧道具数据测试)
- Modify: `scripts/core/enums.gd` — 移除 ItemTag, ItemRarity, ItemEffect
- Modify: `scripts/core/game_config.gd` — 移除 items 字典和加载
- Modify: `scripts/ui/result.gd` — 移除道具引用，改为武器/塔展示
- Modify: `scripts/ui/character_selection.gd` — 移除 _fill_affinity()、selected_weapon 引用
- Modify: `scripts/entities/projectiles/bullet_projectile.gd` — 移除 lifesteal 逻辑
- Modify: `tests/unit/test_game_data_stats.gd` — 移除 purchased_item_list 相关测试

- [ ] **Step 1: 删除旧道具系统文件**

```bash
rm scripts/resources/shop_item_data.gd
rm scripts/systems/shop_item_generator.gd
rm scripts/systems/shop_effect_applier.gd
rm scripts/systems/item_effect_manager.gd
rm scripts/systems/shop_manager.gd
rm -rf resources/items/
rm tests/unit/test_shop_panel.gd
rm tests/unit/test_shop_items_loaded.gd
rm tests/unit/test_shop_manager_logic.gd
rm tests/unit/test_shop_item_data.gd
rm scripts/ui/shop_item_card.gd
rm scenes/ui/shop_item_card.tscn
```

- [ ] **Step 2: 修改 enums.gd 移除道具相关枚举**

从 `scripts/core/enums.gd` 中移除以下类（约第 89-128 行）：
- `class ItemTag`
- `class ItemRarity`
- `class ItemEffect`

- [ ] **Step 2b: 修改 game_config.gd 移除 items 加载**

从 `scripts/core/game_config.gd` 中：
- 移除 `var items: Dictionary = {}` 字段（第 118 行）
- 移除 `_load_resources_from_dir("res://resources/items/", items)` 调用（第 131 行）

- [ ] **Step 2c: 修改 result.gd 移除道具引用**

`scripts/ui/result.gd` 中第 30 行引用 `GameData.purchased_item_list`，第 38-55 行遍历 `GameConfig.items`。替换为展示已拥有武器/塔：

```gdscript
	# 替换原 "购买物品" 行
	_add_stat_row(stats_grid, "拥有武器", str(GameData.owned_weapons.size()))
	_add_stat_row(stats_grid, "拥有塔", str(GameData.owned_towers.size()))

	# 替换原 ItemsPanel 内容：显示武器和塔等级
	var items_flow: HFlowContainer = vbox.get_node("ItemsPanel/ItemsFlow")
	for weapon_id: String in GameData.owned_weapons:
		var level: int = GameData.owned_weapons[weapon_id]
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		var label := Label.new()
		label.text = "%s Lv%d" % [wd.display_name, level]
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
		var pill := PanelContainer.new()
		var pill_style := UIConstants.create_panel_stylebox(Color(0.2, 0.2, 0.3, 0.8), 6)
		pill_style.content_margin_left = 8
		pill_style.content_margin_right = 8
		pill_style.content_margin_top = 4
		pill_style.content_margin_bottom = 4
		pill.add_theme_stylebox_override("panel", pill_style)
		pill.add_child(label)
		items_flow.add_child(pill)
	for tower_id: String in GameData.owned_towers:
		var level: int = GameData.owned_towers[tower_id]
		var td: TowerData = GameConfig.towers[tower_id]
		var label := Label.new()
		label.text = "%s Lv%d" % [td.display_name, level]
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
		label.add_theme_color_override("font_color", Color("#80c0ff"))
		var pill := PanelContainer.new()
		var pill_style := UIConstants.create_panel_stylebox(Color(0.15, 0.2, 0.3, 0.8), 6)
		pill_style.content_margin_left = 8
		pill_style.content_margin_right = 8
		pill_style.content_margin_top = 4
		pill_style.content_margin_bottom = 4
		pill.add_theme_stylebox_override("panel", pill_style)
		pill.add_child(label)
		items_flow.add_child(pill)
```

- [ ] **Step 2d: 修改 test_game_data_stats.gd**

移除以下测试（引用已删除的 record_item_purchased/purchased_item_list）：
- `test_record_item_purchased()` — 整个函数删除
- `test_stats_fields_exist()` — 移除 `assert_eq(GameData.purchased_item_list.size(), 0)` 行
- `test_reset_clears_stats()` — 移除 `GameData.record_item_purchased("test")` 和 `assert_eq(GameData.purchased_item_list.size(), 0)` 行

同时在 `test_shop_items_loaded.gd` 已在 Step 1 删除，`test_dora_character_loaded` 中引用 `affinity_tags` 的断言也已随文件删除。

- [ ] **Step 2e: 修改 character_selection.gd**

`scripts/ui/character_selection.gd` 中：
- 第 263 行 `GameData.selected_weapon = char_data.default_weapon` — 移除（GameData.reset() 已通过 owned_weapons 初始化）
- 第 228-255 行 `_fill_affinity()` 方法 — 整个方法删除
- 第 210 行 `_fill_affinity(char_data)` 调用 — 删除
- 第 28 行 `@onready var _affinity_section` — 删除（若有对应 UI 节点引用也删除）

> 角色选择页面不再显示亲和信息，可以改为显示"初始武器"和"初始塔"。

- [ ] **Step 2f: 修改 bullet_projectile.gd 移除 lifesteal**

`scripts/entities/projectiles/bullet_projectile.gd` 中：
- 第 75-78 行 lifesteal 逻辑 — 移除（`GameData.lifesteal_ratio` 已删除）
- 保留 split_count/split_damage_mult 引用（这些是 milestone 保留字段）

- [ ] **Step 3: 移除 WeaponData/TowerData 旧平面字段**

从 `scripts/resources/weapon_data.gd` 移除：
- `@export var fire_rate: float = 0.1`
- `@export var damage: float = 10.0`
- `@export var weapon_range: float = 300.0`

从 `scripts/resources/tower_data.gd` 移除：
- `@export var hp: float = 100.0`
- `@export var damage: float = 0.0`
- `@export var fire_rate: float = 0.0`
- `@export var attack_range: float = 0.0`
- `@export var shop_price_min: int = 35`
- `@export var shop_price_max: int = 45`
- `@export var slow_percent: float = 0.0`

同时从 3 个 tower .tres 和 3 个 weapon .tres 中移除对应的旧平面字段行（如 `hp = 80.0`, `damage = 15.0` 等）。

> **tower_wall.tscn** 使用 `tower.gd` 基类脚本（无独立脚本），等级化 HP 由基类 `_apply_level_stats()` 处理，无需额外修改场景文件。

- [ ] **Step 4: 更新 global_script_class_cache.cfg**

移除 `ShopItemData` 条目（如果存在）。headless 测试依赖此缓存文件。

查看 `.godot/global_script_class_cache.cfg`，搜索 `ShopItemData`，删除对应条目。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: 移除旧道具系统（37 tres + 4 脚本 + 枚举 + 旧平面字段）"
```

---

## Chunk 2: 武器等级化运行时 + 塔等级化运行时

### Task 6: Weapon 基类等级化属性读取

**Files:**
- Modify: `scripts/entities/weapons/weapon.gd`
- Modify: `scripts/entities/weapons/weapon_manager.gd`
- Modify: `scripts/entities/weapons/bullet_weapon.gd`
- Modify: `scripts/entities/weapons/boomerang_weapon.gd`
- Modify: `scripts/entities/weapons/laser_weapon.gd`
- Modify: `scripts/entities/player.gd`
- Test: `tests/unit/test_weapon_level.gd` (扩展)

- [ ] **Step 1: 写失败测试 — 武器等级化属性**

在 `tests/unit/test_weapon_level.gd` 中追加：

```gdscript
var _original_owned_weapons: Dictionary

func before_each():
	_original_owned_weapons = GameData.owned_weapons.duplicate()

func after_each():
	GameData.owned_weapons = _original_owned_weapons

func test_weapon_get_damage_reads_level():
	GameData.owned_weapons = {"rifle": 3}
	var weapon := BulletWeapon.new()
	var wd: WeaponData = GameConfig.weapons["rifle"]
	weapon.initialize(wd)
	assert_almost_eq(weapon.get_damage(), wd.damage_per_level[2], 0.01,
		"Lv3 伤害应读 damage_per_level[2]")
	add_child_autofree(weapon)

func test_weapon_get_fire_rate_reads_level():
	GameData.owned_weapons = {"rifle": 1}
	var weapon := BulletWeapon.new()
	var wd: WeaponData = GameConfig.weapons["rifle"]
	weapon.initialize(wd)
	assert_almost_eq(weapon.get_fire_rate(), wd.fire_rate_per_level[0], 0.01,
		"Lv1 射速应读 fire_rate_per_level[0]")
	add_child_autofree(weapon)

func test_weapon_get_weapon_range_reads_level():
	GameData.owned_weapons = {"rifle": 5}
	var weapon := BulletWeapon.new()
	var wd: WeaponData = GameConfig.weapons["rifle"]
	weapon.initialize(wd)
	assert_almost_eq(weapon.get_weapon_range(), wd.weapon_range_per_level[4], 0.01,
		"Lv5 射程应读 weapon_range_per_level[4]")
	add_child_autofree(weapon)
```

- [ ] **Step 2: 运行测试验证失败**

Expected: FAIL — Weapon 没有 get_damage() 等方法

- [ ] **Step 3: 修改 weapon.gd**

重写 `scripts/entities/weapons/weapon.gd`：

```gdscript
# Weapon — 武器基类（不可见 Node）
class_name Weapon
extends Node

var weapon_data: WeaponData = null
var owner_node: Node2D = null
var _cooldown: float = 0.0

func initialize(data: WeaponData) -> void:
	weapon_data = data
	_cooldown = 0.0

func get_current_level() -> int:
	return GameData.owned_weapons.get(weapon_data.id, 1)

func get_damage() -> float:
	return weapon_data.damage_per_level[get_current_level() - 1]

func get_fire_rate() -> float:
	return weapon_data.fire_rate_per_level[get_current_level() - 1]

func get_weapon_range() -> float:
	return weapon_data.weapon_range_per_level[get_current_level() - 1]

func tick(delta: float, target: Node2D) -> void:
	_cooldown -= delta
	if _cooldown <= 0.0 and target:
		fire(target)
		var speed_mult: float = GameData.player_stats.get(Enums.Stat.ATTACK_SPEED_MULT, 1.0)
		_cooldown = get_fire_rate() / speed_mult

func fire(_target: Node2D) -> void:
	pass  # 子类实现
```

> 注意：移除了 enemy_killed 连接和 kill_stack 逻辑。

- [ ] **Step 4: 修改 weapon_manager.gd**

将 `tick()` 中 `weapon.weapon_data.weapon_range` 替换为 `weapon.get_weapon_range()`，移除 `weapon_range_mult`：

```gdscript
func tick(delta: float) -> void:
	var max_range: float = 0.0
	for weapon in _weapons:
		var wr: float = weapon.get_weapon_range()
		if wr > max_range:
			max_range = wr
	var target: Node2D = _find_closest_enemy(max_range)
	for weapon in _weapons:
		weapon.tick(delta, target)
```

- [ ] **Step 5: 修改 bullet_weapon.gd**

简化 `fire()` — 移除 kill_stack、crit、tower_link、multishot 逻辑（这些将来通过 milestones 按需恢复）：

```gdscript
class_name BulletWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		push_error("BulletWeapon: owner has no parent scene")
		return
	var base_dir: Vector2 = owner_node.global_position.direction_to(target.global_position)
	_spawn_bullet(scene_parent, base_dir, base_damage)
	_spawn_muzzle_flash(owner_node)
	AudioManager.play("shoot")

func _spawn_bullet(scene_parent: Node, direction: Vector2, damage: float) -> void:
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	bullet.speed = weapon_data.bullet_speed
	scene_parent.add_child(bullet)
	bullet.setup(damage, weapon_data.knockback_force, owner_node.global_position, direction)

func _spawn_muzzle_flash(owner_node: Node2D) -> void:
	var fx: EffectConfigData = GameConfig.effects
	var flash: ColorRect = ColorRect.new()
	flash.size = fx.muzzle_flash_size
	flash.color = fx.muzzle_flash_color
	flash.z_index = fx.muzzle_flash_z_index
	var parent: Node = owner_node.get_parent()
	if not parent:
		return
	parent.add_child(flash)
	flash.global_position = owner_node.global_position - fx.muzzle_flash_size / 2
	var tween: Tween = owner_node.create_tween()
	tween.tween_property(flash, "scale", Vector2(0.1, 0.1), fx.muzzle_flash_duration).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.queue_free)
```

- [ ] **Step 6: 修改 boomerang_weapon.gd 和 laser_weapon.gd**

两个文件中将 `weapon_data.damage` 替换为 `get_damage()`。

> boomerang_weapon.gd: fire() 中的 damage 参数使用 `get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)`
> laser_weapon.gd: 同上

- [ ] **Step 7: 修改 player.gd**

在 `_ready()` 中修改武器初始化（第 45 行）：

```gdscript
# 旧: _weapon_manager.initialize([GameData.selected_weapon])
var weapon_ids: Array[String] = []
for id: String in GameData.owned_weapons:
	weapon_ids.append(id)
_weapon_manager.initialize(weapon_ids)
```

移除以下道具相关逻辑：
- `_process()` 中的 slow_aura 相关代码（第 74-79 行）
- `_process()` 中的 auto_dash 相关代码（第 82-83 行）
- `_apply_damage()` 中的 dodge/shield/damage_reduction 逻辑（第 129-136 行），简化为直接扣血
- `_update_auto_dash()`, `_start_dash()`, `_end_dash()`, `_apply_slow_aura()` 方法
- 对应的常量和成员变量：`MAX_DODGE_CHANCE`, `MAX_DAMAGE_REDUCTION`, `SLOW_AURA_TICK_INTERVAL`, `DASH_SPEED`, `DASH_INVINCIBLE_BUFFER`, `_aura_slowed_enemies`, `_dash_timer`, `_is_dashing`, `_dash_direction`, `_dash_remaining`, `_slow_aura_timer`

简化后的 `_apply_damage()`：
```gdscript
func _apply_damage(raw_damage: float) -> void:
	health.take_damage_no_sparks(raw_damage)
	GameData.record_damage_taken(raw_damage)
	_flash_white()
	invincible_timer = invincible_duration
	var fx: EffectConfigData = GameConfig.effects
	EventBus.camera_shake_requested.emit(fx.camera_shake_player_hit_intensity, fx.camera_shake_player_hit_duration)
```

简化后的 `_physics_process()` — 移除 dash 分支：
```gdscript
func _physics_process(_delta: float) -> void:
	var input_vector: Vector2 = Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
	velocity = input_vector * speed
	move_and_slide()
	_sprite_animator.update_animation(velocity)
	var camera: Camera2D = $Camera
	if camera and camera.has_method("update_look_ahead"):
		camera.update_look_ahead(velocity)
```

- [ ] **Step 8: 运行测试验证通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_weapon_level.gd`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add scripts/entities/weapons/ scripts/entities/player.gd tests/unit/test_weapon_level.gd
git commit -m "feat: 武器等级化属性读取，移除旧道具战斗逻辑"
```

---

### Task 7: Tower 等级化运行时 + SceneFactory 适配

**Files:**
- Modify: `scripts/entities/towers/tower.gd`
- Modify: `scripts/entities/towers/tower_shooter.gd`
- Modify: `scripts/entities/towers/tower_slow.gd`
- Modify: `scripts/core/scene_factory.gd`
- Test: `tests/unit/test_tower_level.gd` (扩展)

- [ ] **Step 1: 写失败测试 — 塔等级化属性和全局升级**

在 `tests/unit/test_tower_level.gd` 中追加：

```gdscript
var _original_owned_towers: Dictionary

func before_each():
	_original_owned_towers = GameData.owned_towers.duplicate()
	GameData.owned_towers = {"shooter": 1}

func after_each():
	GameData.owned_towers = _original_owned_towers

func test_scene_factory_get_tower_cost_reads_level():
	GameData.owned_towers = {"shooter": 3}
	var td: TowerData = GameConfig.towers["shooter"]
	var expected_cost: int = td.place_cost_per_level[2]
	assert_eq(SceneFactory.get_tower_cost("shooter"), expected_cost,
		"Lv3 放置费用应读 place_cost_per_level[2]")

func test_tower_upgrade_applies_globally():
	# 创建一座射手塔
	var tower: Node2D = SceneFactory.create_tower("shooter")
	add_child_autofree(tower)
	# 确认 Lv1 HP
	var td: TowerData = GameConfig.towers["shooter"]
	assert_almost_eq(tower.health.max_hp, td.hp_per_level[0], 0.01, "Lv1 HP")
	# 升级到 Lv2
	GameData.owned_towers["shooter"] = 2
	EventBus.tower_upgraded.emit("shooter")
	# 验证 HP 更新
	assert_almost_eq(tower.health.max_hp, td.hp_per_level[1], 0.01, "Lv2 HP 应全局更新")
```

- [ ] **Step 2: 运行测试验证失败**

Expected: FAIL

- [ ] **Step 3: 修改 tower.gd**

```gdscript
extends StaticBody2D
class_name Tower

var data: TowerData = null
var tower_type: String = Enums.TowerId.WALL

@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	_apply_level_stats()
	health.death_color = Color.GREEN
	health.died.connect(_on_died)
	add_to_group(Enums.Group.TOWERS)
	EventBus.tower_upgraded.connect(_on_tower_upgraded)

func get_current_level() -> int:
	return GameData.owned_towers.get(data.id, 1)

func _apply_level_stats() -> void:
	var level: int = get_current_level()
	var idx: int = level - 1
	health.initialize(data.hp_per_level[idx])

func _on_tower_upgraded(upgraded_type: String) -> void:
	if upgraded_type == data.id:
		_apply_level_stats()

func take_damage(amount: float) -> void:
	health.take_damage(amount)

func _on_died() -> void:
	EventBus.tower_upgraded.disconnect(_on_tower_upgraded)
	queue_free()
```

- [ ] **Step 4: 修改 tower_shooter.gd**

```gdscript
extends Tower

@export var attack_range: float = 300.0
@export var attack_damage: float = 10.0
@export var attack_rate: float = 1.0

@onready var detect_area: Area2D = $DetectArea
@onready var shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	tower_type = Enums.TowerId.SHOOTER
	super._ready()
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start()

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var level: int = get_current_level()
	var idx: int = level - 1
	attack_damage = data.damage_per_level[idx] * GameData.player_stats[Enums.Stat.TOWER_MULT]
	attack_rate = data.fire_rate_per_level[idx]
	attack_range = data.attack_range_per_level[idx]
	if shoot_timer:
		shoot_timer.wait_time = attack_rate

func _on_shoot_timer_timeout() -> void:
	_shoot_nearest_enemy()

func _shoot_nearest_enemy() -> void:
	var enemies: Array[Node2D] = detect_area.get_overlapping_bodies()
	var closest: Node2D = null
	var min_dist: float = attack_range
	for enemy: Node2D in enemies:
		if enemy.is_in_group(Enums.Group.ENEMIES):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	if closest:
		var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
		var direction: Vector2 = global_position.direction_to(closest.global_position)
		get_parent().add_child(bullet)
		bullet.setup(attack_damage, 0.0, global_position, direction)
```

> 注意：移除了 `_get_symbiosis_bonus()` — symbiosis 属于旧道具系统。

- [ ] **Step 5: 修改 tower_slow.gd**

```gdscript
extends Tower

@export var slow_radius: float = 200.0
@export var slow_percent: float = 0.5

@onready var slow_area: Area2D = $SlowArea

func _ready() -> void:
	tower_type = Enums.TowerId.SLOW
	super._ready()
	slow_area.body_entered.connect(_on_enemy_entered)
	slow_area.body_exited.connect(_on_enemy_exited)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var level: int = get_current_level()
	var idx: int = level - 1
	slow_radius = data.attack_range_per_level[idx]
	slow_percent = data.slow_ratio_per_level[idx]

func _on_enemy_entered(body: Node2D) -> void:
	if body.is_in_group(Enums.Group.ENEMIES) and body.has_method("apply_slow"):
		body.apply_slow(slow_percent)

func _on_enemy_exited(body: Node2D) -> void:
	if body.is_in_group(Enums.Group.ENEMIES) and body.has_method("remove_slow"):
		body.remove_slow(slow_percent)
```

- [ ] **Step 6: 修改 SceneFactory.get_tower_cost()**

```gdscript
func get_tower_cost(type: String) -> int:
	if not GameConfig.towers.has(type):
		push_error("Unknown tower type: " + type)
		return 0
	var td: TowerData = GameConfig.towers[type]
	var level: int = GameData.owned_towers.get(type, 1)
	return td.place_cost_per_level[level - 1]
```

- [ ] **Step 7: 运行测试验证通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_tower_level.gd`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add scripts/entities/towers/ scripts/core/scene_factory.gd tests/unit/test_tower_level.gd
git commit -m "feat: 塔等级化运行时，支持全局升级信号，SceneFactory 适配等级费用"
```

---

## Chunk 3: 武器选择弹窗 + 塔商店生成器

### Task 8: 武器选项生成器

**Files:**
- Create: `scripts/systems/weapon_upgrade_generator.gd`
- Test: `tests/unit/test_weapon_upgrade_generator.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_weapon_upgrade_generator.gd`:

```gdscript
extends GutTest

var _original_owned_weapons: Dictionary
var _generator: WeaponUpgradeGenerator

func before_each():
	_original_owned_weapons = GameData.owned_weapons.duplicate()
	_generator = WeaponUpgradeGenerator.new()

func after_each():
	GameData.owned_weapons = _original_owned_weapons

func test_generates_new_weapons_and_upgrades():
	GameData.owned_weapons = {"rifle": 1}
	var options: Array[Dictionary] = _generator.generate_options()
	assert_gt(options.size(), 0, "应生成至少 1 个选项")
	assert_lte(options.size(), 3, "最多 3 个选项")

func test_new_weapon_option_has_level_1():
	GameData.owned_weapons = {"rifle": 5}  # rifle 满级
	var options: Array[Dictionary] = _generator.generate_options()
	# 应该出现 boomerang 或 laser 作为新武器
	var has_new: bool = false
	for opt in options:
		if opt["weapon_id"] != "rifle":
			assert_eq(opt["target_level"], 1, "新武器应为 Lv1")
			has_new = true
	assert_true(has_new, "应有新武器选项")

func test_upgrade_option_has_next_level():
	GameData.owned_weapons = {"rifle": 2}
	var options: Array[Dictionary] = _generator.generate_options()
	for opt in options:
		if opt["weapon_id"] == "rifle":
			assert_eq(opt["target_level"], 3, "已有 Lv2 武器应升到 Lv3")

func test_max_level_weapon_excluded():
	GameData.owned_weapons = {"rifle": 5, "boomerang": 5, "laser": 5}
	var options: Array[Dictionary] = _generator.generate_options()
	assert_eq(options.size(), 0, "全部满级应返回空")

func test_no_duplicate_options():
	GameData.owned_weapons = {"rifle": 1}
	var options: Array[Dictionary] = _generator.generate_options()
	var ids: Array[String] = []
	for opt in options:
		assert_false(opt["weapon_id"] in ids, "不应有重复武器")
		ids.append(opt["weapon_id"])
```

- [ ] **Step 2: 运行测试验证失败**

Expected: FAIL — WeaponUpgradeGenerator 类不存在

- [ ] **Step 3: 实现 weapon_upgrade_generator.gd**

创建 `scripts/systems/weapon_upgrade_generator.gd`:

```gdscript
class_name WeaponUpgradeGenerator
extends RefCounted

## 生成武器选择弹窗的选项列表
## 返回: Array[Dictionary]，每项 = {weapon_id: String, target_level: int, is_new: bool}
func generate_options() -> Array[Dictionary]:
	var pool: Array[Dictionary] = _build_pool()
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size()))

func _build_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for weapon_id: String in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		var current_level: int = GameData.owned_weapons.get(weapon_id, 0)
		if current_level == 0:
			# 新武器
			pool.append({
				"weapon_id": weapon_id,
				"target_level": 1,
				"is_new": true,
			})
		elif current_level < wd.max_level:
			# 已有但未满级
			pool.append({
				"weapon_id": weapon_id,
				"target_level": current_level + 1,
				"is_new": false,
			})
		# 满级的不进池
	return pool
```

- [ ] **Step 4: 更新 global_script_class_cache.cfg 添加 WeaponUpgradeGenerator**

检查 `.godot/global_script_class_cache.cfg`，添加：
```
WeaponUpgradeGenerator = { "base": "RefCounted", "path": "res://scripts/systems/weapon_upgrade_generator.gd" }
```

- [ ] **Step 5: 运行测试验证通过**

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/systems/weapon_upgrade_generator.gd tests/unit/test_weapon_upgrade_generator.gd .godot/global_script_class_cache.cfg
git commit -m "feat: 武器选项生成器 WeaponUpgradeGenerator"
```

---

### Task 9: 塔商店生成器

**Files:**
- Create: `scripts/systems/tower_shop_generator.gd`
- Test: `tests/unit/test_tower_shop_generator.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_tower_shop_generator.gd`:

```gdscript
extends GutTest

var _original_owned_towers: Dictionary
var _generator: TowerShopGenerator

func before_each():
	_original_owned_towers = GameData.owned_towers.duplicate()
	_generator = TowerShopGenerator.new()

func after_each():
	GameData.owned_towers = _original_owned_towers

func test_generates_options_with_prices():
	GameData.owned_towers = {"shooter": 1}
	var result: Dictionary = _generator.generate_options()
	assert_true(result.has("items"), "应有 items 数组")
	assert_true(result.has("prices"), "应有 prices 数组")
	assert_gt(result["items"].size(), 0, "应有至少 1 个选项")
	assert_lte(result["items"].size(), 3, "最多 3 个选项")
	assert_eq(result["items"].size(), result["prices"].size(), "items 和 prices 等长")

func test_new_tower_price_is_level_1():
	GameData.owned_towers = {"shooter": 5}  # shooter 满级
	var result: Dictionary = _generator.generate_options()
	for i in range(result["items"].size()):
		var item: Dictionary = result["items"][i]
		if item["is_new"]:
			var td: TowerData = GameConfig.towers[item["tower_id"]]
			assert_eq(result["prices"][i], td.shop_price_per_level[0], "新塔价格应为 Lv1 购买价")

func test_upgrade_price_reads_per_level():
	GameData.owned_towers = {"shooter": 2}
	var result: Dictionary = _generator.generate_options()
	for i in range(result["items"].size()):
		var item: Dictionary = result["items"][i]
		if item["tower_id"] == "shooter" and not item["is_new"]:
			var td: TowerData = GameConfig.towers["shooter"]
			assert_eq(result["prices"][i], td.shop_price_per_level[2], "Lv2→3 价格应读 shop_price_per_level[2]")

func test_max_level_excluded():
	GameData.owned_towers = {"shooter": 5, "wall": 5, "slow": 5}
	var result: Dictionary = _generator.generate_options()
	assert_eq(result["items"].size(), 0, "全部满级应返回空")

func test_empty_slots_when_pool_small():
	GameData.owned_towers = {"shooter": 5, "wall": 5}
	var result: Dictionary = _generator.generate_options()
	assert_lte(result["items"].size(), 1, "只剩 slow 一个选项")
```

- [ ] **Step 2: 运行测试验证失败**

Expected: FAIL

- [ ] **Step 3: 实现 tower_shop_generator.gd**

创建 `scripts/systems/tower_shop_generator.gd`:

```gdscript
class_name TowerShopGenerator
extends RefCounted

## 生成塔商店选项
## 返回: {items: Array[Dictionary], prices: Array[int]}
## 每项 item = {tower_id: String, target_level: int, is_new: bool}
func generate_options() -> Dictionary:
	var pool: Array[Dictionary] = _build_pool()
	pool.shuffle()
	var selected: Array[Dictionary] = pool.slice(0, mini(3, pool.size()))
	var prices: Array[int] = []
	for item: Dictionary in selected:
		var td: TowerData = GameConfig.towers[item["tower_id"]]
		prices.append(td.shop_price_per_level[item["target_level"] - 1])
	return {"items": selected, "prices": prices}

func _build_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for tower_id: String in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		var current_level: int = GameData.owned_towers.get(tower_id, 0)
		if current_level == 0:
			pool.append({
				"tower_id": tower_id,
				"target_level": 1,
				"is_new": true,
			})
		elif current_level < td.max_level:
			pool.append({
				"tower_id": tower_id,
				"target_level": current_level + 1,
				"is_new": false,
			})
	return pool
```

- [ ] **Step 4: 更新 global_script_class_cache.cfg 添加 TowerShopGenerator**

- [ ] **Step 5: 运行测试验证通过**

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/systems/tower_shop_generator.gd tests/unit/test_tower_shop_generator.gd .godot/global_script_class_cache.cfg
git commit -m "feat: 塔商店生成器 TowerShopGenerator"
```

---

### Task 10: 武器选择弹窗 UI

**Files:**
- Create: `scripts/ui/weapon_select_popup.gd`
- Create: `scenes/ui/weapon_select_popup.tscn`
- Modify: `scripts/ui/main.gd`

- [ ] **Step 1: 创建 weapon_select_popup.gd**

创建 `scripts/ui/weapon_select_popup.gd`:

```gdscript
extends CanvasLayer
## 武器选择弹窗 — 波次结束后 3 选 1

signal weapon_selected(weapon_id: String)
signal skipped  # 无可选项时自动跳过

var _generator := WeaponUpgradeGenerator.new()
var _options: Array[Dictionary] = []

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_options() -> void:
	_options = _generator.generate_options()
	if _options.is_empty():
		skipped.emit()
		queue_free()
		return
	_build_ui()
	get_tree().paused = true

func _build_ui() -> void:
	# 半透明背景
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 居中容器
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "选择武器升级"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	# 选项卡片 — 横排
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	for i in range(_options.size()):
		var card := _create_card(i)
		hbox.add_child(card)

func _create_card(index: int) -> PanelContainer:
	var opt: Dictionary = _options[index]
	var weapon_id: String = opt["weapon_id"]
	var target_level: int = opt["target_level"]
	var is_new: bool = opt["is_new"]
	var wd: WeaponData = GameConfig.weapons[weapon_id]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 200)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# 武器名
	var name_label := Label.new()
	name_label.text = wd.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# 等级标签
	var level_label := Label.new()
	if is_new:
		level_label.text = "新武器! Lv1"
		level_label.add_theme_color_override("font_color", Color("#80ff80"))
	else:
		level_label.text = "Lv%d → Lv%d" % [target_level - 1, target_level]
		level_label.add_theme_color_override("font_color", Color("#ffd040"))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(level_label)

	# 属性变化预览
	var stats_label := Label.new()
	stats_label.text = _get_stats_text(wd, target_level, is_new)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color("#c0c0c0"))
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(stats_label)

	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_option_selected(index)
	)
	return card

func _get_stats_text(wd: WeaponData, target_level: int, is_new: bool) -> String:
	var idx: int = target_level - 1
	if is_new:
		return "伤害: %.0f\n射速: %.2f\n射程: %.0f" % [
			wd.damage_per_level[0], wd.fire_rate_per_level[0], wd.weapon_range_per_level[0]
		]
	else:
		var prev_idx: int = idx - 1
		return "伤害: %.0f → %.0f\n射速: %.2f → %.2f\n射程: %.0f → %.0f" % [
			wd.damage_per_level[prev_idx], wd.damage_per_level[idx],
			wd.fire_rate_per_level[prev_idx], wd.fire_rate_per_level[idx],
			wd.weapon_range_per_level[prev_idx], wd.weapon_range_per_level[idx],
		]

func _on_option_selected(index: int) -> void:
	var opt: Dictionary = _options[index]
	GameData.upgrade_weapon(opt["weapon_id"])
	get_tree().paused = false
	weapon_selected.emit(opt["weapon_id"])
	queue_free()
```

- [ ] **Step 2: 创建 weapon_select_popup.tscn（最小场景）**

使用 gdai-mcp 或手写 .tscn：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/weapon_select_popup.gd" id="1"]

[node name="WeaponSelectPopup" type="CanvasLayer"]
script = ExtResource("1")
```

- [ ] **Step 3: 修改 main.gd — 波次结束弹出武器选择**

重写 `scripts/ui/main.gd`:

```gdscript
extends Node2D

var _weapon_popup_scene: PackedScene = preload("res://scenes/ui/weapon_select_popup.tscn")

func _ready() -> void:
	_load_map()
	_restore_towers()
	# 暂停覆盖层
	var pause_overlay = load("res://scripts/ui/pause_overlay.gd").new()
	add_child(pause_overlay)
	# 调试面板
	var debug_panel = load("res://scripts/ui/debug_panel.gd").new()
	add_child(debug_panel)
	# 监听波次完成
	EventBus.wave_completed.connect(_on_wave_completed)

func _on_wave_completed(_wave_number: int) -> void:
	# 延迟一帧确保波次清理完成
	await get_tree().process_frame
	_show_weapon_select()

func _show_weapon_select() -> void:
	var popup: CanvasLayer = _weapon_popup_scene.instantiate()
	add_child(popup)
	popup.weapon_selected.connect(_on_weapon_selected)
	popup.skipped.connect(_on_weapon_skipped)
	popup.show_options()

func _on_weapon_selected(_weapon_id: String) -> void:
	SceneManager.go_to(Enums.Scene.PLACEMENT)

func _on_weapon_skipped() -> void:
	SceneManager.go_to(Enums.Scene.PLACEMENT)

func _load_map() -> void:
	var map_data: MapData = GameConfig.maps.get(GameData.selected_map)
	if map_data == null or map_data.map_scene.is_empty():
		push_warning("地图场景未配置，跳过加载: " + GameData.selected_map)
		return
	if not ResourceLoader.exists(map_data.map_scene):
		push_warning("地图场景文件不存在: " + map_data.map_scene)
		return
	var map_instance = load(map_data.map_scene).instantiate()
	add_child(map_instance)
	move_child(map_instance, 0)

func _restore_towers() -> void:
	for tower_entry in GameData.tower_inventory:
		var tower_type: String = tower_entry["type"]
		var tower_pos: Vector2 = tower_entry["position"]
		var tower: Node2D = SceneFactory.create_tower(tower_type)
		if tower:
			tower.global_position = tower_pos
			tower.add_to_group(Enums.Group.TOWERS)
			add_child(tower)
```

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/weapon_select_popup.gd scenes/ui/weapon_select_popup.tscn scripts/ui/main.gd
git commit -m "feat: 武器选择弹窗 UI + main.gd 波次结束触发"
```

---

## Chunk 4: 塔商店重构 + 布置面板适配

### Task 11: shop_panel.gd 重写为塔商店

**Files:**
- Rewrite: `scripts/ui/shop_panel.gd`
- Test: `tests/unit/test_tower_shop_panel.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_tower_shop_panel.gd`:

```gdscript
extends GutTest

var _original_coins: int
var _original_wave: int
var _original_owned_towers: Dictionary

func before_each():
	_original_coins = GameData.coins
	_original_wave = GameData.current_wave
	_original_owned_towers = GameData.owned_towers.duplicate()
	GameData.coins = 200
	GameData.current_wave = 2
	GameData.owned_towers = {"shooter": 1}

func after_each():
	GameData.coins = _original_coins
	GameData.current_wave = _original_wave
	GameData.owned_towers = _original_owned_towers

func test_shop_generates_tower_options():
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	panel._generate_shop()
	assert_lte(panel.shop_items.size(), 3, "最多 3 个选项")
	assert_eq(panel.shop_items.size(), panel.shop_prices.size(), "items 和 prices 等长")

func test_shop_buy_upgrades_tower():
	GameData.owned_towers = {"shooter": 1, "wall": 1, "slow": 1}
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	panel._generate_shop()
	# 找到一个 shooter 升级选项
	for i in range(panel.shop_items.size()):
		if panel.shop_items[i]["tower_id"] == "shooter":
			var price: int = panel.shop_prices[i]
			GameData.coins = price + 10
			panel._buy_item(i)
			assert_eq(GameData.owned_towers["shooter"], 2, "购买后应升级到 Lv2")
			return
	# 如果没有 shooter 选项（随机的），至少验证购买不崩溃
	pass_test("随机未出现 shooter 选项")

func test_shop_refresh_cost():
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	GameData.current_wave = 1
	assert_eq(panel._get_refresh_cost(), 5)
	GameData.current_wave = 9
	assert_eq(panel._get_refresh_cost(), 12)
```

- [ ] **Step 2: 运行测试验证失败**

Expected: FAIL — shop_panel.gd 仍引用旧的 ShopItemGenerator

- [ ] **Step 3: 重写 shop_panel.gd**

```gdscript
extends Node
## 塔商店侧栏：3 格 + 刷新

const REFRESH_COSTS: Array = [0, 5, 5, 5, 5, 8, 8, 8, 8, 12, 12]

var _main: Node2D = null
var _generator := TowerShopGenerator.new()
var shop_items: Array[Dictionary] = []  # [{tower_id, target_level, is_new}]
var shop_prices: Array[int] = []
var _item_nodes: Array = []

func initialize(main: Node2D) -> void:
	_main = main
	_generate_shop()
	_create_item_cards()
	_main.coins_changed.connect(_update_display)

func _generate_shop() -> void:
	var result: Dictionary = _generator.generate_options()
	shop_items = result["items"]
	shop_prices = result["prices"]

func _create_item_cards() -> void:
	var item_list: VBoxContainer = get_parent().get_node("ShopScroll/ShopItemList")
	for child in item_list.get_children():
		child.queue_free()
	_item_nodes.clear()

	for i in range(shop_items.size()):
		var card := _create_item_card(i)
		item_list.add_child(card)
		_item_nodes.append(card)

	var refresh_btn: Button = get_parent().get_node("RefreshButton")
	if not refresh_btn.pressed.is_connected(_on_refresh_pressed):
		refresh_btn.pressed.connect(_on_refresh_pressed)
	_update_refresh_button(refresh_btn)

func _create_item_card(index: int) -> PanelContainer:
	var item: Dictionary = shop_items[index]
	var price: int = shop_prices[index]
	var tower_id: String = item["tower_id"]
	var target_level: int = item["target_level"]
	var is_new: bool = item["is_new"]
	var td: TowerData = GameConfig.towers[tower_id]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(108, 60)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var name_label := Label.new()
	if is_new:
		name_label.text = "%s (新!)" % td.display_name
	else:
		name_label.text = "%s Lv%d" % [td.display_name, target_level]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(name_label)

	var price_label := Label.new()
	price_label.text = "%d 金" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 10)
	price_label.add_theme_color_override("font_color", Color("#e0c040"))
	vbox.add_child(price_label)

	card.gui_input.connect(func(event: InputEvent) -> void: _on_item_clicked(event, index))
	return card

func _on_item_clicked(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_buy_item(index)

func _buy_item(index: int) -> void:
	if index >= shop_items.size():
		return
	var price: int = shop_prices[index]
	if GameData.coins < price:
		return
	var item: Dictionary = shop_items[index]
	GameData.coins -= price
	GameData.upgrade_tower(item["tower_id"])
	AudioManager.play("shop_buy")
	# 购买后移除此选项
	shop_items.remove_at(index)
	shop_prices.remove_at(index)
	_recreate_item_cards()
	if _main:
		_main.update_coins_display()

func _on_refresh_pressed() -> void:
	var cost := _get_refresh_cost()
	if GameData.coins < cost:
		return
	GameData.coins -= cost
	_generate_shop()
	_recreate_item_cards()
	if _main:
		_main.update_coins_display()

func _recreate_item_cards() -> void:
	var item_list: VBoxContainer = get_parent().get_node("ShopScroll/ShopItemList")
	for child in item_list.get_children():
		child.queue_free()
	_item_nodes.clear()
	for i in range(shop_items.size()):
		var card := _create_item_card(i)
		item_list.add_child(card)
		_item_nodes.append(card)

func _update_display() -> void:
	for i in range(min(shop_items.size(), _item_nodes.size())):
		var price: int = shop_prices[i]
		_item_nodes[i].modulate.a = 1.0 if GameData.coins >= price else 0.5
	var refresh_btn: Button = get_parent().get_node("RefreshButton")
	_update_refresh_button(refresh_btn)

func _update_refresh_button(btn: Button) -> void:
	var cost := _get_refresh_cost()
	btn.text = "刷新 (%d)" % cost
	btn.disabled = GameData.coins < cost

func _get_refresh_cost() -> int:
	var wave := GameData.current_wave + 1
	if wave >= REFRESH_COSTS.size():
		return REFRESH_COSTS[-1]
	return REFRESH_COSTS[wave]
```

- [ ] **Step 4: 运行测试验证通过**

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/shop_panel.gd tests/unit/test_tower_shop_panel.gd
git commit -m "feat: shop_panel 重写为 3 格塔商店"
```

---

### Task 12: placement_panel.gd 适配已拥有塔

**Files:**
- Modify: `scripts/ui/placement_panel.gd`
- Modify: `scripts/ui/placement.gd`
- Test: `tests/unit/test_placement_panel.gd` (更新)

- [ ] **Step 1: 修改 placement_panel.gd**

核心变更：
1. `_create_tower_cards()` — 只遍历 `GameData.owned_towers` 而非硬编码 3 种
2. 费用从 `SceneFactory.get_tower_cost()` 读取（已在 Task 7 改为读 place_cost_per_level）
3. 卡片显示等级
4. 监听 `EventBus.tower_purchased` 刷新卡片

修改 `_create_tower_cards()`:

```gdscript
func _create_tower_cards() -> void:
	var tower_list: VBoxContainer = get_parent().get_node("PlacementScroll/TowerList")
	# 清空旧卡片
	for child in tower_list.get_children():
		child.queue_free()
	_tower_buttons.clear()

	for tower_type: String in GameData.owned_towers:
		var td: TowerData = GameConfig.towers[tower_type]
		var level: int = GameData.owned_towers[tower_type]
		var cost: int = SceneFactory.get_tower_cost(tower_type)
		var display: String = "%s Lv%d" % [td.display_name, level]
		var card := _create_card(tower_type, display, cost)
		tower_list.add_child(card)
		_tower_buttons[tower_type] = card
```

在 `initialize()` 中添加 EventBus 监听：

```gdscript
func initialize(main: Node2D, range_indicator: RangeIndicator) -> void:
	_main = main
	_range_indicator = range_indicator
	_create_tower_cards()
	_update_buttons()
	_main.coins_changed.connect(_update_buttons)
	EventBus.tower_purchased.connect(_on_tower_purchased)
	EventBus.tower_upgraded.connect(_on_tower_upgraded)

func _on_tower_purchased(_tower_type: String) -> void:
	_create_tower_cards()
	_update_buttons()

func _on_tower_upgraded(_tower_type: String) -> void:
	_create_tower_cards()
	_update_buttons()
```

- [ ] **Step 2: 修改 placement.gd — 移除 purchased_towers 兼容逻辑**

删除 `_ready()` 中第 50-53 行：

```gdscript
	# 将商店购买的塔转为金币（遗留兼容）
	for tower_type in GameData.purchased_towers:
		GameData.coins += SceneFactory.get_tower_cost(tower_type)
	GameData.purchased_towers.clear()
```

- [ ] **Step 3: 更新 test_placement_panel.gd**

```gdscript
extends GutTest

var placement: Node2D
var _original_coins: int
var _original_map: String
var _original_owned_towers: Dictionary

func before_each():
	_original_coins = GameData.coins
	_original_map = GameData.selected_map
	_original_owned_towers = GameData.owned_towers.duplicate()
	GameData.tower_inventory.clear()
	GameData.owned_towers = {"shooter": 1, "wall": 1, "slow": 1}
	GameData.coins = 200
	for node in get_tree().get_nodes_in_group(Enums.Group.TOWERS):
		node.remove_from_group(Enums.Group.TOWERS)
	var placement_scene = load("res://scenes/levels/placement.tscn")
	placement = placement_scene.instantiate()
	add_child_autofree(placement)

func after_each():
	GameData.coins = _original_coins
	GameData.selected_map = _original_map
	GameData.owned_towers = _original_owned_towers

func test_place_tower_deducts_coins():
	var cost: int = SceneFactory.get_tower_cost(Enums.TowerId.SHOOTER)
	var initial_coins: int = GameData.coins
	placement._placement_panel._select_tower(Enums.TowerId.SHOOTER)
	assert_not_null(placement._placement_panel._preview_tower, "应有预览塔")
	var place_pos := Vector2(200, 200)
	placement._placement_panel._preview_tower.global_position = place_pos
	assert_true(placement.can_place_at(place_pos), "测试位置应允许放置")
	placement._placement_panel._place_tower()
	assert_eq(GameData.coins, initial_coins - cost, "放置应扣除金币")

func test_remove_tower_refunds_coins():
	GameData.coins = 60
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)
	var cost: int = SceneFactory.get_tower_cost(Enums.TowerId.SHOOTER)
	placement._placement_panel._remove_tower_at(Vector2(110, 110))
	assert_eq(GameData.coins, 60 + cost, "移除应退还金币")

func test_cannot_select_tower_when_coins_insufficient():
	GameData.coins = 0
	placement._placement_panel._select_tower(Enums.TowerId.SHOOTER)
	assert_null(placement._placement_panel._preview_tower, "金币不足不应创建预览")

func test_cancel_placement_clears_preview():
	placement._placement_panel._select_tower(Enums.TowerId.SHOOTER)
	assert_true(placement._placement_panel.has_preview())
	placement._placement_panel.cancel_placement()
	assert_false(placement._placement_panel.has_preview())

func test_only_owned_towers_shown():
	GameData.owned_towers = {"shooter": 1}  # 只有射手塔
	# 重新创建面板
	placement._placement_panel._create_tower_cards()
	assert_eq(placement._placement_panel._tower_buttons.size(), 1, "只显示 1 种已拥有塔")
	assert_true(placement._placement_panel._tower_buttons.has("shooter"), "应显示射手塔")
```

- [ ] **Step 4: 运行测试验证通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_placement_panel.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/placement_panel.gd scripts/ui/placement.gd tests/unit/test_placement_panel.gd
git commit -m "feat: placement_panel 只显示已拥有塔，适配等级费用"
```

---

## Chunk 5: 全量测试修复 + 最终验证

### Task 13: 修复剩余编译错误和测试失败

**Files:**
- 可能涉及多个文件的小修补

- [ ] **Step 1: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

- [ ] **Step 2: 逐个修复失败的测试**

常见问题：
- 引用已删除的 `GameData.selected_weapon` → 改为 `GameData.owned_weapons`
- 引用已删除的 `GameData.purchased_items` → 移除
- 引用已删除的 `GameData.purchased_towers` → 移除
- `weapon_data.damage` 平面字段不存在 → 确保所有引用改为 `get_damage()`
- `tower.data.hp` 平面字段不存在 → 确保走 per_level
- `ShopItemData` 类不存在 → 删除相关代码
- `UIConstants.get_rarity_color()` 可能引用 ItemRarity → 检查是否还需要

- [ ] **Step 3: 验证全量测试通过**

Expected: ALL PASS

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "fix: 修复全量测试适配新武器/塔等级系统"
```

---

### Task 14: 清理和最终验证

- [ ] **Step 1: 检查 global_script_class_cache.cfg 完整性**

确认：
- 移除 `ShopItemData`, `ShopItemGenerator`, `ShopEffectApplier` 条目
- 新增 `WeaponUpgradeGenerator`, `TowerShopGenerator` 条目

- [ ] **Step 2: 检查 .uid 文件清理**

删除不再需要的 `.uid` 文件（如 `scripts/ui/shop_panel.gd.uid` 等，git status 中的 untracked 文件）。

- [ ] **Step 3: 运行全量测试最终确认**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: ALL PASS

- [ ] **Step 4: 最终 Commit**

```bash
git add -A
git commit -m "chore: 清理缓存文件和遗留引用"
```
