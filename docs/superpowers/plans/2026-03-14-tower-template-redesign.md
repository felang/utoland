# 植物塔模板重新设计 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重新整理 TowerData 资源类，新增 description/icon_path/rarity 字段，用 @export_group 分组，升级系统使用塔稀有度权重。

**Architecture:** 与武器模板重构模式一致：枚举 → Resource 类改造 → .tres 数据更新 → 生成器权重 → UI 卡片 → 测试。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

---

## Chunk 1: 核心数据层（枚举 + Resource 类 + .tres 文件）

### Task 1: 新增 TowerRarity 枚举

**Files:**
- Modify: `scripts/core/enums.gd:101-105`

- [ ] **Step 1: 在 WeaponRarity 之后新增 TowerRarity 类**

在 `scripts/core/enums.gd` 的 `WeaponRarity` 类后面（第 105 行之后）插入：

```gdscript
# 塔稀有度
class TowerRarity:
	const COMMON = 0
	const RARE = 1
	const EPIC = 2
```

- [ ] **Step 2: 提交**

```bash
git add scripts/core/enums.gd
git commit -m "feat: 新增 TowerRarity 枚举（COMMON/RARE/EPIC）"
```

---

### Task 2: TowerData 资源类 @export_group 分组 + 新增字段

**Files:**
- Modify: `scripts/resources/tower_data.gd`

- [ ] **Step 1: 重写 tower_data.gd，添加 @export_group 和新字段**

完整替换 `scripts/resources/tower_data.gd` 为：

```gdscript
class_name TowerData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export var rarity: int = 0

@export_group("等级系统")
@export var max_level: int = 5
@export var hp_per_level: PackedFloat32Array = []
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var attack_range_per_level: PackedFloat32Array = []
@export var slow_ratio_per_level: PackedFloat32Array = []
@export var shop_price_per_level: PackedInt32Array = []
@export var place_cost_per_level: PackedInt32Array = []
@export var milestones: Dictionary = {}

@export_group("玫瑰专有")
@export var burst_count: int = 3
@export var burst_interval: float = 0.15

@export_group("藤蔓专有")
@export var trap_duration_per_level: PackedFloat32Array = []
@export var trap_cooldown: float = 8.0

@export_group("蒲公英专有")
@export var knockback_force_per_level: PackedFloat32Array = []
@export var knockback_interval: float = 5.0

@export_group("猪笼草专有")
@export var grab_dps_per_level: PackedFloat32Array = []
@export var digest_duration_per_level: PackedFloat32Array = []

@export_group("荆棘专有")
@export var reflect_ratio_per_level: PackedFloat32Array = []

@export_group("橡树专有")
@export var aura_reduction_per_level: PackedFloat32Array = []

@export_group("向日葵专有")
@export var generate_amount_per_level: PackedFloat32Array = []
@export var generate_interval_per_level: PackedFloat32Array = []

@export_group("薄荷专有")
@export var buff_damage_mult_per_level: PackedFloat32Array = []
@export var buff_speed_mult_per_level: PackedFloat32Array = []

@export_group("治愈花专有")
@export var heal_amount_per_level: PackedFloat32Array = []
@export var heal_interval_per_level: PackedFloat32Array = []

@export_group("爆竹竹专有")
@export var charge_time: float = 15.0
@export var explosion_damage_per_level: PackedFloat32Array = []
@export var explosion_range_per_level: PackedFloat32Array = []
```

- [ ] **Step 2: 提交**

```bash
git add scripts/resources/tower_data.gd
git commit -m "refactor: TowerData 新增 description/icon_path/rarity，@export_group 分组"
```

---

### Task 3: 更新 15 个 .tres 文件添加 description/rarity 数据

**Files:**
- Modify: `resources/towers/pea_shooter.tres`
- Modify: `resources/towers/stump.tres`
- Modify: `resources/towers/ice_flower.tres`
- Modify: `resources/towers/sunflower.tres`
- Modify: `resources/towers/thorn.tres`
- Modify: `resources/towers/dandelion.tres`
- Modify: `resources/towers/cactus.tres`
- Modify: `resources/towers/rose.tres`
- Modify: `resources/towers/mushroom.tres`
- Modify: `resources/towers/heal_flower.tres`
- Modify: `resources/towers/mint.tres`
- Modify: `resources/towers/vine.tres`
- Modify: `resources/towers/pitcher.tres`
- Modify: `resources/towers/oak.tres`
- Modify: `resources/towers/bamboo.tres`

- [ ] **Step 1: 在每个 .tres 文件的 `display_name` 行后插入 description 和 rarity**

在 .tres 文件中，新字段插入在 `display_name = "..."` 行之后。为与武器 .tres 保持一致，所有塔显式写入 `icon_path = ""`  和 `rarity` 值（包括 COMMON 的 `rarity = 0`）。

**COMMON (rarity=0)，6 个文件：**

