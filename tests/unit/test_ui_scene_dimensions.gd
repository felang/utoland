extends GutTest

func _control_size(node: Control) -> Vector2:
	return Vector2(node.offset_right - node.offset_left, node.offset_bottom - node.offset_top)

func test_map_select_cards_fit_640x360():
	var scene = load("res://scenes/ui/map_select.tscn").instantiate()
	add_child_autofree(scene)
	var forest_btn: Button = scene.get_node("VBoxContainer/MapCardsContainer/ForestCard/ForestButton")
	var desert_btn: Button = scene.get_node("VBoxContainer/MapCardsContainer/DesertCard/DesertButton")
	assert_eq(forest_btn.custom_minimum_size, Vector2(240, 140))
	assert_eq(desert_btn.custom_minimum_size, Vector2(240, 140))

func test_result_panel_and_buttons_fit_640x360():
	var scene = load("res://scenes/ui/result.tscn").instantiate()
	add_child_autofree(scene)
	var panel: Control = scene.get_node("VBoxContainer")
	assert_eq(_control_size(panel), Vector2(320, 220))
	assert_eq(scene.get_node("VBoxContainer/RestartButton").custom_minimum_size, Vector2(160, 36))
	assert_eq(scene.get_node("VBoxContainer/QuitButton").custom_minimum_size, Vector2(160, 36))

func test_shop_main_panel_fits_640x360():
	var scene = load("res://scenes/ui/shop.tscn").instantiate()
	add_child_autofree(scene)
	var panel: Control = scene.get_node("MainPanel")
	assert_eq(_control_size(panel), Vector2(500, 380))

func test_start_menu_button_uses_standard_size():
	var scene = load("res://scenes/ui/start_menu.tscn").instantiate()
	add_child_autofree(scene)
	var start_btn: Button = scene.get_node("CenterContainer/VBoxContainer/StartButton")
	assert_eq(start_btn.custom_minimum_size, Vector2(200, 44))
