# 商店成长系统重设计 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将商店从简单随机升级改造为标签协同双轨成长系统，实现25个物品、4角色亲和、稀有度解锁、锁定机制。

**Architecture:** 新增 `ShopItemData` Resource 定义物品（标签/稀有度/效果），`CharacterData` 增加 `affinity_tags`，`ShopManager` 按波次概率表生成稀有度并应用亲和折扣，物品效果通过 `GameData.player_stats` 和 EventBus 接入战斗系统。

**Tech Stack:** GDScript 4.x, Godot 4.6, GUT 测试框架（`/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`）

**角色映射（复用现有 ID）：**
- `warrior` → 战士（射手亲和，击杀回复HP）
- `ranger` → 幽灵（强射手亲和，移速+20% / 最大HP-20%）
- `tank` → 指挥官（射手+工程双亲和，无特殊被动）
- `engineer`（新增）→ 工程师（工程亲和，初始免费塔）

---

## Phase 1：数据基础

### Task 1：扩展 Enums（新增 ItemTag、ItemRarity）

**Files:**
- Modify: `scripts/core/enums.gd`

**Step 1: 在 enums.gd 末尾追加**

```gdscript
# 物品标签
class ItemTag:
	const SHOOTER  = "shooter"   # 射手
	const ENGINEER = "engineer"  # 工程
	const UNIVERSAL = "universal" # 通用

# 物品稀有度
class ItemRarity:
	const COMMON = "common"
	const RARE   = "rare"
	const EPIC   = "epic"

# 物品效果类型
class ItemEffect:
	const STAT_BOOST    = "stat_boost"     # 修改 player_stats
	const TOWER_STAT    = "tower_stat"     # 修改塔属性倍率（存 player_stats）
	const CONSUMABLE    = "consumable"     # 一次性效果
	const PIERCE        = "pierce"         # 穿甲弹：子弹穿透
	const MULTISHOT     = "multishot"      # 弹幕：多发
	const KILL_STACK    = "kill_stack"     # 蓄力：击杀叠层
	const LIFESTEAL     = "lifesteal"      # 吸血
	const TOWER_LINK    = "tower_link"     # 联动系统
	const WAVE_GOLD     = "wave_gold"      # 金矿：波次结束给金币
	const WAVE_HEAL_TOWERS = "wave_heal_towers"  # 战场维修
	const TOWER_REGEN   = "tower_regen"    # 纳米修复
	const SYMBIOSIS     = "symbiosis"      # 共生
	const WAR_MACHINE   = "war_machine"    # 战争机器
	const DESTINY       = "destiny"        # 天命
```

**Step 2: 运行测试确保无回归**

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -5
```
期望：All tests passed

**Step 3: Commit**

```bash
git add scripts/core/enums.gd
git commit -m "feat: 新增 ItemTag/ItemRarity/ItemEffect Enums"
```

---

### Task 2：ShopItemData Resource 类定义 + 测试

**Files:**
- Create: `scripts/resources/shop_item_data.gd`
- Create: `tests/unit/test_shop_item_data.gd`

**Step 1: 写失败测试**

```gdscript
# tests/unit/test_shop_item_data.gd
extends GutTest

func test_shop_item_data_has_required_fields():
	var item := ShopItemData.new()
	assert_has(item, "id")
	assert_has(item, "display_name")
	assert_has(item, "tags")
	assert_has(item, "rarity")
	assert_has(item, "effect_type")
	assert_has(item, "effect_params")
	assert_has(item, "cost_min")
	assert_has(item, "cost_max")
	assert_has(item, "max_stack")

func test_shop_item_default_values():
	var item := ShopItemData.new()
	assert_eq(item.rarity, Enums.ItemRarity.COMMON)
	assert_eq(item.max_stack, 1)
	assert_gt(item.cost_max, 0)
```

**Step 2: 运行测试，期望 FAIL（类未定义）**

**Step 3: 创建 ShopItemData**

```gdscript
# scripts/resources/shop_item_data.gd
class_name ShopItemData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
## 标签数组，对应 Enums.ItemTag 常量
@export var tags: PackedStringArray = PackedStringArray()
@export var rarity: String = Enums.ItemRarity.COMMON
## 效果类型，对应 Enums.ItemEffect 常量
@export var effect_type: String = Enums.ItemEffect.STAT_BOOST
## 效果参数，key 由 effect_type 决定
## stat_boost: {"stat": Enums.Stat.X, "value": float}
## consumable:  {"effect": "heal", "value": int}
## pierce/multishot/lifesteal/kill_stack 等：自定义 key
@export var effect_params: Dictionary = {}
@export var cost_min: int = 20
@export var cost_max: int = 35
## 同一物品最多可购买次数（-1 = 无限，1 = 只能买一次）
@export var max_stack: int = 1
```

**Step 4: 运行测试，期望 PASS**

**Step 5: Commit**

```bash
git add scripts/resources/shop_item_data.gd tests/unit/test_shop_item_data.gd
git commit -m "feat: 新增 ShopItemData Resource 类"
```

---

### Task 3：创建25个物品的 .tres 配置文件

**Files:**
- Create: `resources/items/` 目录下25个 `.tres` 文件

**Step 1: 创建目录并批量创建射手普通物品（6个）**

`resources/items/shooter_sharpbullet.tres`（锋利弹头）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "sharp_bullet"
display_name = "锋利弹头"
tags = PackedStringArray("shooter")
rarity = "common"
effect_type = "stat_boost"
effect_params = {"stat": "damage_mult", "value": 0.15}
cost_min = 20
cost_max = 30
max_stack = 3
```

