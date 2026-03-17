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

