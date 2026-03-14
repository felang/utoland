extends GutTest

func test_forest_wave_count():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	assert_eq(waves.size(), 20, "Forest 地图应有 20 波")

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
	assert_eq(boss_waves.size(), 2, "应有 2 个 Boss 波")

func test_boss_waves_are_10_20():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	var boss_wave_numbers := []
	for w: WaveData in waves:
		if w.is_boss_wave:
			boss_wave_numbers.append(w.wave_number)
	assert_has(boss_wave_numbers, 10, "第 10 波应为 Boss 波")
	assert_has(boss_wave_numbers, 20, "第 20 波应为 Boss 波")

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

func test_difficulty_curve_total_enemies_increasing():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	# 整体趋势：后期波次 total_enemies 应多于前期（允许喘息波下降）
	var first_half_max := 0
	var second_half_max := 0
	for i in range(waves.size()):
		var w: WaveData = waves[i]
		if not w.is_boss_wave:
			if i < waves.size() / 2:
				first_half_max = max(first_half_max, w.total_enemies)
			else:
				second_half_max = max(second_half_max, w.total_enemies)
	assert_gt(second_half_max, first_half_max, "后半段最大敌人数应大于前半段")

func test_difficulty_curve_spawn_interval_decreasing():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	# 整体趋势：spawn_interval 应不增
	var first_interval: float = waves[0].spawn_interval
	var last_non_boss: WaveData = null
	for w: WaveData in waves:
		if not w.is_boss_wave:
			last_non_boss = w
	assert_lt(last_non_boss.spawn_interval, first_interval, "后期波次 spawn_interval 应比第 1 波小")

func test_elite_chance_increases_over_waves():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	# 第 1 波无精英，后期波次有精英
	assert_eq(waves[0].elite_chance, 0.0, "第 1 波不应有精英怪")
	var has_elite := false
	for w: WaveData in waves:
		if w.elite_chance > 0.0:
			has_elite = true
			break
	assert_true(has_elite, "后期波次应有精英怪")

func test_wave_manager_kill_tracking_with_real_wave_data():
	var wm = load("res://scripts/systems/wave_manager.gd").new()
	var waves: Array = GameConfig.get_waves_for_map("forest")
	var wave_1: WaveData = waves[0]
	wm._start_wave_with_data(1, wave_1)
	assert_eq(wm.enemies_killed, 0)
	# 模拟击杀所有敌人
	for i in range(wave_1.total_enemies):
		wm._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_eq(wm.enemies_killed, wave_1.total_enemies)
	assert_false(wm.is_wave_active, "击杀所有敌人后波次应结束")

func test_boss_wave_completion_with_real_data():
	var wm = load("res://scripts/systems/wave_manager.gd").new()
	var waves: Array = GameConfig.get_waves_for_map("forest")
	# 找第一个 Boss 波
	var boss_wave: WaveData = null
	for w: WaveData in waves:
		if w.is_boss_wave:
			boss_wave = w
			break
	assert_not_null(boss_wave, "应找到 Boss 波")
	wm._start_wave_with_data(boss_wave.wave_number, boss_wave)
	assert_true(wm.is_wave_active)
	wm._on_boss_killed(boss_wave.boss_id)
	assert_false(wm.is_wave_active, "Boss 死亡后波次应结束")
