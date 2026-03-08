extends GutTest

## WaveManager 击杀制结束条件单元测试

var wave_manager: Node

func before_each():
	wave_manager = load("res://scripts/systems/wave_manager.gd").new()
	# 不调用 add_child（避免 _ready 触发 start_next_wave）
	# 直接测试内部方法

func test_kill_count_increments():
	var wd := WaveData.new()
	wd.total_enemies = 10
	wd.time_limit = 60.0
	wave_manager._start_wave_with_data(1, wd)
	assert_eq(wave_manager.enemies_killed, 0)
	wave_manager._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_eq(wave_manager.enemies_killed, 1)

func test_wave_completes_on_all_killed():
	var wd := WaveData.new()
	wd.total_enemies = 2
	wd.time_limit = 999.0
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._on_enemy_killed("normal", Vector2.ZERO, false)
	wave_manager._on_enemy_killed("fast", Vector2.ZERO, false)
	assert_false(wave_manager.is_wave_active, "波次应在全部击杀后结束")

func test_wave_completes_on_time_limit():
	var wd := WaveData.new()
	wd.total_enemies = 100
	wd.time_limit = 1.0
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._process(1.1)
	assert_false(wave_manager.is_wave_active, "波次应在时间到后结束")

func test_boss_wave_completes_on_boss_killed():
	var wd := WaveData.new()
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	wd.total_enemies = 100
	wd.time_limit = 999.0
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._on_boss_killed("boss_brute")
	assert_false(wave_manager.is_wave_active, "Boss 波应在 Boss 击杀后结束")

func test_boss_wave_ignores_normal_kill_count():
	var wd := WaveData.new()
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	wd.total_enemies = 2
	wd.time_limit = 999.0
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._on_enemy_killed("normal", Vector2.ZERO, false)
	wave_manager._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_true(wave_manager.is_wave_active, "Boss 波不应因普通击杀数达标而结束")

func test_kill_after_wave_inactive_ignored():
	var wd := WaveData.new()
	wd.total_enemies = 5
	wd.time_limit = 60.0
	wave_manager._start_wave_with_data(1, wd)
	wave_manager.is_wave_active = false
	wave_manager._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_eq(wave_manager.enemies_killed, 0, "波次不活跃时击杀不计数")

func test_enemies_killed_resets_each_wave():
	var wd1 := WaveData.new()
	wd1.total_enemies = 10
	wd1.time_limit = 60.0
	wave_manager._start_wave_with_data(1, wd1)
	wave_manager._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_eq(wave_manager.enemies_killed, 1)
	var wd2 := WaveData.new()
	wd2.total_enemies = 10
	wd2.time_limit = 60.0
	wave_manager._start_wave_with_data(2, wd2)
	assert_eq(wave_manager.enemies_killed, 0, "新波次应重置击杀数")
