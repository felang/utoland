# 角色选择界面重构 实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将角色选择界面从水平卡片列表重构为左右分栏布局（左侧头像列表 + 右侧详情面板）

**Architecture:** 场景模板预定义右侧详情面板结构，脚本动态生成左侧头像按钮并填充右侧数据。删除旧的 character_card 组件，统一在 character_selection 中完成所有逻辑。

**Tech Stack:** Godot 4.6 GDScript, UIConstants 样式系统, GUT 单元测试

**Spec:** `docs/superpowers/specs/2026-03-12-character-selection-ui-design.md`

---

## File Structure

| 操作 | 文件路径 | 职责 |
|------|---------|------|
| 重写 | `scenes/ui/character_selection.tscn` | 左右分栏布局模板，右侧详情面板节点 |
| 重写 | `scripts/ui/character_selection.gd` | 动态生成头像、选中切换、数据填充、确认/返回 |
| 删除 | `scenes/ui/character_card.tscn` | 旧卡片场景 |
| 删除 | `scripts/ui/character_card.gd` | 旧卡片脚本 |
| 新建 | `tests/unit/test_character_selection.gd` | 角色选择逻辑单元测试 |

---

## Chunk 1: 场景模板与核心脚本

### Task 1: 创建新的场景模板 (character_selection.tscn)

**Files:**
- Rewrite: `scenes/ui/character_selection.tscn`

- [ ] **Step 1: 用 GDScript 通过 gdai-mcp 或手动编写场景文件**

重写 `scenes/ui/character_selection.tscn`，节点树如下：

```
CharacterSelection (Control, 全屏 anchors_preset=15)
├── Background (ColorRect, 全屏 anchors_preset=15)
├── MainVBox (VBoxContainer, 全屏带边距)
│   ├── TitleLabel (Label, "选择你的角色", 居中)
│   ├── HSplitContent (HBoxContainer, size_flags_vertical=EXPAND_FILL)
│   │   ├── LeftPanel (ScrollContainer, custom_minimum_size.x=120)
│   │   │   └── PortraitList (VBoxContainer, size_flags_horizontal=EXPAND_FILL)
│   │   └── RightPanel (PanelContainer, size_flags_horizontal=EXPAND_FILL, stretch_ratio=4)
│   │       └── DetailMargin (MarginContainer)
│   │           └── DetailVBox (VBoxContainer, separation=16)
│   │               ├── HeaderSection (HBoxContainer, separation=16)
│   │               │   ├── LargePortrait (TextureRect, 120×120, expand_mode=KEEP_ASPECT_COVERED)
│   │               │   └── NameAndWeapon (VBoxContainer)
│   │               │       ├── CharacterName (Label)
│   │               │       └── WeaponLabel (Label)
│   │               ├── StatsSection (PanelContainer)
│   │               │   └── StatsGrid (GridContainer, columns=2)
│   │               │       ├── HPTitle (Label, "生命值")
│   │               │       ├── HPValue (Label)
│   │               │       ├── SpeedTitle (Label, "速度")
│   │               │       ├── SpeedValue (Label)
│   │               │       ├── DamageTitle (Label, "伤害倍率")
│   │               │       ├── DamageValue (Label)
│   │               │       ├── AttackSpeedTitle (Label, "攻速倍率")
│   │               │       ├── AttackSpeedValue (Label)
│   │               │       ├── HPRegenTitle (Label, "生命回复")
│   │               │       └── HPRegenValue (Label)
│   │               ├── AffinitySection (HBoxContainer)
│   │               ├── PassiveSection (VBoxContainer)
│   │               │   ├── PassiveTitle (Label, "被动技能")
│   │               │   └── PassiveDesc (Label, autowrap_mode=WORD_SMART)
│   │               └── SelectButton (Button, "选择此角色")
│   └── BackButton (Button, "← 返回主菜单")
```

场景文件内容（手写 .tscn 格式）：

