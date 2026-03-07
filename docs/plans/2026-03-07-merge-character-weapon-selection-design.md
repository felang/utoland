# 合并角色与武器选择 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将角色选择和武器选择合并为一个场景，武器作为角色的固定配置项。

**Architecture:** 在 CharacterData Resource 中新增 `default_weapon` 字段，角色 `.tres` 文件配置对应武器 ID。角色选择场景改为卡片式布局展示属性和武器，选择后自动设置武器。删除独立的武器选择场景。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

---

### Task 1: CharacterData 新增 default_weapon 字段

**Files:**
- Modify: `scripts/resources/character_data.gd:12` (末尾添加字段)
- Test: `tests/unit/test_resource_loading.gd`

**Step 1: 写失败测试**

在 `tests/unit/test_resource_loading.gd` 角色资源加载区域末尾添加：

```gdscript
func test_character_warrior_has_default_weapon() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.WARRIOR]
	assert_eq(c.default_weapon, Enums.WeaponId.RIFLE, "战士默认武器应为步枪")

func test_character_ranger_has_default_weapon() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.RANGER]
	assert_eq(c.default_weapon, Enums.WeaponId.BOOMERANG, "游侠默认武器应为回旋镖")

func test_character_tank_has_default_weapon() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.TANK]
	assert_eq(c.default_weapon, Enums.WeaponId.LASER, "坦克默认武器应为激光枪")
```

**Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_resource_loading.gd -gexit`
Expected: 3 个新测试 FAIL

**Step 3: 实现 — 修改 CharacterData**

在 `scripts/resources/character_data.gd:12` (`hp_regen` 行之后) 添加：

```gdscript
@export var default_weapon: String = ""
```

**Step 4: 实现 — 更新 3 个角色 .tres 文件**

`resources/characters/warrior.tres` 末尾添加：
```
default_weapon = "rifle"
```

`resources/characters/ranger.tres` 末尾添加：
```
default_weapon = "boomerang"
```

`resources/characters/tank.tres` 末尾添加：
```
default_weapon = "laser"
```

**Step 5: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_resource_loading.gd -gexit`
Expected: 全部 PASS

**Step 6: 提交**

```bash
git add scripts/resources/character_data.gd resources/characters/*.tres tests/unit/test_resource_loading.gd
git commit -m "feat: CharacterData 新增 default_weapon 字段并配置角色武器对应"
```

---

### Task 2: 角色选择脚本改为数据驱动卡片式 + 自动设置武器

**Files:**
- Rewrite: `scripts/ui/character_selection.gd`
- Rewrite: `scenes/ui/character_selection.tscn`

**Step 1: 重写角色选择脚本**

替换 `scripts/ui/character_selection.gd` 全部内容：

```gdscript
extends Control

# 角色选择界面 — 数据驱动，从 GameConfig.characters 生成卡片

@onready var _container: HBoxContainer = $CharacterContainer

func _ready() -> void:
	# 清除编辑器中的占位节点
	for child in _container.get_children():
		child.queue_free()

	# 从 GameConfig 动态生成角色卡片
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		var weapon_data: WeaponData = GameConfig.weapons[char_data.default_weapon]
		_container.add_child(_create_card(character_id, char_data, weapon_data))


func _create_card(character_id: String, char_data: CharacterData, weapon_data: WeaponData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 180)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	# 角色名称
	var name_label := Label.new()
	name_label.text = char_data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# 属性信息
	var stats_label := Label.new()
	stats_label.text = "生命: %d\n速度: %d\n伤害: x%.1f" % [
		int(char_data.max_hp), int(char_data.speed), char_data.damage_mult
	]
	vbox.add_child(stats_label)

	# 武器名称
	var weapon_label := Label.new()
	weapon_label.text = "武器: " + weapon_data.display_name
	vbox.add_child(weapon_label)

	# 选择按钮
	var button := Button.new()
	button.text = "选择"
	button.pressed.connect(_on_character_selected.bind(character_id))
	vbox.add_child(button)

	return card


func _on_character_selected(character_id: String) -> void:
	var char_data: CharacterData = GameConfig.characters[character_id]
	GameData.current_character = character_id
	GameData.selected_weapon = char_data.default_weapon
	GameData.init_character(character_id)
	SceneManager.go_to(Enums.Scene.MAP_SELECT)
```

**Step 2: 重写角色选择场景**

替换 `scenes/ui/character_selection.tscn` 全部内容：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/character_selection.gd" id="1_xxxxx"]

[node name="root" type="Control"]
script = ExtResource("1_xxxxx")
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="TitleLabel" type="Label" parent="."]
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_top = 30.0
offset_bottom = 60.0
grow_horizontal = 2
text = "选择角色"
horizontal_alignment = 1

[node name="CharacterContainer" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -260.0
offset_top = -90.0
offset_right = 260.0
offset_bottom = 90.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 20
```

**Step 3: 运行全部测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部 PASS

**Step 4: 提交**

```bash
git add scripts/ui/character_selection.gd scenes/ui/character_selection.tscn
git commit -m "feat: 角色选择改为数据驱动卡片式布局，自动设置武器"
```

---

### Task 3: 删除武器选择场景并清理引用

**Files:**
- Delete: `scripts/ui/weapon_select.gd`
- Delete: `scenes/ui/weapon_select.tscn`
- Delete: `tests/unit/test_weapon_select.gd`
- Modify: `scripts/core/scene_manager.gd:6` (删除 weapon_select 条目)
- Modify: `scripts/core/enums.gd:16` (删除 WEAPON_SELECT 常量)

**Step 1: 删除文件**

```bash
git rm scripts/ui/weapon_select.gd scenes/ui/weapon_select.tscn tests/unit/test_weapon_select.gd
```

**Step 2: SceneManager 移除条目**

在 `scripts/core/scene_manager.gd` 删除第 6 行：
```gdscript
	"weapon_select":       "res://scenes/ui/weapon_select.tscn",
```

**Step 3: Enums 移除常量**

在 `scripts/core/enums.gd` 删除第 16 行：
```gdscript
	const WEAPON_SELECT = "weapon_select"
```

**Step 4: 运行全部测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部 PASS（test_weapon_select.gd 已删除不会运行）

**Step 5: 提交**

```bash
git add -A
git commit -m "refactor: 删除武器选择场景，清理相关引用"
```

---

### Task 4: 更新 GameData.reset() 默认武器逻辑

**Files:**
- Modify: `scripts/core/game_data.gd:55`

**Step 1: 修改 reset() 方法**

在 `scripts/core/game_data.gd` 的 `reset()` 方法中，将：

```gdscript
	selected_weapon = Enums.WeaponId.RIFLE
```

改为：

```gdscript
	# 从角色配置读取默认武器
	var char_data: CharacterData = GameConfig.characters[current_character]
	selected_weapon = char_data.default_weapon
```

**Step 2: 运行全部测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部 PASS

**Step 3: 提交**

```bash
git add scripts/core/game_data.gd
git commit -m "fix: GameData.reset() 从角色配置读取默认武器"
```

---

### Task 5: 更新 CLAUDE.md 场景流程文档

**Files:**
- Modify: `CLAUDE.md:32` (更新流程图)

**Step 1: 更新流程描述**

在 `CLAUDE.md` 将场景流程从：
```
start_menu → character_selection → weapon_select → map_select → main (战斗)
```
改为：
```
start_menu → character_selection → map_select → main (战斗)
```

同时从 UI 场景列表中移除 `weapon_select`。

**Step 2: 提交**

```bash
git add CLAUDE.md
git commit -m "docs: 更新场景流程，移除武器选择步骤"
```