`resources/items/shooter_quickhand.tres`（快手）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "quick_hand"
display_name = "快手"
tags = PackedStringArray("shooter")
rarity = "common"
effect_type = "stat_boost"
effect_params = {"stat": "attack_speed_mult", "value": 0.20}
cost_min = 20
cost_max = 30
max_stack = 3
```

`resources/items/shooter_lightarmor.tres`（轻甲）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "light_armor"
display_name = "轻甲"
tags = PackedStringArray("shooter")
rarity = "common"
effect_type = "stat_boost"
effect_params = {"stat": "move_speed_mult", "value": 0.15}
cost_min = 18
cost_max = 28
max_stack = 3
```

`resources/items/shooter_ironwill.tres`（钢铁意志）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "iron_will"
display_name = "钢铁意志"
tags = PackedStringArray("shooter")
rarity = "common"
effect_type = "stat_boost"
effect_params = {"stat": "hp_mult", "value": 0.25}
cost_min = 20
cost_max = 30
max_stack = 3
```

`resources/items/shooter_medkit.tres`（急救包）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "medkit"
display_name = "急救包"
tags = PackedStringArray("shooter")
rarity = "common"
effect_type = "consumable"
effect_params = {"effect": "heal", "value": 50}
cost_min = 12
cost_max = 18
max_stack = -1
```

`resources/items/shooter_piercing.tres`（穿甲弹）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "piercing_bullet"
display_name = "穿甲弹"
tags = PackedStringArray("shooter")
rarity = "common"
effect_type = "pierce"
effect_params = {"pierce_count": 1}
cost_min = 25
cost_max = 35
max_stack = 2
```

**Step 2: 创建射手稀有物品（3个）**

`resources/items/shooter_chargeup.tres`（蓄力）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "charge_up"
display_name = "蓄力"
tags = PackedStringArray("shooter")
rarity = "rare"
effect_type = "kill_stack"
effect_params = {"damage_per_stack": 0.20, "max_stacks": 3}
cost_min = 40
cost_max = 55
max_stack = 1
```

`resources/items/shooter_lifesteal.tres`（吸血）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "lifesteal"
display_name = "吸血"
tags = PackedStringArray("shooter")
rarity = "rare"
effect_type = "lifesteal"
effect_params = {"ratio": 0.05}
cost_min = 45
cost_max = 60
max_stack = 1
```

`resources/items/shooter_barrage.tres`（弹幕）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "barrage"
display_name = "弹幕"
tags = PackedStringArray("shooter")
rarity = "rare"
effect_type = "multishot"
effect_params = {"count": 3, "damage_mult": 0.75}
cost_min = 45
cost_max = 60
max_stack = 1
```

**Step 3: 创建射手史诗物品（1个）**

`resources/items/shooter_bulletrain.tres`（弹雨）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "bullet_rain"
display_name = "弹雨"
tags = PackedStringArray("shooter")
rarity = "epic"
effect_type = "stat_boost"
effect_params = {"stats": [{"stat": "attack_speed_mult", "value": 0.50}, {"stat": "damage_mult", "value": 0.30}]}
cost_min = 70
cost_max = 90
max_stack = 1
```

**Step 4: 创建工程普通物品（6个）**

`resources/items/engineer_reinforce.tres`（强化底座）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "reinforce_base"
display_name = "强化底座"
tags = PackedStringArray("engineer")
rarity = "common"
effect_type = "tower_stat"
effect_params = {"stat": "tower_hp_mult", "value": 0.30}
cost_min = 20
cost_max = 30
max_stack = 3
```

`resources/items/engineer_precision.tres`（精密瞄准）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "precision_aim"
display_name = "精密瞄准"
tags = PackedStringArray("engineer")
rarity = "common"
effect_type = "tower_stat"
effect_params = {"stat": "tower_range_mult", "value": 0.20}
cost_min = 20
cost_max = 30
max_stack = 3
```

`resources/items/engineer_quickbuild.tres`（急造）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "quick_build"
display_name = "急造"
tags = PackedStringArray("engineer")
rarity = "common"
effect_type = "tower_stat"
effect_params = {"stat": "tower_cost_mult", "value": -0.15}
cost_min = 18
cost_max = 28
max_stack = 2
```

`resources/items/engineer_fieldrepair.tres`（战场维修）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "field_repair"
display_name = "战场维修"
tags = PackedStringArray("engineer")
rarity = "common"
effect_type = "wave_heal_towers"
effect_params = {"ratio": 0.20}
cost_min = 22
cost_max = 32
max_stack = 2
```

`resources/items/engineer_accelerator.tres`（加速器）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "accelerator"
display_name = "加速器"
tags = PackedStringArray("engineer")
rarity = "common"
effect_type = "tower_stat"
effect_params = {"stat": "tower_attack_speed_mult", "value": 0.20}
cost_min = 20
cost_max = 30
max_stack = 3
```

`resources/items/engineer_manual.tres`（工程手册）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "engineer_manual"
display_name = "工程手册"
tags = PackedStringArray("engineer")
rarity = "common"
effect_type = "tower_stat"
effect_params = {"stat": "tower_mult", "value": 0.15}
cost_min = 20
cost_max = 30
max_stack = 3
```

**Step 5: 创建工程稀有/史诗物品（4个）**

`resources/items/engineer_towerlink.tres`（联动系统）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "tower_link"
display_name = "联动系统"
tags = PackedStringArray("engineer")
rarity = "rare"
effect_type = "tower_link"
effect_params = {"damage_per_tower": 0.04}
cost_min = 40
cost_max = 55
max_stack = 1
```

`resources/items/engineer_overload.tres`（超载）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "overload"
display_name = "超载"
tags = PackedStringArray("engineer")
rarity = "rare"
effect_type = "tower_stat"
effect_params = {"stats": [{"stat": "tower_mult", "value": 0.50}, {"stat": "tower_hp_mult", "value": -0.30}]}
cost_min = 45
cost_max = 60
max_stack = 1
```

`resources/items/engineer_nanoregen.tres`（纳米修复）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "nano_regen"
display_name = "纳米修复"
tags = PackedStringArray("engineer")
rarity = "rare"
effect_type = "tower_regen"
effect_params = {"hp_per_interval": 5, "interval": 5.0}
cost_min = 45
cost_max = 60
max_stack = 1
```