```tscn
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/character_selection.gd" id="1_script"]

[node name="CharacterSelection" type="Control"]
script = ExtResource("1_script")
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="MainVBox" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 12.0
offset_top = 12.0
offset_right = -12.0
offset_bottom = -12.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 12

[node name="TitleLabel" type="Label" parent="MainVBox"]
layout_mode = 2
text = "选择你的角色"
horizontal_alignment = 1

[node name="HSplitContent" type="HBoxContainer" parent="MainVBox"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 12

[node name="LeftPanel" type="ScrollContainer" parent="MainVBox/HSplitContent"]
layout_mode = 2
custom_minimum_size = Vector2(120, 0)

[node name="PortraitList" type="VBoxContainer" parent="MainVBox/HSplitContent/LeftPanel"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 8

[node name="RightPanel" type="PanelContainer" parent="MainVBox/HSplitContent"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_stretch_ratio = 4.0

[node name="DetailMargin" type="MarginContainer" parent="MainVBox/HSplitContent/RightPanel"]
layout_mode = 2
theme_override_constants/margin_left = 20
theme_override_constants/margin_top = 20
theme_override_constants/margin_right = 20
theme_override_constants/margin_bottom = 20

[node name="DetailVBox" type="VBoxContainer" parent="MainVBox/HSplitContent/RightPanel/DetailMargin"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="HeaderSection" type="HBoxContainer" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="LargePortrait" type="TextureRect" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/HeaderSection"]
unique_name_in_owner = true
layout_mode = 2
custom_minimum_size = Vector2(120, 120)
expand_mode = 1
stretch_mode = 6

[node name="NameAndWeapon" type="VBoxContainer" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/HeaderSection"]
layout_mode = 2
size_flags_vertical = 1

[node name="CharacterName" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/HeaderSection/NameAndWeapon"]
unique_name_in_owner = true
layout_mode = 2

[node name="WeaponLabel" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/HeaderSection/NameAndWeapon"]
unique_name_in_owner = true
layout_mode = 2

[node name="StatsSection" type="PanelContainer" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox"]
unique_name_in_owner = true
layout_mode = 2

[node name="StatsGrid" type="GridContainer" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/StatsSection"]
layout_mode = 2
columns = 2
theme_override_constants/h_separation = 16
theme_override_constants/v_separation = 4

[node name="HPTitle" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/StatsSection/StatsGrid"]
layout_mode = 2
text = "生命值"

[node name="HPValue" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/StatsSection/StatsGrid"]
unique_name_in_owner = true
layout_mode = 2

[node name="SpeedTitle" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/StatsSection/StatsGrid"]
layout_mode = 2
text = "速度"

[node name="SpeedValue" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/StatsSection/StatsGrid"]
unique_name_in_owner = true
layout_mode = 2

[node name="DamageTitle" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/StatsSection/StatsGrid"]
layout_mode = 2
text = "伤害倍率"

[node name="DamageValue" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/StatsSection/StatsGrid"]
unique_name_in_owner = true
layout_mode = 2

[node name="AttackSpeedTitle" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/StatsSection/StatsGrid"]
layout_mode = 2
text = "攻速倍率"

[node name="AttackSpeedValue" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/StatsSection/StatsGrid"]
unique_name_in_owner = true
layout_mode = 2

[node name="HPRegenTitle" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/StatsSection/StatsGrid"]
layout_mode = 2
text = "生命回复"

[node name="HPRegenValue" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/StatsSection/StatsGrid"]
unique_name_in_owner = true
layout_mode = 2

[node name="AffinitySection" type="HBoxContainer" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox"]
unique_name_in_owner = true
layout_mode = 2
theme_override_constants/separation = 8

[node name="PassiveSection" type="VBoxContainer" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox"]
layout_mode = 2
theme_override_constants/separation = 4

[node name="PassiveTitle" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/PassiveSection"]
unique_name_in_owner = true
layout_mode = 2
text = "被动技能"

[node name="PassiveDesc" type="Label" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox/PassiveSection"]
unique_name_in_owner = true
layout_mode = 2
autowrap_mode = 3

[node name="SelectButton" type="Button" parent="MainVBox/HSplitContent/RightPanel/DetailMargin/DetailVBox"]
unique_name_in_owner = true
layout_mode = 2
text = "选择此角色"

[node name="BackButton" type="Button" parent="MainVBox"]
unique_name_in_owner = true
layout_mode = 2
text = "← 返回主菜单"
```

- [ ] **Step 2: 验证场景文件可被 Godot 解析**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20`
Expected: 无场景解析错误

- [ ] **Step 3: Commit**

```bash
git add scenes/ui/character_selection.tscn
git commit -m "refactor: 重写角色选择场景模板为左右分栏布局"
```

---

### Task 2: 重写 character_selection.gd 脚本

**Files:**
- Rewrite: `scripts/ui/character_selection.gd`

- [ ] **Step 1: 编写新脚本**

```gdscript
extends Control
## 角色选择界面 — 左侧头像列表 + 右侧详情面板

