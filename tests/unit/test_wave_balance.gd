extends GutTest

func test_forest_has_12_waves():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_eq(waves.size(), 20, "Forest 应有 20 波")

func test_wave_numbers_sequential():
	var waves = GameConfig.get_waves_for_map("forest")
	for i in range(waves.size()):
		assert_eq(waves[i].wave_number, i + 1)

func test_boss_waves_at_4_8_12():
	var waves = GameConfig.get_waves_for_map("forest")
	var boss_wave_numbers := []
	for w: WaveData in waves:
		if w.is_boss_wave:
			boss_wave_numbers.append(w.wave_number)
	assert_eq(boss_wave_numbers.size(), 5, "应有 5 个 Boss 波")
	assert_has(boss_wave_numbers, 4, "第 4 波应为 Boss 波")
	assert_has(boss_wave_numbers, 8, "第 8 波应为 Boss 波")
	assert_has(boss_wave_numbers, 12, "第 12 波应为 Boss 波")
	assert_has(boss_wave_numbers, 15, "第 15 波应为 Boss 波")
	assert_has(boss_wave_numbers, 20, "第 20 波应为 Boss 波")

func test_boss_ids():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_eq(waves[3].boss_id, "boss_brute")
	assert_eq(waves[7].boss_id, "boss_summoner")
	assert_eq(waves[11].boss_id, "boss_guardian")
	assert_eq(waves[14].boss_id, "boss_guardian")
	assert_eq(waves[19].boss_id, "boss_guardian")

func test_all_waves_have_spawn_phases():
	var waves = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		assert_gt(w.spawn_phases.size(), 0, "波次 %d 应有分段配置" % w.wave_number)

func test_spawn_phases_duration_ratio_sum():
	var waves = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		var total_ratio: float = 0.0
		for phase: SpawnPhaseData in w.spawn_phases:
			total_ratio += phase.duration_ratio
		assert_almost_eq(total_ratio, 1.0, 0.01, "波次 %d 的 duration_ratio 之和应为 1.0" % w.wave_number)

func test_time_limit_increasing():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_lt(waves[0].time_limit, waves[19].time_limit, "后期波次时间应更长")

func test_elite_chance_progression():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_eq(waves[0].elite_chance, 0.0, "第 1 波不应有精英怪")
	var has_elite := false
	for w: WaveData in waves:
		if w.elite_chance > 0.0:
			has_elite = true
			break
	assert_true(has_elite, "后期波次应有精英怪")

func test_max_alive_enemies_increasing():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_lt(waves[0].max_alive_enemies, waves[19].max_alive_enemies, "后期波次 max_alive 应更大")