`resources/towers/pea_shooter.tres` — 在 `display_name = "射手塔"` 后插入：
```
description = "稳定射击最近的敌人。虽然平凡，但从不缺席。"
icon_path = ""
rarity = 0
```

`resources/towers/stump.tres` — 在 `display_name = "墙塔"` 后插入：
```
description = "坚实的血肉屏障，不攻击但极难击倒。年轮是它唯一的武器。"
icon_path = ""
rarity = 0
```

`resources/towers/ice_flower.tres` — 在 `display_name = "减速塔"` 后插入：
```
description = "散发寒气减速周围敌人。冬天的花朵，盛开在最不该温暖的地方。"
icon_path = ""
rarity = 0
```

`resources/towers/sunflower.tres` — 在 `display_name = "向日葵"` 后插入：
```
description = "定时产出金币。它追逐的不是阳光，而是闪闪发光的一切。"
icon_path = ""
rarity = 0
```

`resources/towers/thorn.tres` — 在 `display_name = "荆棘"` 后插入：
```
description = "受击时将伤害反弹给攻击者。以牙还牙，以刺还刺。"
icon_path = ""
rarity = 0
```

`resources/towers/dandelion.tres` — 在 `display_name = "蒲公英"` 后插入：
```
description = "周期性击退范围内敌人。一口气吹散所有烦恼。"
icon_path = ""
rarity = 0
```

**RARE (rarity=1)，5 个文件：**

`resources/towers/cactus.tres` — 在 `display_name = "仙人掌"` 后插入：
```
description = "瞄准血量最高的敌人精准狙击。沙漠猎手，一针见血。"
icon_path = ""
rarity = 1
```

`resources/towers/rose.tres` — 在 `display_name = "玫瑰"` 后插入：
```
description = "三连发爆射，火力凶猛。美丽的东西往往带刺。"
icon_path = ""
rarity = 1
```

`resources/towers/mushroom.tres` — 在 `display_name = "毒蘑菇"` 后插入：
```
description = "释放毒雾持续伤害范围内敌人。闻起来不太对劲。"
icon_path = ""
rarity = 1
```

`resources/towers/heal_flower.tres` — 在 `display_name = "治愈花"` 后插入：
```
description = "治疗血量最低的友方塔。温柔的力量，无声的守护。"
icon_path = ""
rarity = 1
```

`resources/towers/mint.tres` — 在 `display_name = "薄荷"` 后插入：
```
description = "增强周围友方塔的攻速和伤害。清凉提神，战斗加倍。"
icon_path = ""
rarity = 1
```

**EPIC (rarity=2)，4 个文件：**

`resources/towers/vine.tres` — 在 `display_name = "藤蔓"` 后插入：
```
description = "接触敌人时将其定身。一旦缠上，就别想走了。"
icon_path = ""
rarity = 2
```

`resources/towers/pitcher.tres` — 在 `display_name = "猪笼草"` 后插入：
```
description = "抓取敌人缓慢消化。Boss 太大塞不进去。"
icon_path = ""
rarity = 2
```

`resources/towers/oak.tres` — 在 `display_name = "橡树"` 后插入：
```
description = "光环减少周围友方塔受到的伤害。千年老树，庇护万物。"
icon_path = ""
rarity = 2
```

`resources/towers/bamboo.tres` — 在 `display_name = "爆竹竹"` 后插入：
```
description = "充能后自爆造成大范围伤害。生命虽短，但要轰轰烈烈。"
icon_path = ""
rarity = 2
```

- [ ] **Step 2: 提交**

```bash
git add resources/towers/
git commit -m "feat: 15 个塔 .tres 添加 description/rarity 数据"
```

---

## Chunk 2: 升级系统改造（生成器 + 卡片 UI）

### Task 4: 升级生成器使用塔稀有度权重

**Files:**
- Modify: `scripts/systems/upgrade_generator.gd:4-8,66-83`

- [ ] **Step 1: 新增 TOWER_RARITY_WEIGHTS 常量**

在 `scripts/systems/upgrade_generator.gd` 的 `RARITY_WEIGHTS` 常量后面（第 8 行之后）插入：

```gdscript
const TOWER_RARITY_WEIGHTS: Dictionary = {
	Enums.TowerRarity.COMMON: 1.0,
	Enums.TowerRarity.RARE: 0.6,
	Enums.TowerRarity.EPIC: 0.3,
}
```

- [ ] **Step 2: 塔池 _weight 改为读取 td.rarity**

在 `_build_pool()` 方法中，将两处塔的 `"_weight": 1.0` 替换为：

第 76 行（新塔）：
```gdscript
"_weight": TOWER_RARITY_WEIGHTS.get(td.rarity, 1.0)
```

第 82 行（升级塔）：
```gdscript
"_weight": TOWER_RARITY_WEIGHTS.get(td.rarity, 1.0)
```

- [ ] **Step 3: 提交**

```bash
git add scripts/systems/upgrade_generator.gd
git commit -m "feat: 升级生成器使用塔稀有度权重替代固定权重"
```

---