`resources/items/engineer_arsenal.tres`（军工厂）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "arsenal"
display_name = "军工厂"
tags = PackedStringArray("engineer")
rarity = "epic"
effect_type = "tower_stat"
effect_params = {"stats": [{"stat": "tower_mult", "value": 0.30}, {"stat": "tower_hp_mult", "value": 0.30}, {"stat": "tower_range_mult", "value": 0.30}]}
cost_min = 70
cost_max = 90
max_stack = 1
```

**Step 6: 创建通用物品（5个）**

`resources/items/universal_goldmine.tres`（金矿）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "gold_mine"
display_name = "金矿"
tags = PackedStringArray("universal")
rarity = "common"
effect_type = "wave_gold"
effect_params = {"gold": 15}
cost_min = 20
cost_max = 30
max_stack = 3
```

`resources/items/universal_sturdy.tres`（强壮）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "sturdy"
display_name = "强壮"
tags = PackedStringArray("universal")
rarity = "common"
effect_type = "tower_stat"
effect_params = {"stats": [{"stat": "hp_mult", "value": 0.15}, {"stat": "tower_hp_mult", "value": 0.15}]}
cost_min = 22
cost_max = 32
max_stack = 2
```

`resources/items/universal_symbiosis.tres`（共生）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "symbiosis"
display_name = "共生"
tags = PackedStringArray("universal")
rarity = "rare"
effect_type = "symbiosis"
effect_params = {"hp_threshold": 0.30, "tower_damage_bonus": 0.60}
cost_min = 40
cost_max = 55
max_stack = 1
```

