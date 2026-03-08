extends Control

## 地图选择界面 — 数据驱动，根据 GameConfig.maps 动态生成地图卡片

@onready var _map_container: HBoxContainer = $VBoxContainer/MapContainer
@onready var _back_button: Button = $VBoxContainer/BackButton

func _ready() -> void:
	# 背景色
	$Background.color = UIConstants.COLOR_BG_PRIMARY

	# 标题样式
	$VBoxContainer/TitleLabel.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TITLE)
	$VBoxContainer/TitleLabel.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)

	# 返回按钮
	_back_button.pressed.connect(func(): SceneManager.go_to(Enums.Scene.CHARACTER_SELECTION))
	_back_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)

	# 清空占位子节点
	for child in _map_container.get_children():
		child.queue_free()

	# 根据配置动态生成地图卡片
	for map_id in GameConfig.maps:
		var map_data: MapData = GameConfig.maps[map_id]
		_map_container.add_child(_create_map_card(map_id, map_data))


func _create_map_card(map_id: String, map_data: MapData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 160)
	card.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox())

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# 预览色块
	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(170, 80)
	preview.color = map_data.fallback_color
	vbox.add_child(preview)

	# 地图名称
	var name_label := Label.new()
	name_label.text = map_data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SUBTITLE)
	name_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	vbox.add_child(name_label)

	# 选择按钮
	var button := Button.new()
	button.text = "选择"
	button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	button.pressed.connect(_on_map_selected.bind(map_id))
	vbox.add_child(button)

	return card


func _on_map_selected(map_id: String) -> void:
	if not GameConfig.maps.has(map_id):
		push_error("未知地图: " + map_id)
		return
	GameData.selected_map = map_id
	SceneManager.go_to(Enums.Scene.MAIN)
