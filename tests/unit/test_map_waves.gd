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
