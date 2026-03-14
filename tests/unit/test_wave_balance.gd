extends GutTest

func test_forest_has_20_waves():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_eq(waves.size(), 20, "Forest 应有 20 波")

func test_wave_numbers_sequential():
	var waves = GameConfig.get_waves_for_map("forest")
	for i in range(waves.size()):
		assert_eq(waves[i].wave_number, i + 1)

func test_wave_10_is_brute_boss():
	var waves = GameConfig.get_waves_for_map("forest")
	var w10 = waves[9]
	assert_true(w10.is_boss_wave)
	assert_eq(w10.boss_id, "boss_brute")

func test_wave_20_is_guardian_boss():
	var waves = GameConfig.get_waves_for_map("forest")
	var w20 = waves[19]
	assert_true(w20.is_boss_wave)
	assert_eq(w20.boss_id, "boss_guardian")

func test_enemy_count_progression():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_eq(waves[0].total_enemies, 20)
	assert_eq(waves[16].total_enemies, 85)

func test_elite_chance_progression():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_eq(waves[0].elite_chance, 0.0)
	assert_eq(waves[3].elite_chance, 0.0)
	assert_gt(waves[4].elite_chance, 0.0)

func test_spawn_interval_decreasing():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_gt(waves[0].spawn_interval, waves[19].spawn_interval)

func test_wave_9_and_19_are_breather_waves():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_lt(waves[8].total_enemies, waves[7].total_enemies)
	assert_lt(waves[18].total_enemies, waves[17].total_enemies)
