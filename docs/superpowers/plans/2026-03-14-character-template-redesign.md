# 角色模板重新设计 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重新设计 CharacterData Resource，为 5 个角色提供差异化数值和被动技能系统。

**Architecture:** 修改 CharacterData Resource 增删字段，在 Enums 中新增 PassiveType 常量类，GameData 存储被动相关运行时状态，各实体（player/tower/enemy）在自身逻辑中读取 GameData 被动数据并应用效果。

**Tech Stack:** Godot 4.6, GDScript, Resource (.tres), GUT 测试框架

---

## Chunk 1: 核心数据层（CharacterData + Enums + GameData）

### Task 1: 更新 Enums — 新增 PassiveType，移除废弃 Stat 常量

**Files:**
- Modify: `scripts/core/enums.gd:84-92`

- [ ] **Step 1: 在 enums.gd 中新增 PassiveType 类，移除 Stat.HP_REGEN 和 Stat.MOVE_SPEED_MULT**

在 `class Stat:` 之后新增 `class PassiveType:`，同时从 Stat 中移除两个废弃常量：

```gdscript
# 玩家属性 key
class Stat:
	const MAX_HP = "max_hp"
	const HP_MULT = "hp_mult"
	const DAMAGE_MULT = "damage_mult"
	const ATTACK_SPEED_MULT = "attack_speed_mult"
	const TOWER_MULT = "tower_mult"

# 角色被动技能类型
class PassiveType:
	const NONE = ""
	const KILL_HEAL = "kill_heal"
	const TOWER_ATTACK_SPEED_BONUS = "tower_attack_speed_bonus"
	const TOWER_HP_BONUS = "tower_hp_bonus"
	const COIN_BONUS = "coin_bonus"
	const DAMAGE_ON_LOW_HP = "damage_on_low_hp"
```

> **注意：** 移除 `Stat.HP_REGEN`/`Stat.MOVE_SPEED_MULT` 会导致 `game_data.gd`、`player.gd`、`character_selection.gd` 暂时编译失败，在 Task 4/5/9 中修复。建议 Task 1-5 + Task 9 作为一组连续执行，不要在中间运行测试。

- [ ] **Step 2: 暂不单独提交，与后续任务合并提交**

此任务不单独 commit，在 Task 5 完成后统一提交（避免仓库处于编译失败的中间状态）。

---

### Task 2: 更新 CharacterData Resource 类

**Files:**
- Modify: `scripts/resources/character_data.gd`

- [ ] **Step 1: 修改 character_data.gd，增删字段**

移除 `move_speed_mult` 和 `hp_regen`，新增 `starting_gold`、`passive_type`、`passive_value`：

```gdscript
class_name CharacterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var max_hp: float = 100.0
@export var speed: float = 100.0
@export var damage_mult: float = 1.0
@export var attack_speed_mult: float = 1.0
## 初始资金（与 GameConfig.PLAYER["initial_coins"] 叠加）
@export var starting_gold: int = 0
## 角色默认武器 ID
@export var default_weapon: String = ""
## 角色默认塔 ID
@export var default_tower: String = ""
## 被动技能类型（使用 Enums.PassiveType 常量）
@export var passive_type: String = ""
## 被动技能数值
@export var passive_value: float = 0.0
## 角色特色被动描述（展示用）
@export var passive_description: String = ""
## 精灵 SpriteFrames 资源路径（Aseprite Wizard 导出的 .res）
@export var sprite_frames_path: String = ""
## 头像 PNG 路径
@export var portrait_path: String = ""
## 原始精灵像素尺寸，用于缩放计算
@export var sprite_pixel_size: float = 16.0
```

- [ ] **Step 2: 暂不单独提交，与后续任务合并提交**

> **注意：** 修改 .gd 后必须同步更新 .tres 文件（Task 3），否则 Godot 加载 .tres 时会因字段不匹配报错。保留文件头（`[gd_resource ...]` 和 `[ext_resource ...]`），仅修改 `[resource]` 部分。

---

### Task 3: 更新 5 个角色 .tres 数据文件

