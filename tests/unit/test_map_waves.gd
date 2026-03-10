extends GutTest

func test_map_data_has_wave_count():
	var md := MapData.new()
	assert_true("wave_count" in md, "MapData 应有 wave_count 字段")
	assert_eq(md.wave_count, 10)

func test_game_config_loads_waves_for_map():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	assert_gt(waves.size(), 0, "森林地图应有波次配置")
	for w in waves:
		assert_true(w is WaveData, "每项应为 WaveData")

func test_game_config_waves_sorted():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for i in range(waves.size() - 1):
		assert_lt(waves[i].wave_number, waves[i + 1].wave_number, "波次应按 wave_number 排序")

func test_game_config_fallback_for_unknown_map():
	var waves: Array = GameConfig.get_waves_for_map("nonexistent")
	# 应返回默认 waves 数组
	assert_gt(waves.size(), 0, "未知地图应返回默认波次")

func test_waves_by_map_has_forest():
	assert_true(GameConfig.waves_by_map.has("forest"), "waves_by_map 应包含 forest")

func test_map_data_has_map_scene_field():
	var md := MapData.new()
	assert_true("map_scene" in md, "MapData 应有 map_scene 字段")
	assert_eq(md.map_scene, "", "map_scene 默认值应为空字符串")

func test_forest_map_scene_configured():
	var md: MapData = GameConfig.maps.get("forest")
	assert_not_null(md, "forest MapData 应存在")
	assert_ne(md.map_scene, "", "forest.tres 应配置 map_scene 路径")

func test_desert_map_scene_configured():
	var md: MapData = GameConfig.maps.get("desert")
	assert_not_null(md, "desert MapData 应存在")
	assert_ne(md.map_scene, "", "desert.tres 应配置 map_scene 路径")

func test_forest_map_scene_file_exists():
	var md: MapData = GameConfig.maps.get("forest")
	# FileAccess.file_exists 支持 res:// 路径，在 headless 模式下直接检查文件系统
	assert_true(FileAccess.file_exists(md.map_scene), "forest 地图场景文件应存在于磁盘")
