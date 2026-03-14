# 武器模板重新设计 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重新设计 WeaponData Resource，新增描述/图标/稀有度字段，用 @export_group 整理分组，并在升级系统中集成稀有度权重。

**Architecture:** 修改 WeaponData Resource 添加字段和分组，Enums 新增 WeaponRarity 常量，upgrade_generator 用稀有度映射权重，upgrade_card_builder 展示描述和稀有度边框颜色。

**Tech Stack:** Godot 4.6, GDScript, Resource (.tres), GUT 测试框架

---

## Chunk 1: 数据层 + 稀有度系统

### Task 1: 新增 WeaponRarity 枚举

**Files:**
- Modify: `scripts/core/enums.gd:100` (在 PassiveType 类之后插入)

- [ ] **Step 1: 在 enums.gd 中新增 WeaponRarity 常量类**

在 `class PassiveType:` 块之后、`enum BoomerangState` 之前插入：

```gdscript
# 武器稀有度
class WeaponRarity:
	const COMMON = 0
	const RARE = 1
	const EPIC = 2
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/enums.gd
git commit -m "feat: 新增 WeaponRarity 枚举（COMMON/RARE/EPIC）"
```

---

### Task 2: 更新 WeaponData Resource 类 — 新增字段 + @export_group

**Files:**
- Modify: `scripts/resources/weapon_data.gd`

- [ ] **Step 1: 替换 weapon_data.gd 全文**

```gdscript
class_name WeaponData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export var rarity: int = 0
@export var weapon_type: String = ""
@export var projectile_type: String = "bullet"

@export_group("等级系统")
@export var max_level: int = 5
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var weapon_range_per_level: PackedFloat32Array = []
@export var milestones: Dictionary = {}

@export_group("通用属性")
@export var knockback_force: float = 40.0
@export var bullet_speed: float = 300.0

@export_group("子弹专有")
@export var bullet_count: int = 1

@export_group("回旋镖专有")
@export var boomerang_speed: float = 175.0
@export var outbound_distance: float = 100.0
@export var return_speed_mult: float = 1.3
@export var boomerang_max_lifetime: float = 5.0

@export_group("激光专有")
@export var beam_range: float = 200.0
@export var beam_width: float = 2.0
@export var beam_duration: float = 0.08

@export_group("火箭专有")
@export var explosion_radius_per_level: PackedFloat32Array = []

@export_group("火焰专有")
@export var flame_cone_angle: float = 45.0

@export_group("闪电专有")
@export var chain_count: int = 3
@export var chain_decay: float = 0.7
@export var chain_range: float = 150.0

@export_group("冰冻专有")
@export var slow_on_hit: float = 0.0
@export var slow_duration: float = 2.0
```

- [ ] **Step 2: Commit**

```bash
git add scripts/resources/weapon_data.gd
git commit -m "refactor: WeaponData 新增 description/icon_path/rarity，@export_group 分组"
```

---

### Task 3: 更新 10 个武器 .tres 文件

**Files:**
- Modify: `resources/weapons/rifle.tres`
- Modify: `resources/weapons/shotgun.tres`
- Modify: `resources/weapons/minigun.tres`
- Modify: `resources/weapons/boomerang.tres`
- Modify: `resources/weapons/ice_gun.tres`
- Modify: `resources/weapons/laser.tres`
- Modify: `resources/weapons/blade.tres`
- Modify: `resources/weapons/rocket.tres`
- Modify: `resources/weapons/lightning.tres`
- Modify: `resources/weapons/flamethrower.tres`

- [ ] **Step 1: 为每个 .tres 文件添加 description、icon_path、rarity 字段**

保留文件头（`[gd_resource ...]` 和 `[ext_resource ...]`）不变，在 `[resource]` 部分的 `display_name` 之后添加新字段。

稀有度和描述值：

