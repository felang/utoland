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
	UIUtils.setup_button_hover(_back_button)

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
	PlayerState.selected_map = map_id
	SceneManager.go_to(Enums.Scene.MAIN)
