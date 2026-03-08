extends GutTest

func test_wave_data_default_values():
	var wd := WaveData.new()
	assert_eq(wd.wave_number, 1)
	assert_eq(wd.total_enemies, 15)
	assert_eq(wd.time_limit, 60.0)
	assert_eq(wd.spawn_interval, 1.5)
	assert_eq(wd.enemy_weights, {"normal": 100})
	assert_eq(wd.elite_chance, 0.0)
	assert_eq(wd.elite_hp_mult, 1.5)
	assert_eq(wd.elite_damage_mult, 1.3)
	assert_eq(wd.elite_coin_mult, 2.0)
	assert_eq(wd.elite_scale, 1.2)
	assert_eq(wd.is_boss_wave, false)
	assert_eq(wd.boss_id, "")
	assert_eq(wd.boss_escort_count, 0)

func test_wave_data_custom_values():
	var wd := WaveData.new()
	wd.total_enemies = 30
	wd.time_limit = 90.0
	wd.enemy_weights = {"normal": 50, "fast": 30, "tank": 20}
	wd.elite_chance = 0.15
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	wd.boss_escort_count = 10
	assert_eq(wd.total_enemies, 30)
	assert_eq(wd.time_limit, 90.0)
	assert_eq(wd.enemy_weights, {"normal": 50, "fast": 30, "tank": 20})
	assert_eq(wd.elite_chance, 0.15)
	assert_eq(wd.is_boss_wave, true)
	assert_eq(wd.boss_id, "boss_brute")
	assert_eq(wd.boss_escort_count, 10)