### Task 5: 升级卡片展示塔描述和稀有度边框颜色

**Files:**
- Modify: `scripts/ui/upgrade_card_builder.gd:16-20,63-74`

- [ ] **Step 1: 塔边框颜色改为按稀有度着色**

在 `create_card()` 方法中，将第 19-20 行的塔边框硬编码：

```gdscript
	else:
		border_color = Color("#66bb6a")
```

替换为：

```gdscript
	else:
		var td: TowerData = GameConfig.towers[opt["id"]]
		border_color = RARITY_COLORS.get(td.rarity, Color("#4fc3f7"))
```

- [ ] **Step 2: 清理武器描述的无用 _wd 判断，并添加塔描述显示**

将第 63-74 行的描述部分：

```gdscript
	# 描述文字（仅武器且 description 非空时显示）
	if is_weapon:
		if not opt.has("_wd"):
			var wd_for_desc: WeaponData = GameConfig.weapons[opt["id"]]
			if wd_for_desc.description != "":
				var desc_lbl := Label.new()
				desc_lbl.text = wd_for_desc.description
				desc_lbl.add_theme_font_size_override("font_size", 10)
				desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(desc_lbl)
```

替换为：

```gdscript
	# 描述文字
	var _desc_text: String = ""
	if is_weapon:
		var wd_for_desc: WeaponData = GameConfig.weapons[opt["id"]]
		_desc_text = wd_for_desc.description
	else:
		var td_for_desc: TowerData = GameConfig.towers[opt["id"]]
		_desc_text = td_for_desc.description
	if _desc_text != "":
		var desc_lbl := Label.new()
		desc_lbl.text = _desc_text
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)
```

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/upgrade_card_builder.gd
git commit -m "feat: 升级卡片展示塔描述和稀有度边框颜色"
```

---

## Chunk 3: 测试

### Task 6: 新增塔模板稀有度和描述测试

**Files:**
- Create: `tests/unit/test_tower_data.gd`

- [ ] **Step 1: 创建测试文件**

创建 `tests/unit/test_tower_data.gd`：

```gdscript
extends GutTest

func test_tower_rarity_enum_values() -> void:
	assert_eq(Enums.TowerRarity.COMMON, 0, "COMMON should be 0")
	assert_eq(Enums.TowerRarity.RARE, 1, "RARE should be 1")
	assert_eq(Enums.TowerRarity.EPIC, 2, "EPIC should be 2")

func test_all_towers_have_valid_rarity() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_true(
			td.rarity >= Enums.TowerRarity.COMMON and td.rarity <= Enums.TowerRarity.EPIC,
			"%s rarity %d 不在有效范围 [0, 2]" % [tower_id, td.rarity]
		)

func test_all_towers_have_description() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_ne(td.description, "", "%s 缺少 description" % tower_id)

func test_tower_rarity_weight_mapping() -> void:
	assert_true(UpgradeGenerator.TOWER_RARITY_WEIGHTS.has(Enums.TowerRarity.COMMON), "缺少 COMMON 权重")
	assert_true(UpgradeGenerator.TOWER_RARITY_WEIGHTS.has(Enums.TowerRarity.RARE), "缺少 RARE 权重")
	assert_true(UpgradeGenerator.TOWER_RARITY_WEIGHTS.has(Enums.TowerRarity.EPIC), "缺少 EPIC 权重")
	assert_gt(
		UpgradeGenerator.TOWER_RARITY_WEIGHTS[Enums.TowerRarity.COMMON],
		UpgradeGenerator.TOWER_RARITY_WEIGHTS[Enums.TowerRarity.RARE],
		"COMMON 权重应大于 RARE"
	)
	assert_gt(
		UpgradeGenerator.TOWER_RARITY_WEIGHTS[Enums.TowerRarity.RARE],
		UpgradeGenerator.TOWER_RARITY_WEIGHTS[Enums.TowerRarity.EPIC],
		"RARE 权重应大于 EPIC"
	)

func test_common_towers_count() -> void:
	var count: int = 0
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		if td.rarity == Enums.TowerRarity.COMMON:
			count += 1
	assert_eq(count, 6, "应有 6 个普通塔")

func test_rare_towers_count() -> void:
	var count: int = 0
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		if td.rarity == Enums.TowerRarity.RARE:
			count += 1
	assert_eq(count, 5, "应有 5 个稀有塔")

func test_epic_towers_count() -> void:
	var count: int = 0
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		if td.rarity == Enums.TowerRarity.EPIC:
			count += 1
	assert_eq(count, 4, "应有 4 个史诗塔")
```

- [ ] **Step 2: 运行测试验证通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gprefix=test_tower_data
```

期望：7 个测试全部 PASS。

- [ ] **Step 3: 运行全部测试确认无回归**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

期望：所有测试 PASS，无回归。

- [ ] **Step 4: 提交**

```bash
git add tests/unit/test_tower_data.gd
git commit -m "test: 新增塔模板稀有度和描述测试"
```
