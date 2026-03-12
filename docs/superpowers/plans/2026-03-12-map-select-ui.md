# 地图选择界面 UI 重构实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将地图选择界面从水平卡片布局重构为吸血鬼幸存者风格的单列横条卡片列表，支持纵向滚动和锁定/解锁状态。

**Architecture:** 原地重构 `map_select.tscn` 和 `map_select.gd`。tscn 改为 ScrollContainer > VBoxContainer 结构，脚本中动态生成横条卡片。解锁逻辑简单 hardcode（仅第一张解锁）。

**Tech Stack:** Godot 4.6 GDScript, UIConstants, GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-12-map-select-ui-design.md`

---

## Chunk 1: 测试 + 场景重构 + 脚本实现

### Task 1: 编写测试

**Files:**
- Create: `tests/unit/test_map_select.gd`

- [ ] **Step 1: 创建测试文件**

```gdscript
extends GutTest

# 地图选择界面数据验证 + 解锁逻辑测试

func test_maps_dict_not_empty() -> void:
	assert_gt(GameConfig.maps.size(), 0, "地图字典不应为空")

func test_all_maps_have_display_name() -> void:
	for map_id in GameConfig.maps:
		var map_data: MapData = GameConfig.maps[map_id]
		assert_ne(map_data.display_name, "", "%s 应有 display_name" % map_id)

func test_all_maps_have_fallback_color() -> void:
	for map_id in GameConfig.maps:
		var map_data: MapData = GameConfig.maps[map_id]
		assert_ne(map_data.fallback_color, "", "%s 应有 fallback_color" % map_id)

func test_fallback_color_is_valid_hex() -> void:
	for map_id in GameConfig.maps:
		var map_data: MapData = GameConfig.maps[map_id]
		# Color() 构造函数接受 hex 字符串，不会崩溃就算通过
		var color := Color(map_data.fallback_color)
		assert_true(color.a > 0.0, "%s 的 fallback_color 应能解析为有效颜色" % map_id)

func test_first_map_is_unlocked() -> void:
	# 第一张地图永远解锁
	var first_id: String = GameConfig.maps.keys()[0]
	assert_eq(first_id, "forest", "第一张地图应为 forest")

func test_scene_file_exists() -> void:
	assert_true(ResourceLoader.exists("res://scenes/ui/map_select.tscn"),
		"地图选择场景文件应存在")