**Files:**
- Modify: `resources/characters/dora.tres`
- Modify: `resources/characters/gorg.tres`
- Modify: `resources/characters/kaze.tres`
- Modify: `resources/characters/merlin.tres`
- Modify: `resources/characters/nemo.tres`

- [ ] **Step 1: 更新所有 .tres 文件，移除旧字段，添加新字段**

每个文件移除 `move_speed_mult` 和 `hp_regen` 行，新增 `starting_gold`、`passive_type`、`passive_value` 行。暂时所有角色使用默认值（差异化数值在被动实现后再填入）：

**dora.tres** 示例（其他文件同理，保留各自原有的不同值）：
```
[resource]
script = ExtResource("1")
id = "dora"
display_name = "朵拉"
description = "均衡型角色，适合新手"
max_hp = 100.0
speed = 100.0
damage_mult = 1.0
attack_speed_mult = 1.0
starting_gold = 0
default_weapon = "rifle"
default_tower = "pea_shooter"
passive_type = ""
passive_value = 0.0
passive_description = ""
sprite_frames_path = "res://assets/characters/dora-sprite.res"
portrait_path = "res://assets/characters/dora-portrait.png"
sprite_pixel_size = 16.0
```

- [ ] **Step 2: 暂不单独提交，继续 Task 4**

---

### Task 4: 更新 GameData — 移除废弃字段，新增 starting_gold 和被动状态

**Files:**
- Modify: `scripts/core/game_data.gd`

- [ ] **Step 1: 修改 game_data.gd**

变更内容：
1. 移除 `character_move_speed_mult` 和 `character_hp_regen` 变量
2. 新增 `character_passive_type: String` 和 `character_passive_value: float` 和 `coin_drop_mult: float` 变量
3. `init_character()` 中移除对 `move_speed_mult`/`hp_regen` 的读取，新增被动字段读取
4. `reset()` 中金币公式改为 `initial_coins + starting_gold`
5. `player_stats` 字典移除 `HP_REGEN` 和 `MOVE_SPEED_MULT` 键
6. 新增 `coin_drop_mult` 初始化（如果被动是 coin_bonus 则设为 `1.0 + passive_value`，否则 `1.0`）

```gdscript
# 角色系统（修改后）
var current_character: String = Enums.Character.DORA
var character_max_hp: float = 0.0
var character_speed: float = 0.0
var character_damage_mult: float = 1.0
var character_attack_speed_mult: float = 1.0
var character_passive_type: String = ""
var character_passive_value: float = 0.0
var coin_drop_mult: float = 1.0
```

`player_stats` 初始字典（移除 HP_REGEN 和 MOVE_SPEED_MULT）：
```gdscript
var player_stats: Dictionary = {
	Enums.Stat.MAX_HP: 100.0,
	Enums.Stat.HP_MULT: 1.0,
	Enums.Stat.DAMAGE_MULT: 1.0,
	Enums.Stat.ATTACK_SPEED_MULT: 1.0,
	Enums.Stat.TOWER_MULT: 1.0
}
```

`init_character()` 修改：
```gdscript
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
	character_passive_type = char_data.passive_type
	character_passive_value = char_data.passive_value
	# 金币掉落倍率（coin_bonus 被动）
	if character_passive_type == Enums.PassiveType.COIN_BONUS:
		coin_drop_mult = 1.0 + character_passive_value
	else:
		coin_drop_mult = 1.0
```

`reset()` 修改金币初始化行：
```gdscript
	coins = GameConfig.PLAYER["initial_coins"] + char_data.starting_gold
```

- [ ] **Step 2: 暂不单独提交，继续 Task 5**

---

### Task 5: 更新 player.gd — 移除 hp_regen 循环和 move_speed_mult，添加 kill_heal 被动

**Files:**
- Modify: `scripts/entities/player.gd`

- [ ] **Step 1: 修改 player.gd**

