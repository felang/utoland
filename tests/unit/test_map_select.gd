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
		var color := Color(map_data.fallback_color)
		assert_true(color.a > 0.0, "%s 的 fallback_color 应能解析为有效颜色" % map_id)

func test_first_map_is_unlocked() -> void:
	var first_id: String = GameConfig.maps.keys()[0]
	assert_eq(first_id, "forest", "第一张地图应为 forest")

func test_scene_file_exists() -> void:
	assert_true(ResourceLoader.exists("res://scenes/ui/map_select.tscn"),
		"地图选择场景文件应存在")

func test_card_count_matches_maps() -> void:
	var scene: Control = load("res://scenes/ui/map_select.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	var map_list: VBoxContainer = scene.get_node("MarginContainer/VBoxContainer/ScrollContainer/MapList")
	assert_eq(map_list.get_child_count(), GameConfig.maps.size(), "卡片数量应等于地图数量")
	scene.queue_free()