`resources/items/universal_warmachine.tres`（战争机器）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "war_machine"
display_name = "战争机器"
tags = PackedStringArray("universal")
rarity = "rare"
effect_type = "war_machine"
effect_params = {"damage_mult": 0.20, "tower_mult": 0.20, "wave_hp_cost": 8}
cost_min = 45
cost_max = 60
max_stack = 1
```

`resources/items/universal_destiny.tres`（天命）:
```
[gd_resource type="Resource" script_class="ShopItemData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_item_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "destiny"
display_name = "天命"
tags = PackedStringArray("universal")
rarity = "epic"
effect_type = "destiny"
effect_params = {"bonus_rare_count": 2}
cost_min = 60
cost_max = 80
max_stack = 1
```

**Step 7: 运行测试确认无回归，然后 commit**

```bash
git add resources/items/
git commit -m "feat: 新增25个商店物品配置文件"
```

---

### Task 4：GameConfig 加载物品池，CharacterData 增加亲和字段

**Files:**
- Modify: `scripts/core/game_config.gd`
- Modify: `scripts/resources/character_data.gd`
- Modify: `resources/characters/warrior.tres`
- Modify: `resources/characters/ranger.tres`
- Modify: `resources/characters/tank.tres`
- Create: `resources/characters/engineer.tres`
- Create: `tests/unit/test_shop_items_loaded.gd`

**Step 1: 修改 CharacterData，新增亲和字段**

在 `scripts/resources/character_data.gd` 末尾添加：

```gdscript
## 亲和标签数组（对应 Enums.ItemTag 常量）
@export var affinity_tags: PackedStringArray = PackedStringArray()
## 亲和折扣倍率（0.15 = 亲和物品降价15%）
@export var affinity_discount: float = 0.15
## 角色特色被动描述（展示用）
@export var passive_description: String = ""
```

**Step 2: 更新三个现有角色的 .tres，追加新字段**

`resources/characters/warrior.tres` 追加：
```
affinity_tags = PackedStringArray("shooter")
affinity_discount = 0.15
passive_description = "击杀敌人回复3HP"
```

`resources/characters/ranger.tres` 追加：
```
affinity_tags = PackedStringArray("shooter")
affinity_discount = 0.25
passive_description = "移速+20%，最大HP-20%"
```

`resources/characters/tank.tres` 追加：
```
affinity_tags = PackedStringArray("shooter", "engineer")
affinity_discount = 0.15
passive_description = "无特殊被动"
```

**Step 3: 创建工程师角色配置**

`resources/characters/engineer.tres`（需先确认 warrior.tres 的完整格式再照抄头部）:
```
[gd_resource type="Resource" script_class="CharacterData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/character_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = "engineer"
display_name = "工程师"
description = "擅长塔防布局，初始携带免费塔"
max_hp = 100.0
speed = 180.0
damage_mult = 1.0
attack_speed_mult = 1.0
move_speed_mult = 1.0
hp_regen = 0.0
default_weapon = "rifle"
affinity_tags = PackedStringArray("engineer")
affinity_discount = 0.15
passive_description = "每局初始携带1座免费射击塔"
```

同时在 `scripts/core/enums.gd` 的 `Character` 类中添加：
```gdscript
const ENGINEER = "engineer"
```

**Step 4: GameConfig 增加物品池加载**

在 `scripts/core/game_config.gd` 中：

变量声明区添加：
```gdscript
var items: Dictionary = {}  # ShopItemData 注册表
```

`_ready()` 中添加：
```gdscript
_load_resources_from_dir("res://resources/items/", items)
```

**Step 5: 写加载测试**

```gdscript
# tests/unit/test_shop_items_loaded.gd
extends GutTest

func test_items_are_loaded():
	assert_eq(GameConfig.items.size(), 25, "应加载25个物品")

func test_shooter_common_items_exist():
	assert_true(GameConfig.items.has("sharp_bullet"))
	assert_true(GameConfig.items.has("quick_hand"))
	assert_true(GameConfig.items.has("piercing_bullet"))

func test_engineer_rare_items_exist():
	assert_true(GameConfig.items.has("tower_link"))
	assert_true(GameConfig.items.has("overload"))

func test_epic_items_exist():
	assert_true(GameConfig.items.has("bullet_rain"))
	assert_true(GameConfig.items.has("arsenal"))
	assert_true(GameConfig.items.has("destiny"))

func test_engineer_character_loaded():
	assert_true(GameConfig.characters.has("engineer"))
	var eng: CharacterData = GameConfig.characters["engineer"]
	assert_true(eng.affinity_tags.has("engineer"))

func test_warrior_has_affinity():
	var w: CharacterData = GameConfig.characters["warrior"]
	assert_true(w.affinity_tags.has("shooter"))

func test_ranger_has_strong_discount():
	var r: CharacterData = GameConfig.characters["ranger"]
	assert_eq(r.affinity_discount, 0.25)
```

**Step 6: 运行测试，期望 PASS**

**Step 7: Commit**

```bash
git add scripts/core/game_config.gd scripts/resources/character_data.gd \
        scripts/core/enums.gd resources/characters/ \
        tests/unit/test_shop_items_loaded.gd
git commit -m "feat: CharacterData 亲和字段，GameConfig 加载物品池，新增工程师角色"
```

---

## Phase 2：商店逻辑与 UI

### Task 5：新增 GameData 商店状态字段

**Files:**
- Modify: `scripts/core/game_data.gd`

**Step 1: 在 game_data.gd 变量区添加**

```gdscript
## 本局已购买的物品 id → 购买次数
var purchased_items: Dictionary = {}
## 本局可用的金矿加成（每波额外金币）
var wave_gold_bonus: int = 0
## 穿甲弹穿透数（0 = 不穿透）
var pierce_count: int = 0
## 弹幕激活（true = 3发）及伤害倍率
var multishot_active: bool = false
var multishot_damage_mult: float = 1.0
## 吸血比例（0.0 = 未激活）
var lifesteal_ratio: float = 0.0
## 蓄力当前层数
var kill_stack_count: int = 0
var kill_stack_max: int = 0
var kill_stack_damage_per_stack: float = 0.0
## 联动系统：每塔玩家伤害加成
var tower_link_damage_per_tower: float = 0.0
## 战场维修：每波塔HP回复比例
var wave_tower_heal_ratio: float = 0.0
## 纳米修复已激活
var tower_regen_active: bool = false
var tower_regen_hp: float = 0.0
var tower_regen_interval: float = 5.0
## 共生：低血量塔伤害加成
var symbiosis_hp_threshold: float = 0.0
var symbiosis_tower_bonus: float = 0.0
## 战争机器激活
var war_machine_active: bool = false
var war_machine_wave_hp_cost: int = 0
## 额外塔属性倍率（tower_hp_mult, tower_range_mult, tower_attack_speed_mult, tower_cost_mult）
var tower_hp_mult: float = 1.0
var tower_range_mult: float = 1.0
var tower_attack_speed_mult: float = 1.0
var tower_cost_mult: float = 1.0
```

**Step 2: 在 `reset()` 末尾添加新字段的重置**

```gdscript
purchased_items = {}
wave_gold_bonus = 0
pierce_count = 0
multishot_active = false
multishot_damage_mult = 1.0
lifesteal_ratio = 0.0
kill_stack_count = 0
kill_stack_max = 0
kill_stack_damage_per_stack = 0.0
tower_link_damage_per_tower = 0.0
wave_tower_heal_ratio = 0.0
tower_regen_active = false
tower_regen_hp = 0.0
tower_regen_interval = 5.0
symbiosis_hp_threshold = 0.0
symbiosis_tower_bonus = 0.0
war_machine_active = false
war_machine_wave_hp_cost = 0
tower_hp_mult = 1.0
tower_range_mult = 1.0
tower_attack_speed_mult = 1.0
tower_cost_mult = 1.0
```

**Step 3: 运行测试确认无回归**

**Step 4: Commit**

```bash
git add scripts/core/game_data.gd
git commit -m "feat: GameData 新增商店物品效果状态字段"
```

---

### Task 6：重写 ShopManager 核心逻辑

**Files:**
- Modify: `scripts/systems/shop_manager.gd`
- Create: `tests/unit/test_shop_manager_logic.gd`

**Step 1: 写失败测试（先写逻辑测试，不依赖 UI）**

```gdscript
# tests/unit/test_shop_manager_logic.gd
extends GutTest

var manager: Node

func before_each():
	manager = preload("res://scripts/systems/shop_manager.gd").new()
	add_child_autofree(manager)

func test_rarity_weights_early_waves():
	# 波次1-3 只出普通
	var weights := manager._get_rarity_weights(2)
	assert_eq(weights[Enums.ItemRarity.COMMON], 100)
	assert_eq(weights.get(Enums.ItemRarity.RARE, 0), 0)
	assert_eq(weights.get(Enums.ItemRarity.EPIC, 0), 0)

func test_rarity_weights_mid_waves():
	var weights := manager._get_rarity_weights(5)
	assert_gt(weights.get(Enums.ItemRarity.RARE, 0), 0)
	assert_eq(weights.get(Enums.ItemRarity.EPIC, 0), 0)

func test_rarity_weights_final_wave():
	var weights := manager._get_rarity_weights(10)
	assert_gt(weights.get(Enums.ItemRarity.EPIC, 0), 0)

func test_affinity_discount_applied():
	# warrior 有 shooter 亲和，sharp_bullet 是 shooter 标签
	GameData.current_character = "warrior"
	var item: ShopItemData = GameConfig.items["sharp_bullet"]
	var price := manager._calculate_price(item)
	var char_data: CharacterData = GameConfig.characters["warrior"]
	var max_undiscounted := item.cost_max
	assert_lt(price, max_undiscounted)

func test_no_discount_for_non_affinity():
	GameData.current_character = "warrior"
	# engineer_manual 是 engineer 标签，warrior 无工程亲和
	var item: ShopItemData = GameConfig.items["engineer_manual"]
	var price := manager._calculate_price(item)
	# 价格应在 cost_min..cost_max 之间，无折扣
	assert_gte(price, item.cost_min)
	assert_lte(price, item.cost_max)
```

**Step 2: 运行测试，期望 FAIL**

**Step 3: 重写 shop_manager.gd**

```gdscript
extends Control

# 稀有度概率表 {wave_range_start: {rarity: weight}}
const RARITY_TABLE: Array = [
	{"from": 1,  "weights": {"common": 100, "rare": 0,  "epic": 0}},
	{"from": 4,  "weights": {"common": 70,  "rare": 30, "epic": 0}},
	{"from": 7,  "weights": {"common": 40,  "rare": 50, "epic": 10}},
	{"from": 10, "weights": {"common": 20,  "rare": 50, "epic": 30}},
]
const REFRESH_COSTS: Array = [0, 5, 5, 5, 5, 8, 8, 8, 8, 12, 12]  # index = wave

var shop_items: Array[ShopItemData] = []
var shop_prices: Array[int] = []
var locked_slots: Array[bool] = [false, false, false, false]
# max_stack=-1 的物品可以无限购买，其余检查 GameData.purchased_items

@onready var coin_label = $VBoxContainer/CoinLabel
@onready var refresh_button = $VBoxContainer/ButtonsContainer/RefreshButton
@onready var confirm_button = $VBoxContainer/ButtonsContainer/ConfirmButton
@onready var item_containers: Array = [
	$VBoxContainer/ItemsContainer/Item1,
	$VBoxContainer/ItemsContainer/Item2,
	$VBoxContainer/ItemsContainer/Item3,
	$VBoxContainer/ItemsContainer/Item4,
]

func _ready() -> void:
	refresh_button.pressed.connect(_on_refresh_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	for i in range(4):
		_connect_slot_buttons(i)
	_generate_shop()
	_update_ui()

# ===== 公共方法 =====

func _get_rarity_weights(wave: int) -> Dictionary:
	var result: Dictionary = {}
	for entry in RARITY_TABLE:
		if wave >= entry["from"]:
			result = entry["weights"]
	return result

func _pick_rarity(wave: int) -> String:
	var weights := _get_rarity_weights(wave)
	var total: int = 0
	for w in weights.values():
		total += w
	var roll := randi_range(0, total - 1)
	var cumulative := 0
	for rarity in weights:
		cumulative += weights[rarity]
		if roll < cumulative:
			return rarity
	return Enums.ItemRarity.COMMON

func _get_affinity_tags() -> PackedStringArray:
	var char_id := GameData.current_character
	if not GameConfig.characters.has(char_id):
		return PackedStringArray()
	return GameConfig.characters[char_id].affinity_tags

func _get_affinity_discount() -> float:
	var char_id := GameData.current_character
	if not GameConfig.characters.has(char_id):
		return 0.0
	return GameConfig.characters[char_id].affinity_discount

func _calculate_price(item: ShopItemData) -> int:
	var base := randi_range(item.cost_min, item.cost_max)
	var affinity_tags := _get_affinity_tags()
	for tag in item.tags:
		if tag in affinity_tags:
			var discount := _get_affinity_discount()
			return max(1, int(base * (1.0 - discount)))
	return base

func _can_buy(item: ShopItemData) -> bool:
	if item.max_stack == -1:
		return true
	var bought: int = GameData.purchased_items.get(item.id, 0)
	return bought < item.max_stack

func _generate_shop() -> void:
	var wave := GameData.current_wave + 1  # 当前是第几波后的商店
	var affinity_tags := _get_affinity_tags()

	# 按稀有度分桶
	var by_rarity: Dictionary = {
		Enums.ItemRarity.COMMON: [],
		Enums.ItemRarity.RARE: [],
		Enums.ItemRarity.EPIC: [],
	}
	for item in GameConfig.items.values():
		by_rarity[item.rarity].append(item)

	for i in range(4):
		if locked_slots[i] and shop_items.size() > i:
			continue  # 锁定槽位跳过
		var rarity := _pick_rarity(wave)
		# 天命只能出现一次
		var pool: Array = by_rarity[rarity].filter(func(it: ShopItemData) -> bool:
			if it.id == "destiny" and GameData.purchased_items.get("destiny", 0) > 0:
				return false
			return _can_buy(it)
		)
		# 亲和标签物品权重加倍（先放两份）
		var weighted_pool: Array = []
		for item in pool:
			weighted_pool.append(item)
			for tag in item.tags:
				if tag in affinity_tags:
					weighted_pool.append(item)
					break

		if weighted_pool.is_empty():
			weighted_pool = pool
		if weighted_pool.is_empty():
			# 降级到普通
			weighted_pool = by_rarity[Enums.ItemRarity.COMMON]

		var picked: ShopItemData = weighted_pool.pick_random()
		if i < shop_items.size():
			shop_items[i] = picked
			shop_prices[i] = _calculate_price(picked)
		else:
			shop_items.append(picked)
			shop_prices.append(_calculate_price(picked))

func _buy_item(index: int) -> void:
	if index >= shop_items.size():
		return
	var item: ShopItemData = shop_items[index]
	var price: int = shop_prices[index]
	if GameData.coins < price:
		return
	if not _can_buy(item):
		return

	GameData.coins -= price
	GameData.purchased_items[item.id] = GameData.purchased_items.get(item.id, 0) + 1

	_apply_item_effect(item)
	_update_ui()

func _apply_item_effect(item: ShopItemData) -> void:
	var p := item.effect_params
	match item.effect_type:
		Enums.ItemEffect.STAT_BOOST:
			if p.has("stat"):
				GameData.player_stats[p["stat"]] += p["value"]
			elif p.has("stats"):
				for entry in p["stats"]:
					GameData.player_stats[entry["stat"]] += entry["value"]
		Enums.ItemEffect.TOWER_STAT:
			_apply_tower_stat(p)
		Enums.ItemEffect.CONSUMABLE:
			if p.get("effect") == "heal":
				GameData.pending_heal += p["value"]
		Enums.ItemEffect.PIERCE:
			GameData.pierce_count += p.get("pierce_count", 1)
		Enums.ItemEffect.MULTISHOT:
			GameData.multishot_active = true
			GameData.multishot_damage_mult = p.get("damage_mult", 1.0)
		Enums.ItemEffect.LIFESTEAL:
			GameData.lifesteal_ratio += p.get("ratio", 0.05)
		Enums.ItemEffect.KILL_STACK:
			GameData.kill_stack_max = max(GameData.kill_stack_max, p.get("max_stacks", 3))
			GameData.kill_stack_damage_per_stack += p.get("damage_per_stack", 0.2)
		Enums.ItemEffect.TOWER_LINK:
			GameData.tower_link_damage_per_tower += p.get("damage_per_tower", 0.04)
		Enums.ItemEffect.WAVE_GOLD:
			GameData.wave_gold_bonus += p.get("gold", 15)
		Enums.ItemEffect.WAVE_HEAL_TOWERS:
			GameData.wave_tower_heal_ratio += p.get("ratio", 0.20)
		Enums.ItemEffect.TOWER_REGEN:
			GameData.tower_regen_active = true
			GameData.tower_regen_hp += p.get("hp_per_interval", 5)
			GameData.tower_regen_interval = p.get("interval", 5.0)
		Enums.ItemEffect.SYMBIOSIS:
			GameData.symbiosis_hp_threshold = max(GameData.symbiosis_hp_threshold, p.get("hp_threshold", 0.30))
			GameData.symbiosis_tower_bonus += p.get("tower_damage_bonus", 0.60)
		Enums.ItemEffect.WAR_MACHINE:
			GameData.player_stats[Enums.Stat.DAMAGE_MULT] += p.get("damage_mult", 0.20)
			GameData.player_stats[Enums.Stat.TOWER_MULT] += p.get("tower_mult", 0.20)
			GameData.war_machine_active = true
			GameData.war_machine_wave_hp_cost += p.get("wave_hp_cost", 8)
		Enums.ItemEffect.DESTINY:
			pass  # 天命效果在 _generate_shop 时特殊处理（额外槽位）

func _apply_tower_stat(p: Dictionary) -> void:
	if p.has("stat"):
		_set_tower_stat(p["stat"], p["value"])
	elif p.has("stats"):
		for entry in p["stats"]:
			_set_tower_stat(entry["stat"], entry["value"])

func _set_tower_stat(stat: String, value: float) -> void:
	match stat:
		"tower_hp_mult":
			GameData.tower_hp_mult += value
		"tower_range_mult":
			GameData.tower_range_mult += value
		"tower_attack_speed_mult":
			GameData.tower_attack_speed_mult += value
		"tower_cost_mult":
			GameData.tower_cost_mult += value
		"tower_mult":
			GameData.player_stats[Enums.Stat.TOWER_MULT] += value
		"hp_mult":
			GameData.player_stats[Enums.Stat.HP_MULT] += value

# ===== UI =====

func _connect_slot_buttons(i: int) -> void:
	# 兼容现有 UI 节点命名
	var suffix := "" if i == 0 else str(i + 1)
	var container := item_containers[i]
	var buy_btn := container.get_node("BuyButton" + suffix) if i > 0 else container.get_node("BuyButton")
	buy_btn.pressed.connect(_buy_item.bind(i))
	# 锁定按钮（Task 7 添加后再连接，此处留空）

func _update_ui() -> void:
	coin_label.text = "金币: %d" % GameData.coins
	var refresh_cost := _get_refresh_cost()
	refresh_button.disabled = GameData.coins < refresh_cost
	refresh_button.text = "刷新 (%d)" % refresh_cost
	_display_items()

func _display_items() -> void:
	for i in range(min(shop_items.size(), 4)):
		var item := shop_items[i]
		var price := shop_prices[i]
		var container := item_containers[i]
		var suffix := "" if i == 0 else str(i + 1)
		container.get_node("NameLabel" + suffix if i > 0 else "NameLabel").text = item.display_name
		container.get_node("PriceLabel" + suffix if i > 0 else "PriceLabel").text = "价格: %d" % price
		var buy_btn := container.get_node("BuyButton" + suffix if i > 0 else "BuyButton")
		buy_btn.disabled = GameData.coins < price or not _can_buy(item)

func _get_refresh_cost() -> int:
	var wave := GameData.current_wave + 1
	if wave >= REFRESH_COSTS.size():
		return REFRESH_COSTS[-1]
	return REFRESH_COSTS[wave]

func _on_refresh_pressed() -> void:
	var cost := _get_refresh_cost()
	if GameData.coins < cost:
		return
	GameData.coins -= cost
	locked_slots = [false, false, false, false]
	_generate_shop()
	_update_ui()

func _on_confirm_pressed() -> void:
	SceneManager.go_to(Enums.Scene.PLACEMENT)
```

**Step 4: 运行测试，期望 PASS**

**Step 5: Commit**

```bash
git add scripts/systems/shop_manager.gd tests/unit/test_shop_manager_logic.gd
git commit -m "feat: 重写 ShopManager，支持稀有度/亲和折扣/锁定机制"
```

---

### Task 7：商店 UI 更新（锁定按钮 + 稀有度边框）

> 注意：此任务需打开 Godot 编辑器修改 shop.tscn 场景，为每个 ItemContainer 添加 LockButton 和调整视觉。这里提供脚本侧接入点，UI 节点由开发者在编辑器中手动添加。

**Files:**
- Modify: `scripts/systems/shop_manager.gd`（添加锁定和视觉逻辑）
- Modify: `scenes/ui/shop.tscn`（在编辑器中添加 LockButton 节点）

**Step 1: 在每个 ItemContainer 下添加 LockButton（编辑器操作）**

- 在 Godot 编辑器打开 `scenes/ui/shop.tscn`
- 每个 Item1~Item4 节点下添加 `Button` 子节点，命名 `LockButton`（Item2~4 对应 `LockButton2`~`LockButton4`）
- 按钮文字：`"🔒"` / `"🔓"`（已锁/未锁），尺寸按现有 BuyButton 对齐

**Step 2: 在 `shop_manager.gd` 中添加锁定逻辑**

在 `_connect_slot_buttons()` 中补充连接（已有注释处）：
```gdscript
func _connect_slot_buttons(i: int) -> void:
	var suffix := "" if i == 0 else str(i + 1)
	var container := item_containers[i]
	var buy_btn := container.get_node("BuyButton" + suffix if i > 0 else "BuyButton")
	buy_btn.pressed.connect(_buy_item.bind(i))
	var lock_btn_name := "LockButton" + suffix if i > 0 else "LockButton"
	if container.has_node(lock_btn_name):
		container.get_node(lock_btn_name).pressed.connect(_toggle_lock.bind(i))
```

添加锁定切换方法：
```gdscript
func _toggle_lock(index: int) -> void:
	locked_slots[index] = not locked_slots[index]
	_update_ui()
```

在 `_display_items()` 中更新锁定按钮状态和稀有度边框色：
```gdscript
func _display_items() -> void:
	for i in range(min(shop_items.size(), 4)):
		var item := shop_items[i]
		var price := shop_prices[i]
		var container := item_containers[i]
		var suffix := "" if i == 0 else str(i + 1)
		container.get_node("NameLabel" + suffix if i > 0 else "NameLabel").text = item.display_name
		container.get_node("PriceLabel" + suffix if i > 0 else "PriceLabel").text = "价格: %d" % price
		var buy_btn := container.get_node("BuyButton" + suffix if i > 0 else "BuyButton")
		buy_btn.disabled = GameData.coins < price or not _can_buy(item)
		# 锁定按钮
		var lock_btn_name := "LockButton" + suffix if i > 0 else "LockButton"
		if container.has_node(lock_btn_name):
			container.get_node(lock_btn_name).text = "🔒" if locked_slots[i] else "🔓"
		# 稀有度边框色（通过 Panel 背景颜色）
		var rarity_color := _get_rarity_color(item.rarity)
		if container is PanelContainer:
			var style := container.get_theme_stylebox("panel").duplicate()
			if style is StyleBoxFlat:
				style.border_color = rarity_color
				container.add_theme_stylebox_override("panel", style)

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		Enums.ItemRarity.RARE:  return Color(0.3, 0.6, 1.0)   # 蓝
		Enums.ItemRarity.EPIC:  return Color(0.7, 0.3, 1.0)   # 紫
		_:                      return Color(0.5, 0.5, 0.5)    # 灰（普通）
```

**Step 3: 亲和物品额外视觉标记**

```gdscript
func _get_affinity_border_color(item: ShopItemData) -> Color:
	var affinity_tags := _get_affinity_tags()
	for tag in item.tags:
		if tag in affinity_tags:
			match tag:
				Enums.ItemTag.SHOOTER:  return Color(0.2, 0.5, 1.0)  # 蓝
				Enums.ItemTag.ENGINEER: return Color(0.2, 0.8, 0.3)  # 绿
	return Color.TRANSPARENT
```

在 `_display_items` 中，如果亲和色非透明则覆盖稀有度边框色。

**Step 4: 运行测试，Commit**

```bash
git add scripts/systems/shop_manager.gd scenes/ui/shop.tscn
git commit -m "feat: 商店 UI 增加锁定按钮和稀有度/亲和边框色"
```

---

## Phase 3：物品效果接入

### Task 8：波次事件钩子（金矿 / 战场维修 / 战争机器HP扣除）

**Files:**
- Modify: `scripts/core/event_bus.gd`（确认 wave_ended 信号存在）
- Modify: `scripts/systems/wave_manager.gd`（在波次结束时 emit）
- Create: `scripts/systems/item_effect_manager.gd`（新节点，响应波次事件）
- Modify: `scenes/levels/main.tscn`（添加 ItemEffectManager 节点）

**Step 1: 确认 EventBus 有 wave_ended 信号，若无则添加**

```gdscript
signal wave_ended(wave_number: int)
```

**Step 2: 创建 ItemEffectManager**

```gdscript
# scripts/systems/item_effect_manager.gd
extends Node

func _ready() -> void:
	EventBus.wave_ended.connect(_on_wave_ended)

func _on_wave_ended(wave_number: int) -> void:
	# 金矿
	if GameData.wave_gold_bonus > 0:
		GameData.coins += GameData.wave_gold_bonus

	# 战场维修
	if GameData.wave_tower_heal_ratio > 0.0:
		var towers := get_tree().get_nodes_in_group(Enums.Group.TOWERS)
		for tower in towers:
			if tower.has_method("heal") or tower.get("health"):
				var max_hp: float = tower.health.max_hp
				tower.health.heal(int(max_hp * GameData.wave_tower_heal_ratio))

	# 战争机器：波次开始扣HP（在 wave_started 更合适，但简化处理在 wave_ended 后下一波开始时）
	if GameData.war_machine_active and GameData.war_machine_wave_hp_cost > 0:
		EventBus.emit_signal("player_take_damage", float(GameData.war_machine_wave_hp_cost))
```

**Step 3: 在 main.tscn 添加 ItemEffectManager 节点（编辑器操作）**

**Step 4: 确认 HealthComponent 有 `heal(amount)` 方法，若无则添加**

```gdscript
func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)
```

**Step 5: 运行测试，确认无回归**

**Step 6: Commit**

```bash
git add scripts/systems/item_effect_manager.gd scripts/core/event_bus.gd \
        scripts/systems/wave_manager.gd scenes/levels/main.tscn
git commit -m "feat: 波次事件驱动金矿/战场维修/战争机器扣HP效果"
```

---

### Task 9：战斗效果接入（穿甲弹 / 弹幕 / 吸血 / 蓄力）

**Files:**
- Modify: `scripts/entities/weapons/bullet_weapon.gd`（或对应基类）
- Modify: `scripts/entities/projectiles/bullet_projectile.gd`
- Modify: `scripts/entities/player.gd`（吸血：伤害回调）
- Modify: `scripts/core/game_data.gd`（击杀计数钩子）

**Step 1: 穿甲弹 — 子弹穿透**

在 `bullet_projectile.gd` 的碰撞处理中：
```gdscript
var _hit_count: int = 0

func _on_hitbox_area_entered(area: Area2D) -> void:
	# 现有伤害逻辑...
	_hit_count += 1
	if _hit_count > GameData.pierce_count:
		queue_free()
	# 若 pierce_count > 0，不销毁，继续穿透
```

**Step 2: 弹幕 — 多发**

在 `bullet_weapon.gd` 的 `fire()` 中：
```gdscript
func fire(target_pos: Vector2) -> void:
	if GameData.multishot_active:
		var angles := [-15.0, 0.0, 15.0]
		for angle_offset in angles:
			var dir := (target_pos - owner_node.global_position).rotated(deg_to_rad(angle_offset)).normalized()
			var proj := SceneFactory.create_bullet_projectile(...)
			proj.setup(damage * GameData.multishot_damage_mult, knockback, owner_node.global_position, dir)
	else:
		# 原有单发逻辑
```

**Step 3: 吸血 — 伤害转HP**

在 `player.gd` 的 `_on_hurtbox_hit()` 或伤害输出回调处（需确认具体信号）。

在玩家子弹命中敌人时（可在 `Hitbox` 信号处）：
```gdscript
func _on_deal_damage(damage: float) -> void:
	if GameData.lifesteal_ratio > 0.0:
		var heal_amount := int(damage * GameData.lifesteal_ratio)
		health.heal(heal_amount)
```

**Step 4: 蓄力 — 击杀叠层**

在敌人死亡时 emit 到 EventBus（确认现有 enemy_died 信号），在 ItemEffectManager 监听：
```gdscript
func _on_enemy_died() -> void:
	if GameData.kill_stack_max > 0:
		GameData.kill_stack_count = min(GameData.kill_stack_count + 1, GameData.kill_stack_max)
```

在武器计算伤害时叠加层数加成：
```gdscript
var total_damage := base_damage * (1.0 + GameData.kill_stack_count * GameData.kill_stack_damage_per_stack)
GameData.kill_stack_count = 0  # 触发后清零
```

**Step 5: 运行测试，Commit**

```bash
git add scripts/entities/weapons/ scripts/entities/projectiles/ scripts/entities/player.gd
git commit -m "feat: 穿甲弹/弹幕/吸血/蓄力战斗效果接入"
```

---

### Task 10：塔效果接入（联动系统 / 纳米修复 / 共生）

**Files:**
- Modify: `scripts/entities/towers/tower.gd`（基类）
- Modify: `scripts/entities/towers/tower_shooter.gd`
- Modify: `scripts/systems/item_effect_manager.gd`

**Step 1: 联动系统 — 玩家伤害随塔数加成**

在 `player.gd` 或 `bullet_weapon.gd` 计算最终伤害时：
```gdscript
func _get_tower_link_bonus() -> float:
	if GameData.tower_link_damage_per_tower <= 0.0:
		return 1.0
	var towers := get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	return 1.0 + towers.size() * GameData.tower_link_damage_per_tower
```

**Step 2: 共生 — 低血量时塔伤害加成**

在 `tower_shooter.gd` 计算攻击伤害时：
```gdscript
func _get_symbiosis_bonus() -> float:
	if GameData.symbiosis_hp_threshold <= 0.0:
		return 1.0
	var player_nodes := get_tree().get_nodes_in_group(Enums.Group.PLAYER)
	if player_nodes.is_empty():
		return 1.0
	var player = player_nodes[0]
	var hp_ratio := player.health.current_hp / player.health.max_hp
	if hp_ratio < GameData.symbiosis_hp_threshold:
		return 1.0 + GameData.symbiosis_tower_bonus
	return 1.0
```

**Step 3: 纳米修复 — 定时塔自愈**

在 `ItemEffectManager._process()` 中：
```gdscript
var _regen_timer: float = 0.0

func _process(delta: float) -> void:
	if not GameData.tower_regen_active:
		return
	_regen_timer += delta
	if _regen_timer >= GameData.tower_regen_interval:
		_regen_timer = 0.0
		var towers := get_tree().get_nodes_in_group(Enums.Group.TOWERS)
		for tower in towers:
			if tower.get("health"):
				tower.health.heal(int(GameData.tower_regen_hp))
```

**Step 4: 运行全部测试**

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -10
```
期望：All tests passed

**Step 5: Commit**

```bash
git add scripts/entities/towers/ scripts/systems/item_effect_manager.gd
git commit -m "feat: 联动系统/共生/纳米修复塔效果接入"
```

---

## 验收标准

1. 商店按波次正确出现稀有/史诗物品
2. 角色亲和物品有折扣且视觉标记正确
3. 锁定槽位后刷新不替换该槽
4. 25个物品购买后效果正确反映到 GameData
5. 金矿波次结算时给金币
6. 全部测试通过（178+ 个）

## 待留后续

- 工程师角色初始免费塔（需在 placement.gd 判断角色并预装一座塔）
- Ranger / 幽灵角色的 HP -20% 被动（在 player.gd `_ready()` 中检查角色 id 应用）
- 战士角色的击杀回复 3HP 被动（监听 enemy_died 事件）
- 天命史诗物品的商店特殊刷新效果
- 商店 UI 节点统一命名（当前 Item1 和 Item2~4 节点命名不一致，技术债）