变更内容：
1. 移除 `hp_regen_timer` 变量（第 10 行）
2. 移除 `_ready()` 中 `hp_regen_timer = 0.0`（第 21 行）
3. 移除 `_process()` 中 hp_regen 循环（第 59-64 行）
4. `_ready()` 中 `speed` 不再乘 `MOVE_SPEED_MULT`，直接用 `GameData.character_speed`
5. `_ready()` 中如果被动是 `kill_heal`，连接 `EventBus.enemy_killed`

speed 初始化改为：
```gdscript
	speed = GameData.character_speed
```

在 `_ready()` 末尾添加被动初始化：
```gdscript
	# 被动技能初始化
	if GameData.character_passive_type == Enums.PassiveType.KILL_HEAL:
		EventBus.enemy_killed.connect(_on_enemy_killed_passive)
```

新增方法：
```gdscript
func _on_enemy_killed_passive(_enemy_type: String, _position: Vector2, _is_elite: bool) -> void:
	health.heal(GameData.character_passive_value)
```

- [ ] **Step 2: 统一提交 Task 1-5 的所有变更**

```bash
git add scripts/core/enums.gd scripts/resources/character_data.gd resources/characters/ scripts/core/game_data.gd scripts/entities/player.gd
git commit -m "refactor: 角色模板重新设计（核心数据层 + 移除废弃字段）"
```

> **注意：** `GameConfig.PLAYER["hp_regen_interval"]` 在移除 hp_regen 循环后成为未使用配置，可在后续清理中移除，本次不处理。

---

## Chunk 2: 被动技能实体集成 + UI 更新

### Task 6: 更新 tower.gd — 读取 tower_attack_speed_bonus 和 tower_hp_bonus 被动

**Files:**
- Modify: `scripts/entities/towers/tower.gd:15-19`

- [ ] **Step 1: 在 tower.gd 的 `_ready()` 中添加角色被动 buff 应用**

在 `_apply_level_stats()` 之后、`add_to_group()` 之前添加被动读取：

```gdscript
func _ready() -> void:
	_apply_level_stats()
	_apply_character_passive()
	health.death_color = Color.GREEN
	health.died.connect(_on_died)
	add_to_group(Enums.Group.TOWERS)
	EventBus.tower_upgraded.connect(_on_tower_upgraded)

func _apply_character_passive() -> void:
	var passive: String = GameData.character_passive_type
	var value: float = GameData.character_passive_value
	if passive == Enums.PassiveType.TOWER_ATTACK_SPEED_BONUS:
		apply_buff(1.0, 1.0 + value, "character_passive")
	elif passive == Enums.PassiveType.TOWER_HP_BONUS:
		var bonus_hp: float = health.max_hp * value
		health.max_hp += bonus_hp
		health.current_hp += bonus_hp
```

- [ ] **Step 2: Commit**

```bash
git add scripts/entities/towers/tower.gd
git commit -m "feat: 塔读取角色被动 buff（攻速/血量加成）"
```

---

### Task 7: 更新 enemy.gd — 读取 coin_drop_mult

**Files:**
- Modify: `scripts/entities/enemy.gd:111-121`

- [ ] **Step 1: 在 `_drop_coins()` 中应用 GameData.coin_drop_mult**

修改 `_drop_coins()` 的 coin_count 计算行：

```gdscript
func _drop_coins() -> void:
	var parent: Node = get_parent()
	if not parent:
		return

	var coin_count: int = randi_range(data.coin_drop_min, data.coin_drop_max)
	coin_count = int(coin_count * _elite_coin_mult * GameData.coin_drop_mult)
	for i in coin_count:
		var coin = SceneFactory.create_coin()
		coin.global_position = global_position + Vector2(randf_range(-COIN_SCATTER_RANGE, COIN_SCATTER_RANGE), randf_range(-COIN_SCATTER_RANGE, COIN_SCATTER_RANGE))
		parent.call_deferred("add_child", coin)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/entities/enemy.gd
git commit -m "feat: 敌人金币掉落应用角色 coin_bonus 被动倍率"
```

---

### Task 8: 更新 weapon.gd — 读取 damage_on_low_hp 被动

**Files:**
- Modify: `scripts/entities/weapons/weapon.gd:17-18`

