extends GutTest

var spawner: Node

func before_each():
	spawner = load("res://scripts/systems/enemy_spawner.gd").new()
	add_child_autofree(spawner)

func test_boss_wave_starts_in_escort_phase():
	var wd := WaveData.new()
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	wd.boss_escort_count = 5
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._boss_phase, spawner.BossPhase.ESCORT)

func test_normal_wave_has_no_boss_phase():
	var wd := WaveData.new()
	wd.is_boss_wave = false
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._boss_phase, spawner.BossPhase.NONE)

func test_escort_spawn_limit():
	var wd := WaveData.new()
	wd.is_boss_wave = true
	wd.boss_escort_count = 3
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	assert_true(spawner._should_spawn_escort())
	spawner.enemies_spawned = 3
	assert_false(spawner._should_spawn_escort())

func test_boss_phase_transitions():
	var wd := WaveData.new()
	wd.is_boss_wave = true
	wd.boss_escort_count = 0  # 无护卫
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	# 0 个护卫，应立即进入 BOSS 阶段
	assert_false(spawner._should_spawn_escort())

func test_boss_spawned_flag_resets():
	var wd := WaveData.new()
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	spawner._on_wave_started(1, wd)
	assert_false(spawner._boss_spawned)