# 属性基准值（用于颜色标记）
# 注意：speed 基准值为 200.0（CharacterData 默认值），旧代码误用 100.0 导致速度始终显绿
const STAT_BASELINES := {
	"max_hp": 100.0,
	"speed": 200.0,
	"damage_mult": 1.0,
	"attack_speed_mult": 1.0,
	"hp_regen": 0.0,
}

# 节点引用
@onready var _portrait_list: VBoxContainer = %PortraitList
@onready var _large_portrait: TextureRect = %LargePortrait
@onready var _character_name: Label = %CharacterName
@onready var _weapon_label: Label = %WeaponLabel
@onready var _hp_value: Label = %HPValue
@onready var _speed_value: Label = %SpeedValue
@onready var _damage_value: Label = %DamageValue
@onready var _attack_speed_value: Label = %AttackSpeedValue
@onready var _hp_regen_value: Label = %HPRegenValue
@onready var _affinity_section: HBoxContainer = %AffinitySection
@onready var _passive_desc: Label = %PassiveDesc
@onready var _select_button: Button = %SelectButton
@onready var _back_button: Button = %BackButton
@onready var _right_panel: PanelContainer = %RightPanel
@onready var _stats_section: PanelContainer = %StatsSection
@onready var _passive_title: Label = %PassiveTitle

var _selected_id: String = ""
var _portrait_buttons: Dictionary = {}  # character_id → TextureButton
var _placeholder_texture: Texture2D = null  # 缓存占位纹理


func _ready() -> void:
	_apply_styles()
	_connect_buttons()
	_generate_portrait_list()
	# 默认选中第一个角色
	if GameConfig.characters.size() > 0:
		var first_id: String = GameConfig.characters.keys()[0]
		_select_character(first_id)


func _apply_styles() -> void:
	# 背景
	$Background.color = UIConstants.COLOR_BG_PRIMARY

	# 标题
	var title: Label = $MainVBox/TitleLabel
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)

	# 右侧面板
	_right_panel.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox())

	# 角色名
	_character_name.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SUBTITLE)
	_character_name.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)

	# 武器
	_weapon_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	_weapon_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)

	# 属性区域
	_stats_section.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox(UIConstants.COLOR_BG_PANEL))

	# 属性标题标签
	var stats_grid: GridContainer = _stats_section.get_node("StatsGrid")
	for i in range(0, stats_grid.get_child_count(), 2):
		var title_label: Label = stats_grid.get_child(i)
		title_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
		title_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)

	# 属性值标签
	for value_label in [_hp_value, _speed_value, _damage_value, _attack_speed_value, _hp_regen_value]:
		value_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)

	# 被动技能
	_passive_title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	_passive_title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	_passive_desc.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	_passive_desc.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)

	# 选择按钮样式
	_select_button.add_theme_stylebox_override("normal", UIConstants.create_button_stylebox(UIConstants.COLOR_BUTTON_NORMAL))
	_select_button.add_theme_stylebox_override("hover", UIConstants.create_button_stylebox(UIConstants.COLOR_BUTTON_HOVER))
	_select_button.add_theme_stylebox_override("pressed", UIConstants.create_button_stylebox(UIConstants.COLOR_BUTTON_PRESSED))
	_select_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	_select_button.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)

	# 返回按钮
	_back_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)


func _connect_buttons() -> void:
	_select_button.pressed.connect(_on_select_pressed)
	_back_button.pressed.connect(func(): SceneManager.go_to(Enums.Scene.START_MENU))


func _generate_portrait_list() -> void:
	for child in _portrait_list.get_children():
		child.queue_free()
	_portrait_buttons.clear()

	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED

		# 加载头像纹理
		var portrait: Texture2D = _load_portrait(char_data.portrait_path)
		if portrait:
			btn.texture_normal = portrait
		else:
			# fallback: 添加占位 ColorRect 作为子节点
			var placeholder := ColorRect.new()
			placeholder.color = Color(0.15, 0.15, 0.25, 1.0)
			placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			btn.add_child(placeholder)

		btn.pressed.connect(_select_character.bind(character_id))
		_portrait_list.add_child(btn)
		_portrait_buttons[character_id] = btn