- [ ] **Step 1: 在 `get_damage()` 中添加低血量伤害加成**

武器通过 `owner_node` 引用玩家（已在 WeaponManager.initialize 中设置），无需额外查找：

```gdscript
func get_damage() -> float:
	var base: float = weapon_data.damage_per_level[get_current_level() - 1]
	# 角色被动：低血量伤害加成（仅影响武器伤害，不影响塔伤害）
	if GameData.character_passive_type == Enums.PassiveType.DAMAGE_ON_LOW_HP:
		if owner_node and owner_node.has_node("HealthComponent"):
			var hp: HealthComponent = owner_node.get_node("HealthComponent")
			if hp.current_hp / hp.max_hp < 0.3:
				base *= (1.0 + GameData.character_passive_value)
	return base
```

- [ ] **Step 2: Commit**

```bash
git add scripts/entities/weapons/weapon.gd
git commit -m "feat: 武器 get_damage 应用角色 damage_on_low_hp 被动"
```

---

### Task 9: 更新角色选择 UI — 移除 hp_regen 显示，调整属性展示

**Files:**
- Modify: `scripts/ui/character_selection.gd`
- Modify: `scenes/ui/character_selection.tscn`（通过 gdai-mcp 或手动）

- [ ] **Step 1: 修改 character_selection.gd**

变更内容：
1. 从 `STAT_BASELINES` 移除 `"hp_regen"` 项，新增 `"starting_gold": 0`
2. 移除 `_hp_regen_value` 的 `@onready` 引用
3. 新增 `@onready var _starting_gold_value: Label = %StartingGoldValue`（需要在 .tscn 中添加对应节点）
4. `_fill_detail_panel()` 移除 hp_regen 显示行，新增 starting_gold 显示
5. `_apply_styles()` 中 value_label 数组移除 `_hp_regen_value`，替换为 `_starting_gold_value`
6. `_fill_detail_panel()` 中武器标签改为同时显示默认武器和默认塔

```gdscript
const STAT_BASELINES := {
	"max_hp": 100.0,
	"speed": 200.0,
	"damage_mult": 1.0,
	"attack_speed_mult": 1.0,
	"starting_gold": 0,
}
```

`_fill_detail_panel()` 中属性部分改为：
```gdscript
	_hp_value.text = "%d" % int(char_data.max_hp)
	_speed_value.text = "%d" % int(char_data.speed)
	_damage_value.text = "x%.1f" % char_data.damage_mult
	_attack_speed_value.text = "x%.1f" % char_data.attack_speed_mult
	_starting_gold_value.text = "%d" % char_data.starting_gold

	_color_stat(_hp_value, char_data.max_hp, STAT_BASELINES["max_hp"])
	_color_stat(_speed_value, char_data.speed, STAT_BASELINES["speed"])
	_color_stat(_damage_value, char_data.damage_mult, STAT_BASELINES["damage_mult"])
	_color_stat(_attack_speed_value, char_data.attack_speed_mult, STAT_BASELINES["attack_speed_mult"])
	_color_stat(_starting_gold_value, float(char_data.starting_gold), float(STAT_BASELINES["starting_gold"]))
```

- [ ] **Step 2: 更新 character_selection.tscn 场景**

