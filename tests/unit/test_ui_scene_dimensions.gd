extends GutTest

func _control_size(node: Control) -> Vector2:
	return Vector2(node.offset_right - node.offset_left, node.offset_bottom - node.offset_top)

func test_map_select_cards_fit_640x360():
	# 数据驱动：卡片由 _ready() 动态生成到 MapContainer
	var scene = load("res://scenes/ui/map_select.tscn").instantiate()
	add_child_autofree(scene)
	# 等待 _ready() 执行完成
	await get_tree().process_frame
	var container: HBoxContainer = scene.get_node("VBoxContainer/MapContainer")
	assert_not_null(container, "MapContainer 应存在")
	# 应为每个 GameConfig.maps 生成一个 PanelContainer 卡片
	var card_count := 0
	for child in container.get_children():
		if child is PanelContainer:
			assert_eq(child.custom_minimum_size, Vector2(200, 160), "地图卡片尺寸应为 200x160")
			card_count += 1
	assert_eq(card_count, GameConfig.maps.size(), "卡片数量应与地图配置一致")

func test_result_panel_and_buttons_fit_640x360():
	var scene = load("res://scenes/ui/result.tscn").instantiate()
	add_child_autofree(scene)
	var vbox: VBoxContainer = scene.get_node("CenterContainer/VBoxContainer")
	assert_not_null(vbox, "VBoxContainer 应存在")
	assert_eq(vbox.custom_minimum_size, Vector2(400, 0), "VBox 最小宽度应为 400")
	var restart_btn: Button = scene.get_node("CenterContainer/VBoxContainer/ButtonRow/RestartButton")
	var menu_btn: Button = scene.get_node("CenterContainer/VBoxContainer/ButtonRow/MenuButton")
	assert_eq(restart_btn.custom_minimum_size, Vector2(140, 36))
	assert_eq(menu_btn.custom_minimum_size, Vector2(140, 36))

func test_shop_main_panel_fills_viewport():
	var scene = load("res://scenes/ui/shop.tscn").instantiate()
	add_child_autofree(scene)
	var panel: Control = scene.get_node("MainPanel")
	# MainPanel 使用全屏锚点 + 左右边距，不再使用固定尺寸
	assert_eq(panel.anchor_right, 1.0, "MainPanel 应使用全屏锚点")
	assert_eq(panel.anchor_bottom, 1.0, "MainPanel 应使用全屏锚点")

func test_start_menu_button_uses_standard_size():
	var scene = load("res://scenes/ui/start_menu.tscn").instantiate()
	add_child_autofree(scene)
	var start_btn: Button = scene.get_node("CenterContainer/VBoxContainer/StartButton")
	assert_eq(start_btn.custom_minimum_size, Vector2(200, 44))
