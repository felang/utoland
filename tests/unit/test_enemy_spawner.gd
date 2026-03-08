extends GutTest

var spawner: Node

func before_each():
	spawner = load("res://scripts/systems/enemy_spawner.gd").new()
	add_child_autofree(spawner)

func test_pick_weighted_enemy_single_type():
	var weights := {"normal": 100}
	var result: String = spawner.pick_weighted_enemy(weights)
	assert_eq(result, "normal")

func test_pick_weighted_enemy_returns_valid_type():
	var weights := {"normal": 70, "fast": 30}
	for i in range(50):
		var result: String = spawner.pick_weighted_enemy(weights)
		assert_true(result in ["normal", "fast"], "应返回有效敌人类型: %s" % result)

func test_pick_weighted_enemy_respects_weights():
	# 用极端权重验证：99% normal, 1% fast
	var weights := {"normal": 99, "fast": 1}
	var normal_count := 0
	for i in range(200):
		if spawner.pick_weighted_enemy(weights) == "normal":
			normal_count += 1
	# normal 应该占绝大多数（至少 80%）
	assert_gt(normal_count, 160, "权重 99 的 normal 应出现在绝大多数情况")

func test_should_spawn_respects_limit():
	var wd := WaveData.new()
	wd.total_enemies = 3
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	assert_true(spawner._should_spawn())
	spawner.enemies_spawned = 3
	assert_false(spawner._should_spawn())

func test_enemies_spawned_resets_each_wave():
	var wd := WaveData.new()
	wd.total_enemies = 10
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	spawner.enemies_spawned = 5
	spawner._on_wave_started(2, wd)
	assert_eq(spawner.enemies_spawned, 0)

func test_should_spawn_false_without_wave_data():
	assert_false(spawner._should_spawn())
