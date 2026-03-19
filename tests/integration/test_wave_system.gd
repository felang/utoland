extends GutTest

func test_forest_wave_count():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	assert_eq(waves.size(), 12, "Forest 地图应有 12 波")

func test_waves_sorted_by_number():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for i in range(waves.size() - 1):
		assert_lt(waves[i].wave_number, waves[i + 1].wave_number, "波次应按 wave_number 排序")

func test_boss_waves_count():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	var boss_waves := []
	for w: WaveData in waves:
		if w.is_boss_wave:
			boss_waves.append(w.wave_number)
	assert_eq(boss_waves.size(), 3, "应有 3 个 Boss 波")

func test_boss_waves_are_4_8_12():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	var boss_wave_numbers := []
	for w: WaveData in waves:
		if w.is_boss_wave:
			boss_wave_numbers.append(w.wave_number)
	assert_has(boss_wave_numbers, 4, "第 4 波应为 Boss 波")
	assert_has(boss_wave_numbers, 8, "第 8 波应为 Boss 波")
	assert_has(boss_wave_numbers, 12, "第 12 波应为 Boss 波")

func test_all_enemy_weights_reference_valid_types():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		for enemy_id: String in w.enemy_weights:
			assert_true(GameConfig.enemies.has(enemy_id), "敌人类型 '%s' 应在 GameConfig 中注册 (wave %d)" % [enemy_id, w.wave_number])

func test_boss_ids_reference_valid_enemies():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		if w.is_boss_wave:
			assert_ne(w.boss_id, "", "Boss 波 %d 应有 boss_id" % w.wave_number)
			assert_true(GameConfig.enemies.has(w.boss_id), "Boss '%s' 应在 GameConfig 中注册 (wave %d)" % [w.boss_id, w.wave_number])

func test_spawn_phases_valid():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		assert_gt(w.spawn_phases.size(), 0, "波次 %d 应有分段" % w.wave_number)
		var total_ratio: float = 0.0
		for phase: SpawnPhaseData in w.spawn_phases:
			assert_gt(phase.duration_ratio, 0.0, "波次 %d 阶段 ratio 应 > 0" % w.wave_number)
			assert_gt(phase.spawn_interval, 0.0, "波次 %d 阶段 interval 应 > 0" % w.wave_number)
			total_ratio += phase.duration_ratio
		assert_almost_eq(total_ratio, 1.0, 0.01, "波次 %d ratio 之和应为 1.0" % w.wave_number)

func test_wave_manager_time_based_completion():
	var wm = load("res://scripts/systems/wave_manager.gd").new()
	var waves: Array = GameConfig.get_waves_for_map("forest")
	var wave_1: WaveData = waves[0]
	wm._start_wave_with_data(1, wave_1)
	assert_true(wm.is_wave_active)
	wm._process(wave_1.time_limit + 0.1)
	assert_false(wm.is_wave_active, "时间到后波次应结束")

func test_elite_chance_increases_over_waves():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	assert_eq(waves[0].elite_chance, 0.0, "第 1 波不应有精英怪")
	var has_elite := false
	for w: WaveData in waves:
		if w.elite_chance > 0.0:
			has_elite = true
			break
	assert_true(has_elite, "后期波次应有精英怪")

func test_time_limit_increases_over_waves():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	assert_lt(waves[0].time_limit, waves[11].time_limit, "后期波次时间应更长")