| 武器 | rarity | description |
|---|---|---|
| rifle | 0 | "基础连射武器，稳定可靠" |
| shotgun | 0 | "近距离散射，一次发射多枚弹丸" |
| minigun | 0 | "高速连射，持续输出" |
| boomerang | 0 | "投掷后自动返回，可二次命中" |
| ice_gun | 1 | "命中敌人施加减速效果" |
| laser | 1 | "持续光束，快速射击" |
| blade | 1 | "近距离环形斩击" |
| rocket | 1 | "发射火箭弹，造成范围爆炸伤害" |
| lightning | 2 | "闪电链式弹跳，可打击多个敌人" |
| flamethrower | 2 | "持续锥形火焰，灼烧区域敌人" |

所有武器 `icon_path = ""`（暂无图标资源）。

示例 — rifle.tres 的 `[resource]` 部分变为：
```
[resource]
script = ExtResource("1")
id = "rifle"
display_name = "步枪"
description = "基础连射武器，稳定可靠"
icon_path = ""
rarity = 0
weapon_type = "bullet"
max_level = 5
damage_per_level = PackedFloat32Array(10, 15, 22, 30, 40)
fire_rate_per_level = PackedFloat32Array(0.1, 0.09, 0.08, 0.07, 0.06)
weapon_range_per_level = PackedFloat32Array(150, 160, 170, 185, 200)
```

示例 — lightning.tres 的 `[resource]` 部分变为：
```
[resource]
script = ExtResource("1")
id = "lightning"
display_name = "闪电链"
description = "闪电链式弹跳，可打击多个敌人"
icon_path = ""
rarity = 2
weapon_type = "lightning"
projectile_type = "chain"
max_level = 5
chain_count = 3
chain_decay = 0.7
chain_range = 150.0
knockback_force = 0.0
damage_per_level = PackedFloat32Array(12, 17, 23, 30, 40)
fire_rate_per_level = PackedFloat32Array(0.8, 0.72, 0.65, 0.58, 0.5)
weapon_range_per_level = PackedFloat32Array(300, 320, 340, 370, 400)
```

- [ ] **Step 2: Commit**

```bash
git add resources/weapons/
git commit -m "feat: 10 个武器 .tres 添加 description/rarity 数据"
```

---

## Chunk 2: 升级系统集成 + UI

### Task 4: 更新 upgrade_generator.gd — 稀有度权重

**Files:**
- Modify: `scripts/systems/upgrade_generator.gd:1-58`

- [ ] **Step 1: 在类顶部添加 RARITY_WEIGHTS 常量，修改 _build_pool() 中武器权重**

在 `class_name UpgradeGenerator` 之后添加常量：
```gdscript
const RARITY_WEIGHTS: Dictionary = {
	Enums.WeaponRarity.COMMON: 1.0,
	Enums.WeaponRarity.RARE: 0.6,
	Enums.WeaponRarity.EPIC: 0.3,
}
```

在 `_build_pool()` 中，将武器条目的两处 `"_weight": 1.0` 改为 `"_weight": RARITY_WEIGHTS.get(wd.rarity, 1.0)`。

具体修改第 52 行：
```
"_weight": 1.0
```
改为：
```
"_weight": RARITY_WEIGHTS.get(wd.rarity, 1.0)
```

第 58 行同理：
```
"current_level": current_level, "_weight": 1.0
```
改为：
```
"current_level": current_level, "_weight": RARITY_WEIGHTS.get(wd.rarity, 1.0)
```

塔池的 `"_weight": 1.0` 保持不变。

- [ ] **Step 2: Commit**

```bash
git add scripts/systems/upgrade_generator.gd
git commit -m "feat: 升级生成器使用武器稀有度权重替代固定权重"
```

---

### Task 5: 更新 upgrade_card_builder.gd — 描述展示 + 稀有度边框

**Files:**
- Modify: `scripts/ui/upgrade_card_builder.gd`

- [ ] **Step 1: 添加稀有度边框颜色映射**

在类顶部常量区域（第 5-6 行之后）添加：
```gdscript
const RARITY_COLORS: Dictionary = {
	Enums.WeaponRarity.COMMON: Color("#4fc3f7"),
	Enums.WeaponRarity.RARE: Color("#ab47bc"),
	Enums.WeaponRarity.EPIC: Color("#ffa726"),
}
```

- [ ] **Step 2: 修改 create_card() 中武器边框颜色**