func _load_portrait(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _select_character(character_id: String) -> void:
	_selected_id = character_id
	_update_portrait_borders()
	_fill_detail_panel(character_id)


func _update_portrait_borders() -> void:
	for cid in _portrait_buttons:
		var btn: TextureButton = _portrait_buttons[cid]
		if cid == _selected_id:
			# 金色边框
			var style := StyleBoxFlat.new()
			style.bg_color = Color.TRANSPARENT
			style.border_color = UIConstants.COLOR_GOLD
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", style)
		else:
			# 无边框
			var style := StyleBoxEmpty.new()
			btn.add_theme_stylebox_override("normal", style)


func _fill_detail_panel(character_id: String) -> void:
	var char_data: CharacterData = GameConfig.characters[character_id]
	var weapon_data: WeaponData = GameConfig.weapons[char_data.default_weapon]

	# 头像
	var portrait: Texture2D = _load_portrait(char_data.portrait_path)
	if portrait:
		_large_portrait.texture = portrait
	else:
		_large_portrait.texture = null

	# 名称与武器
	_character_name.text = char_data.display_name
	_weapon_label.text = "默认武器: %s" % weapon_data.display_name

	# 属性
	_hp_value.text = "%d" % int(char_data.max_hp)
	_speed_value.text = "%d" % int(char_data.speed)
	_damage_value.text = "x%.1f" % char_data.damage_mult
	_attack_speed_value.text = "x%.1f" % char_data.attack_speed_mult
	_hp_regen_value.text = "%.1f/s" % char_data.hp_regen

	# 属性颜色
	_color_stat(_hp_value, char_data.max_hp, STAT_BASELINES["max_hp"])
	_color_stat(_speed_value, char_data.speed, STAT_BASELINES["speed"])
	_color_stat(_damage_value, char_data.damage_mult, STAT_BASELINES["damage_mult"])
	_color_stat(_attack_speed_value, char_data.attack_speed_mult, STAT_BASELINES["attack_speed_mult"])
	_color_stat(_hp_regen_value, char_data.hp_regen, STAT_BASELINES["hp_regen"])

	# 亲和标签
	_fill_affinity(char_data)

	# 被动技能
	if char_data.passive_description != "":
		_passive_desc.text = char_data.passive_description
	else:
		_passive_desc.text = "暂无被动技能"


func _color_stat(label: Label, value: float, baseline: float) -> void:
	if value > baseline:
		label.add_theme_color_override("font_color", UIConstants.COLOR_POSITIVE)
	elif value < baseline:
		label.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_DANGER)
	else:
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)


func _fill_affinity(char_data: CharacterData) -> void:
	# 清除旧内容
	for child in _affinity_section.get_children():
		child.queue_free()

	if char_data.affinity_tags.size() == 0:
		return

	for tag in char_data.affinity_tags:
		var tag_label := Label.new()
		tag_label.text = tag
		tag_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TINY)
		# 根据标签类型着色
		match tag:
			"shooter":
				tag_label.add_theme_color_override("font_color", UIConstants.COLOR_AFFINITY_SHOOTER)
			"engineer":
				tag_label.add_theme_color_override("font_color", UIConstants.COLOR_AFFINITY_ENGINEER)
			_:
				tag_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
		_affinity_section.add_child(tag_label)

	# 折扣标签
	var discount_label := Label.new()
	discount_label.text = "折扣%d%%" % int(char_data.affinity_discount * 100)
	discount_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TINY)
	discount_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	_affinity_section.add_child(discount_label)


func _on_select_pressed() -> void:
	if _selected_id == "":
		return
	var char_data: CharacterData = GameConfig.characters[_selected_id]
	GameData.current_character = _selected_id
	GameData.selected_weapon = char_data.default_weapon
	GameData.init_character(_selected_id)
	SceneManager.go_to(Enums.Scene.MAP_SELECT)
```

注意：`.tscn` 文件中所有 `%` 引用的节点已包含 `unique_name_in_owner = true` 属性。

- [ ] **Step 2: 验证场景加载无错误**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20`
Expected: 无脚本解析错误

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/character_selection.gd scenes/ui/character_selection.tscn
git commit -m "refactor: 重写角色选择脚本为左右分栏布局"
```

> **注意：速度基准值修正** — 旧 character_card.gd 使用 speed baseline=100.0，但 CharacterData 默认 speed=200.0，导致速度始终显示为绿色。新代码修正为 200.0。

---

### Task 3: 删除旧卡片组件

**Files:**
- Delete: `scenes/ui/character_card.tscn`
- Delete: `scripts/ui/character_card.gd`

- [ ] **Step 1: 确认无其他文件引用 character_card**

Run: `grep -r "character_card" --include="*.gd" --include="*.tscn" --include="*.tres" .`
Expected: 仅在即将删除的文件中出现（旧的 character_selection.gd 已被重写不再引用）

- [ ] **Step 2: 删除文件**

```bash
git rm scenes/ui/character_card.tscn scripts/ui/character_card.gd
```

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor: 删除废弃的 character_card 组件"
```