在 StatsGrid 中将 "生命回复" 标签和 HPRegenValue 替换为 "初始资金" 标签和 StartingGoldValue。可通过 gdai-mcp 或直接编辑 .tscn 文件实现。

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/character_selection.gd scenes/ui/character_selection.tscn
git commit -m "refactor: 角色选择 UI 移除 hp_regen，新增 starting_gold 显示"
```

---

### Task 10: 确认无需额外修改的文件

- [ ] **Step 1: 确认以下文件无需修改**

- `.godot/global_script_class_cache.cfg` — 本次没有新增 class_name，PassiveType 是 Enums 的内部类，不需要单独注册
- `scripts/ui/placement.gd` — 虽然 spec 中提到此文件，但 `starting_gold` 通过 `GameData.reset()` 中的 `coins = initial_coins + starting_gold` 已经正确设置，placement 通过 `GameData.coins` 读取，无需额外修改
- `scripts/core/scene_factory.gd` — 不直接使用 CharacterData

---

## Chunk 3: 测试更新

### Task 11: 更新现有测试

**Files:**
- Modify: `tests/unit/test_character_selection.gd`
- Modify: `tests/unit/test_resource_loading.gd`

- [ ] **Step 1: 更新 test_character_selection.gd**

在 `test_init_character_sets_correct_stats()` 中，验证 `GameData.character_max_hp` 仍然正确。
确认测试中没有引用 `hp_regen` 或 `move_speed_mult`（根据搜索结果，当前测试未引用这些字段）。

新增测试验证 starting_gold 和 passive_type 字段：
```gdscript
const VALID_PASSIVE_TYPES: Array[String] = [
	Enums.PassiveType.NONE,
	Enums.PassiveType.KILL_HEAL,
	Enums.PassiveType.TOWER_ATTACK_SPEED_BONUS,
	Enums.PassiveType.TOWER_HP_BONUS,
	Enums.PassiveType.COIN_BONUS,
	Enums.PassiveType.DAMAGE_ON_LOW_HP,
]

func test_character_has_valid_passive_type() -> void:
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		assert_true(
			char_data.passive_type in VALID_PASSIVE_TYPES,
			"%s passive_type '%s' 不是有效的 PassiveType 常量" % [character_id, char_data.passive_type]
		)

func test_character_has_starting_gold() -> void:
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		assert_true(char_data.starting_gold >= 0, "%s starting_gold 不应为负数" % character_id)
```

- [ ] **Step 2: 更新 test_resource_loading.gd**

确认角色资源加载测试仍然通过。当前测试只验证 `max_hp`、`speed`、`damage_mult` 等保留字段，无需修改。

- [ ] **Step 3: 运行全部测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

预期：所有测试通过。

- [ ] **Step 4: Commit**

```bash
git add tests/
git commit -m "test: 新增角色被动技能和 starting_gold 字段测试"
```

---

### Task 12: 新增被动技能集成测试

**Files:**
- Create: `tests/unit/test_character_passive.gd`

- [ ] **Step 1: 编写被动技能单元测试**

```gdscript
extends GutTest

func test_init_character_sets_passive_fields() -> void:
	GameData.init_character(Enums.Character.DORA)
	assert_eq(GameData.character_passive_type, "", "默认角色应无被动")
	assert_eq(GameData.character_passive_value, 0.0, "默认角色被动值应为 0")

func test_coin_drop_mult_default() -> void:
	GameData.init_character(Enums.Character.DORA)
	assert_eq(GameData.coin_drop_mult, 1.0, "无 coin_bonus 被动时倍率应为 1.0")

func test_reset_applies_starting_gold() -> void:
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	var char_data: CharacterData = GameConfig.characters[Enums.Character.DORA]
	var expected: int = GameConfig.PLAYER["initial_coins"] + char_data.starting_gold
	assert_eq(GameData.coins, expected, "reset 后金币应为 initial_coins + starting_gold")

func test_player_stats_no_hp_regen_key() -> void:
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	assert_false(GameData.player_stats.has("hp_regen"), "player_stats 不应再包含 hp_regen")

func test_player_stats_no_move_speed_mult_key() -> void:
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	assert_false(GameData.player_stats.has("move_speed_mult"), "player_stats 不应再包含 move_speed_mult")
```

- [ ] **Step 2: 运行测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_character_passive.gd -gexit`

预期：全部通过。

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_character_passive.gd
git commit -m "test: 新增角色被动技能和 starting_gold 集成测试"
```

---

### Task 13: 全量回归测试

- [ ] **Step 1: 运行全部测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

预期：全部通过（约 366 个测试）。

- [ ] **Step 2: 修复任何回归失败**

如有因移除 `HP_REGEN`/`MOVE_SPEED_MULT` 导致的失败，逐个修复。

- [ ] **Step 3: 最终 Commit**

```bash
git add -A
git commit -m "fix: 修复角色模板重构后的回归测试"
```
