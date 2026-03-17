extends GutTest

## EnemySpawner 分段生成 + Boss 波次测试

var spawner: Node

func before_each():
	spawner = load("res://scripts/systems/enemy_spawner.gd").new()
	add_child_autofree(spawner)

func _make_phase(ratio: float, interval: float, weights: Dictionary = {}) -> SpawnPhaseData:
	var phase := SpawnPhaseData.new()
	phase.duration_ratio = ratio
	phase.spawn_interval = interval
	phase.enemy_weights = weights
	return phase

func _make_wave_data(time_limit: float = 60.0, phases: Array[SpawnPhaseData] = [], max_alive: int = 30) -> WaveData:
	var wd := WaveData.new()
	wd.time_limit = time_limit
	wd.max_alive_enemies = max_alive
	wd.spawn_phases = phases
	wd.enemy_weights = {"normal": 100}
	return wd

func test_enters_first_phase_on_wave_start():
	var phases: Array[SpawnPhaseData] = [
		_make_phase(0.5, 2.0),
		_make_phase(0.5, 1.0),
	]
	var wd := _make_wave_data(60.0, phases)
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._current_phase_index, 0)
	assert_almost_eq(spawner._phase_duration, 30.0, 0.01, "第一阶段应为 60 * 0.5 = 30 秒")
	assert_almost_eq(spawner._current_spawn_interval, 2.0, 0.01)

func test_phase_transition():
	var phases: Array[SpawnPhaseData] = [
		_make_phase(0.3, 2.0),
		_make_phase(0.7, 0.5),
	]
	var wd := _make_wave_data(100.0, phases)
	spawner._on_wave_started(1, wd)
	spawner._phase_time_elapsed = 31.0
	spawner._check_phase_transition()
	assert_eq(spawner._current_phase_index, 1)
	assert_almost_eq(spawner._current_spawn_interval, 0.5, 0.01)

func test_last_phase_does_not_overflow():
	var phases: Array[SpawnPhaseData] = [
		_make_phase(0.5, 2.0),
		_make_phase(0.5, 1.0),
	]
	var wd := _make_wave_data(60.0, phases)
	spawner._on_wave_started(1, wd)
	spawner._current_phase_index = 1
	spawner._phase_time_elapsed = 999.0
	spawner._check_phase_transition()
	assert_eq(spawner._current_phase_index, 1)

func test_phase_inherits_wave_enemy_weights():
	var phases: Array[SpawnPhaseData] = [
		_make_phase(1.0, 1.0),
	]
	var wd := _make_wave_data(60.0, phases)
	wd.enemy_weights = {"normal": 70, "fast": 30}
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._current_enemy_weights, {"normal": 70, "fast": 30})

func test_phase_overrides_enemy_weights():
	var custom_weights := {"tank": 100}
	var phases: Array[SpawnPhaseData] = [
		_make_phase(1.0, 1.0, custom_weights),
	]
	var wd := _make_wave_data(60.0, phases)
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._current_enemy_weights, {"tank": 100})

func test_boss_should_spawn_on_last_phase():
	var phases: Array[SpawnPhaseData] = [
		_make_phase(0.6, 1.0),
		_make_phase(0.4, 0.5),
	]
	var wd := _make_wave_data(60.0, phases)
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	spawner._on_wave_started(1, wd)
	assert_false(spawner._boss_spawned)
	assert_false(spawner._should_spawn_boss(), "第一阶段不应生成 Boss")
	spawner._current_phase_index = 1
	assert_true(spawner._should_spawn_boss(), "最后阶段应触发 Boss 生成")

func test_boss_spawned_flag_resets():
	var phases: Array[SpawnPhaseData] = [_make_phase(1.0, 1.0)]
	var wd := WaveData.new()
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	wd.spawn_phases = phases
	wd.time_limit = 60.0
	wd.max_alive_enemies = 30
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	assert_false(spawner._boss_spawned)

func test_wave_completed_stops_spawning():
	var phases: Array[SpawnPhaseData] = [_make_phase(1.0, 1.0)]
	var wd := _make_wave_data(60.0, phases)
	spawner._on_wave_started(1, wd)
	assert_true(spawner._is_wave_active)
	spawner._on_wave_completed(1)
	assert_false(spawner._is_wave_active)
