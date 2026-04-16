extends GutTest

var _mgr: TowerRollManager = null

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	_mgr = TowerRollManager.new()

func test_roll_three_returns_three_ids() -> void:
	var result: Array = _mgr.roll_three(1)
	assert_eq(result.size(), 3)
	for tower_id in result:
		assert_true(GameConfig.towers.has(tower_id), "未知 tower_id: " + str(tower_id))

func test_roll_can_repeat_same_tower() -> void:
	# 大量 roll,期望出现至少一次重复(3 座塔随机抽 3 张)
	var seen_dup: bool = false
	for i in 30:
		var r: Array = _mgr.roll_three(1)
		var unique: Dictionary = {}
		for tid in r:
			unique[tid] = true
		if unique.size() < r.size():
			seen_dup = true
			break
	assert_true(seen_dup, "30 轮 roll 应至少出现 1 次重复")

func test_dynamic_weight_favors_deployed() -> void:
	# 部署 5 座 pea_shooter,期望 pea_shooter 的 roll 比例显著上升
	for i in 5:
		InventoryManager.deployed_towers.append({
			id = "pea_shooter", level = 1,
			grid_pos = Vector2i(i, 0), deploy_id = i + 1,
		})
	var pea_count: int = 0
	var total: int = 0
	for i in 100:
		var r: Array = _mgr.roll_three(1)
		for tid in r:
			total += 1
			if tid == "pea_shooter":
				pea_count += 1
	# 3 座塔均匀概率 1/3 ≈ 33%,加权后应 > 40%
	var ratio: float = float(pea_count) / float(total)
	assert_gt(ratio, 0.4, "pea_shooter 应该被显著加权,实际比例: " + str(ratio))

func test_lv3_deployed_does_not_boost_weight() -> void:
	# 部署 Lv3 满级 pea_shooter — 不应加权
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 3,
		grid_pos = Vector2i(0, 0), deploy_id = 1,
	})
	# 此处只验证函数返回正确(不再加权)
	assert_false(_mgr._has_unleveled_deployed("pea_shooter"))