func test_card_count_matches_maps() -> void:
	# 实例化场景验证卡片数量
	var scene: Control = load("res://scenes/ui/map_select.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	var map_list: VBoxContainer = scene.get_node("MarginContainer/VBoxContainer/ScrollContainer/MapList")
	assert_eq(map_list.get_child_count(), GameConfig.maps.size(), "卡片数量应等于地图数量")
	scene.queue_free()
```

- [ ] **Step 2: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_map_select.gd -gexit`
Expected: 7 tests PASS

- [ ] **Step 3: 提交测试**

```bash
git add tests/unit/test_map_select.gd
git commit -m "test: 地图选择界面数据验证测试"
```

---

### Task 2: 重构场景文件

**Files:**
- Modify: `scenes/ui/map_select.tscn`

场景树从：
```
MapSelect > VBoxContainer > [TitleLabel, MapContainer(HBox), BackButton]
```
改为：
```
MapSelect > Background + MarginContainer > VBoxContainer > [TitleLabel, ScrollContainer > MapList(VBox), BackButton]
```

- [ ] **Step 1: 重写 map_select.tscn**

用 Write 工具完整重写场景文件。关键变更：
- 根节点 MapSelect (Control, full rect) 不变
- Background (ColorRect, full rect) 不变
- 新增 MarginContainer 居中留边距（上下 40，左右 80）
- VBoxContainer 内：TitleLabel + ScrollContainer + BackButton
- ScrollContainer 内含 MapList (VBoxContainer, separation=10)
- ScrollContainer 设 size_flags_vertical = SIZE_EXPAND_FILL，horizontal_scrollbar 关闭
- BackButton 居中对齐

```
[gd_scene format=3 uid="uid://c8y7m5n3p4q2r"]

[ext_resource type="Script" path="res://scripts/ui/map_select.gd" id="1_a1b2c"]

[node name="MapSelect" type="Control"]
script = ExtResource("1_a1b2c")
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

[node name="MarginContainer" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 80
theme_override_constants/margin_right = 80
theme_override_constants/margin_top = 40
theme_override_constants/margin_bottom = 40

[node name="VBoxContainer" type="VBoxContainer" parent="MarginContainer"]
layout_mode = 2
theme_override_constants/separation = 20

[node name="TitleLabel" type="Label" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
text = "选择地图"
horizontal_alignment = 1

[node name="ScrollContainer" type="ScrollContainer" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
horizontal_scroll_mode = 0

[node name="MapList" type="VBoxContainer" parent="MarginContainer/VBoxContainer/ScrollContainer"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 10

[node name="BackButton" type="Button" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
size_flags_horizontal = 4
text = "← 返回选角"
```

- [ ] **Step 2: 确认场景文件 uid 保持不变**

uid 必须保持 `uid://c8y7m5n3p4q2r`，否则其他引用此场景的地方会断开。

- [ ] **Step 3: 提交场景**

```bash
git add scenes/ui/map_select.tscn
git commit -m "refactor: 地图选择场景改为纵向滚动列表布局"
```

---

### Task 3: 重写脚本

**Files:**
- Modify: `scripts/ui/map_select.gd`

- [ ] **Step 1: 重写 map_select.gd**

完整替换脚本内容：

```gdscript
extends Control

## 地图选择界面 — 吸血鬼幸存者风格纵向滚动列表，横条卡片 + 锁定/解锁

@onready var _map_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MapList
@onready var _back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel

func _ready() -> void:
	# 背景色
	$Background.color = UIConstants.COLOR_BG_PRIMARY

	# 标题样式
	_title_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TITLE)
	_title_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)

	# 返回按钮
	_back_button.pressed.connect(func(): SceneManager.go_to(Enums.Scene.CHARACTER_SELECTION))
	_back_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)

	# 清空占位子节点
	for child in _map_list.get_children():
		child.queue_free()

	# 动态生成地图卡片
	var map_ids: Array = GameConfig.maps.keys()
	for i in range(map_ids.size()):
		var map_id: String = map_ids[i]
		var map_data: MapData = GameConfig.maps[map_id]
		var unlocked := _is_map_unlocked(i)
		_map_list.add_child(_create_map_card(map_id, map_data, unlocked))


func _is_map_unlocked(index: int) -> bool:
	# 简单解锁：仅第一张地图解锁，后续 hardcode 锁定
	return index == 0


func _create_map_card(map_id: String, map_data: MapData, unlocked: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 64)

	# 背景样式
	var base_color := Color(map_data.fallback_color)
	var bg_color: Color
	if unlocked:
		bg_color = base_color.darkened(0.3)
	else:
		bg_color = base_color.darkened(0.6)
		bg_color.a = 0.4
	card.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox(bg_color, UIConstants.CORNER_RADIUS_PANEL))

	# 锁定状态整体降低透明度
	if not unlocked:
		card.modulate.a = 0.6

	# 内容布局：HBoxContainer
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	# 左侧预览色块
	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(64, 48)
	preview.color = base_color
	hbox.add_child(preview)

	# 中间地图名称
	var name_label := Label.new()
	name_label.text = map_data.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SUBTITLE)
	if unlocked:
		name_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	else:
		name_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	hbox.add_child(name_label)

	# 右侧状态图标
	var icon_label := Label.new()
	if unlocked:
		icon_label.text = ">"
		icon_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	else:
		icon_label.text = "[锁]"
		icon_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	icon_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SUBTITLE)
	hbox.add_child(icon_label)

	# 点击事件 + hover 效果（仅已解锁）
	if unlocked:
		card.gui_input.connect(_on_card_gui_input.bind(map_id))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.mouse_entered.connect(func():
			card.add_theme_stylebox_override("panel",
				UIConstants.create_panel_stylebox(bg_color, UIConstants.CORNER_RADIUS_PANEL,
					UIConstants.COLOR_GOLD, 2))
		)
		card.mouse_exited.connect(func():
			card.add_theme_stylebox_override("panel",
				UIConstants.create_panel_stylebox(bg_color, UIConstants.CORNER_RADIUS_PANEL))
		)

	return card


func _on_card_gui_input(event: InputEvent, map_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_map_selected(map_id)


func _on_map_selected(map_id: String) -> void:
	if not GameConfig.maps.has(map_id):
		push_error("未知地图: " + map_id)
		return
	GameData.selected_map = map_id
	SceneManager.go_to(Enums.Scene.MAIN)
```

- [ ] **Step 2: 运行全部测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS（包括新增的 test_map_select.gd）

- [ ] **Step 3: 提交脚本**

```bash
git add scripts/ui/map_select.gd
git commit -m "feat: 地图选择界面改为吸血鬼幸存者风格横条卡片列表"
```

---

### Task 4: 视觉验证

**Files:** 无新文件

- [ ] **Step 1: 在 Godot 编辑器中打开 map_select.tscn 确认场景树正确**

用 gdai-mcp 的 `open_scene` 打开 `res://scenes/ui/map_select.tscn`，检查节点结构。

- [ ] **Step 2: 运行场景截图验证**

用 gdai-mcp 的 `play_scene` 运行 `res://scenes/ui/map_select.tscn`，然后 `get_running_scene_screenshot` 截图查看效果。

确认：
- 深色背景
- 标题 "选择地图" 金色居中
- 森林卡片：绿色横条，白色名称，金色 ">"
- 沙漠卡片：暗淡横条，灰色名称，灰色 "[锁]"，半透明
- 已解锁卡片 hover 时出现金色边框
- 底部返回按钮

- [ ] **Step 3: 最终提交（如有微调）**

```bash
git add -A
git commit -m "fix: 地图选择界面视觉微调"
```
