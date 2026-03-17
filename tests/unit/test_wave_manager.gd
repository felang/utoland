extends GutTest

## WaveManager 纯时间制单元测试

var wave_manager: Node

func before_each():
	wave_manager = load("res://scripts/systems/wave_manager.gd").new()

func _make_wave_data(time_limit: float = 60.0, is_boss: bool = false, boss_id: String = "") -> WaveData:
	var wd := WaveData.new()
	wd.time_limit = time_limit
	wd.is_boss_wave = is_boss
	wd.boss_id = boss_id
	return wd

func test_wave_completes_on_time_limit():
	var wd := _make_wave_data(1.0)
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._process(1.1)
	assert_false(wave_manager.is_wave_active, "波次应在时间到后结束")

func test_wave_stays_active_before_time_limit():
	var wd := _make_wave_data(10.0)
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._process(5.0)
	assert_true(wave_manager.is_wave_active, "时间未到波次应保持活跃")

func test_enemy_kills_do_not_end_wave():
	var wd := _make_wave_data(999.0)
	wave_manager._start_wave_with_data(1, wd)
	for i in range(100):
		wave_manager._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_true(wave_manager.is_wave_active, "击杀敌人不应结束波次")

func test_boss_kill_does_not_end_wave():
	var wd := _make_wave_data(999.0, true, "boss_brute")
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._on_boss_killed("boss_brute")
	assert_true(wave_manager.is_wave_active, "Boss 被杀不应立即结束波次")
	assert_true(wave_manager._boss_killed_this_wave, "应标记 Boss 已击杀")

func test_boss_wave_time_up_without_kill_marks_escaped():
	var wd := _make_wave_data(1.0, true, "boss_brute")
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._process(1.1)
	assert_false(wave_manager.is_wave_active, "时间到波次应结束")

func test_boss_wave_time_up_after_kill_no_escape():
	var wd := _make_wave_data(1.0, true, "boss_brute")
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._on_boss_killed("boss_brute")
	wave_manager._process(1.1)
	assert_false(wave_manager.is_wave_active)
	assert_true(wave_manager._boss_killed_this_wave)

func test_boss_killed_flag_resets_each_wave():
	var wd1 := _make_wave_data(999.0, true, "boss_brute")
	wave_manager._start_wave_with_data(1, wd1)
	wave_manager._on_boss_killed("boss_brute")
	assert_true(wave_manager._boss_killed_this_wave)
	var wd2 := _make_wave_data(999.0)
	wave_manager._start_wave_with_data(2, wd2)
	assert_false(wave_manager._boss_killed_this_wave, "新波次应重置 Boss 击杀标记")