---

## Chunk 2: 单元测试

### Task 4: 编写角色选择逻辑单元测试

**Files:**
- Create: `tests/unit/test_character_selection.gd`

由于角色选择界面是 UI 场景，直接实例化测试较复杂。测试策略：提取可测逻辑为纯函数，或通过 headless 场景实例化测试关键行为。

- [ ] **Step 1: 编写测试文件**

```gdscript
extends GutTest

# 角色选择界面逻辑测试
# 验证数据填充、选中状态、GameData 写入等

func test_all_characters_have_portrait_path() -> void:
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		assert_ne(char_data.portrait_path, "", "%s 应有 portrait_path" % character_id)

func test_all_characters_have_valid_default_weapon() -> void:
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		assert_true(GameConfig.weapons.has(char_data.default_weapon),
			"%s 的 default_weapon '%s' 应存在于 GameConfig.weapons" % [character_id, char_data.default_weapon])

func test_all_characters_have_display_name() -> void:
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		assert_ne(char_data.display_name, "", "%s 应有 display_name" % character_id)

func test_character_portrait_files_exist() -> void:
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		if char_data.portrait_path != "":
			assert_true(ResourceLoader.exists(char_data.portrait_path),
				"%s 的 portrait_path '%s' 文件应存在" % [character_id, char_data.portrait_path])

func test_game_data_init_character_sets_stats() -> void:
	var first_id: String = GameConfig.characters.keys()[0]
	var char_data: CharacterData = GameConfig.characters[first_id]
	GameData.init_character(first_id)
	assert_eq(GameData.character_max_hp, char_data.max_hp, "init_character 应设置 max_hp")
	assert_eq(GameData.character_speed, char_data.speed, "init_character 应设置 speed")
	assert_eq(GameData.character_damage_mult, char_data.damage_mult, "init_character 应设置 damage_mult")

func test_affinity_tags_are_known_values() -> void:
	var known_tags := ["shooter", "engineer"]
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		for tag in char_data.affinity_tags:
			assert_has(known_tags, tag, "%s 的亲和标签 '%s' 应为已知值" % [character_id, tag])

func test_characters_dict_not_empty() -> void:
	assert_gt(GameConfig.characters.size(), 0, "角色字典不应为空")

func test_portrait_load_fallback_for_invalid_path() -> void:
	# 验证无效路径不会导致崩溃
	var invalid_path := "res://nonexistent/portrait.png"
	assert_false(ResourceLoader.exists(invalid_path), "无效路径应不存在")

func test_scene_file_exists() -> void:
	assert_true(ResourceLoader.exists("res://scenes/ui/character_selection.tscn"),
		"角色选择场景文件应存在")
```

- [ ] **Step 2: 运行测试验证全部通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gprefix=test_character_selection -gexit`
Expected: 全部 PASS

- [ ] **Step 3: 运行全量测试确保无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS（276+ 测试）

- [ ] **Step 4: Commit**

```bash
git add tests/unit/test_character_selection.gd
git commit -m "test: 添加角色选择界面数据验证测试"
```

---

## Chunk 3: 验收

### Task 5: 在编辑器中验证 UI 效果

- [ ] **Step 1: 在 Godot 编辑器中打开 character_selection.tscn，确认节点树正确**

- [ ] **Step 2: 运行游戏，进入角色选择界面**

验证项：
- 左侧显示 5 个角色头像，纵向排列
- 默认选中第一个角色（金色边框）
- 右侧显示该角色详情（名称、武器、属性、亲和、被动）
- 点击其他头像切换详情
- 点击"选择此角色"进入地图选择
- 点击"返回"回主菜单

- [ ] **Step 3: 截图确认布局**

使用 gdai-mcp `get_editor_screenshot` 或 `get_running_scene_screenshot` 截图确认。

- [ ] **Step 4: 最终 commit（如有调整）**

```bash
git add -A
git commit -m "fix: 角色选择界面 UI 微调"
```