将第 10 行：
```gdscript
	var border_color: Color = Color("#4fc3f7") if is_weapon else Color("#66bb6a")
```
改为：
```gdscript
	var border_color: Color
	if is_weapon:
		var wd: WeaponData = GameConfig.weapons[opt["id"]]
		border_color = RARITY_COLORS.get(wd.rarity, Color("#4fc3f7"))
	else:
		border_color = Color("#66bb6a")
```

- [ ] **Step 3: 在名称标签之后添加描述文字**

在 `vbox.add_child(name_lbl)` 之后（第 51 行之后），添加 description 展示：

```gdscript
	# 描述文字（仅武器且 description 非空时显示）
	if is_weapon:
		var wd_desc: WeaponData = GameConfig.weapons[opt["id"]]
		if wd_desc.description != "":
			var desc_lbl := Label.new()
			desc_lbl.text = wd_desc.description
			desc_lbl.add_theme_font_size_override("font_size", 10)
			desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(desc_lbl)
```

> 注意：避免重复获取 WeaponData。如果 Step 2 已经获取了 `wd`，可以复用。但由于 create_card 是 static 函数且代码流较短，重新获取也可接受。实现时可优化为只获取一次。

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/upgrade_card_builder.gd
git commit -m "feat: 升级卡片展示武器描述和稀有度边框颜色"
```

---

## Chunk 3: 测试

### Task 6: 新增武器模板测试

**Files:**
- Create: `tests/unit/test_weapon_data.gd`
- Modify: `tests/unit/test_resource_loading.gd`（可能需要）

- [ ] **Step 1: 创建武器数据测试文件**

```gdscript
extends GutTest

func test_all_weapons_have_valid_rarity() -> void:
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		assert_true(
			wd.rarity >= Enums.WeaponRarity.COMMON and wd.rarity <= Enums.WeaponRarity.EPIC,
			"%s rarity %d 不在有效范围 [0, 2]" % [weapon_id, wd.rarity]
		)

func test_all_weapons_have_description() -> void:
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		assert_ne(wd.description, "", "%s 缺少 description" % weapon_id)

func test_rarity_weight_mapping() -> void:
	# 验证 RARITY_WEIGHTS 常量包含所有稀有度等级
	assert_true(UpgradeGenerator.RARITY_WEIGHTS.has(Enums.WeaponRarity.COMMON), "缺少 COMMON 权重")
	assert_true(UpgradeGenerator.RARITY_WEIGHTS.has(Enums.WeaponRarity.RARE), "缺少 RARE 权重")
	assert_true(UpgradeGenerator.RARITY_WEIGHTS.has(Enums.WeaponRarity.EPIC), "缺少 EPIC 权重")
	# 验证权重递减
	assert_gt(
		UpgradeGenerator.RARITY_WEIGHTS[Enums.WeaponRarity.COMMON],
		UpgradeGenerator.RARITY_WEIGHTS[Enums.WeaponRarity.RARE],
		"COMMON 权重应大于 RARE"
	)
	assert_gt(
		UpgradeGenerator.RARITY_WEIGHTS[Enums.WeaponRarity.RARE],
		UpgradeGenerator.RARITY_WEIGHTS[Enums.WeaponRarity.EPIC],
		"RARE 权重应大于 EPIC"
	)

func test_common_weapons_count() -> void:
	var count: int = 0
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if wd.rarity == Enums.WeaponRarity.COMMON:
			count += 1
	assert_eq(count, 4, "应有 4 把普通武器")

func test_rare_weapons_count() -> void:
	var count: int = 0
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if wd.rarity == Enums.WeaponRarity.RARE:
			count += 1
	assert_eq(count, 4, "应有 4 把稀有武器")

func test_epic_weapons_count() -> void:
	var count: int = 0
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if wd.rarity == Enums.WeaponRarity.EPIC:
			count += 1
	assert_eq(count, 2, "应有 2 把史诗武器")
```

- [ ] **Step 2: 运行测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_weapon_data.gd -gexit`

预期：全部通过。

- [ ] **Step 3: 运行全量回归测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

预期：全部通过。

- [ ] **Step 4: Commit**

```bash
git add tests/unit/test_weapon_data.gd
git commit -m "test: 新增武器模板稀有度和描述测试"
```
