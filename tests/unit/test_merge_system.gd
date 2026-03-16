extends GutTest
## 合成系统单元测试
## 覆盖：不满3个不合成、3个lv1→lv2、最高级不合成、跨部署位置、递归合成、不同ID不互相合成
## 合成后物品留在 deployed 中（不再有 bag）

func before_each() -> void:
	GameData.reset()
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	GameData.player_level = 3

# ===== 基础情况 =====

func test_no_merge_with_two_items() -> void:
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData._check_merge("bow", 1)
	# 不够3个，不合成
	assert_eq(GameData.deployed_weapons.size(), 2)

func test_merge_three_lv1_weapons_to_lv2() -> void:
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData._check_merge("bow", 1)
	# 3个lv1 合成1个lv2，留在 deployed_weapons
	assert_eq(GameData.deployed_weapons.size(), 1)
	assert_eq(GameData.deployed_weapons[0].id, "bow")
	assert_eq(GameData.deployed_weapons[0].level, 2)

func test_merge_three_lv1_towers_to_lv2() -> void:
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0), deploy_id = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(1, 0), deploy_id = 2})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(2, 0), deploy_id = 3})
	GameData._check_merge("pea_shooter", 1)
	# 合成后留在 deployed_towers
	assert_eq(GameData.deployed_towers.size(), 1)
	assert_eq(GameData.deployed_towers[0].id, "pea_shooter")
	assert_eq(GameData.deployed_towers[0].level, 2)

func test_no_merge_at_max_level() -> void:
	# max level = 3，lv3不合成
	GameData.deployed_weapons.append({id = "bow", level = 3})
	GameData.deployed_weapons.append({id = "bow", level = 3})
	GameData.deployed_weapons.append({id = "bow", level = 3})
	GameData._check_merge("bow", 3)
	# lv3 不触发合成
	assert_eq(GameData.deployed_weapons.size(), 3)

# ===== 递归合成 =====

func test_recursive_merge_lv1_to_lv3() -> void:
	# 先有2个lv2，再加3个lv1，触发lv1合成得到第3个lv2，递归合成lv3
	GameData.deployed_weapons.append({id = "bow", level = 2})
	GameData.deployed_weapons.append({id = "bow", level = 2})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData._check_merge("bow", 1)
	# 3个lv1 → 1个lv2，此时有3个lv2 → 递归合成1个lv3
	assert_eq(GameData.deployed_weapons.size(), 1)
	assert_eq(GameData.deployed_weapons[0].level, 3)

func test_partial_recursive_merge_no_lv3() -> void:
	# 1个lv2 + 3个lv1：触发lv1合成得到1个lv2，此时共2个lv2，不足3个
	GameData.deployed_weapons.append({id = "bow", level = 2})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData._check_merge("bow", 1)
	# 3个lv1 → 1个lv2，共2个lv2
	assert_eq(GameData.deployed_weapons.size(), 2)
	var lv2_count: int = 0
	for item in GameData.deployed_weapons:
		if item.id == "bow" and item.level == 2:
			lv2_count += 1
	assert_eq(lv2_count, 2)

# ===== 不同ID不互相合成 =====

func test_different_ids_do_not_cross_merge() -> void:
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "sword", level = 1})
	GameData._check_merge("bow", 1)
	# bow只有2个，不合成
	assert_eq(GameData.deployed_weapons.size(), 3)
	var bow_count: int = 0
	for item in GameData.deployed_weapons:
		if item.id == "bow" and item.level == 1:
			bow_count += 1
	assert_eq(bow_count, 2)

# ===== 合成信号 =====

func test_merge_emits_signal() -> void:
	var merged_events: Array[Dictionary] = []
	EventBus.item_merged.connect(func(item_id: String, new_level: int):
		merged_events.append({id = item_id, level = new_level})
	)
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData._check_merge("bow", 1)
	assert_eq(merged_events.size(), 1)
	assert_eq(merged_events[0].id, "bow")
	assert_eq(merged_events[0].level, 2)
	for conn in EventBus.item_merged.get_connections():
		EventBus.item_merged.disconnect(conn["callable"])

# ===== 塔合成保留位置和 deploy_id =====

func test_tower_merge_keeps_position() -> void:
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(3, 3), deploy_id = 10})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(4, 4), deploy_id = 11})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 12})
	GameData._check_merge("pea_shooter", 1)
	assert_eq(GameData.deployed_towers.size(), 1)
	assert_eq(GameData.deployed_towers[0].level, 2)
	# 合成品保留第一个被消耗的塔的位置和 deploy_id
	assert_true(GameData.deployed_towers[0].has("grid_pos"))
	assert_true(GameData.deployed_towers[0].has("deploy_id"))
