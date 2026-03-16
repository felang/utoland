extends GutTest
## 合成系统单元测试
## 覆盖：不满3个不合成、3个lv1→lv2、最高级不合成、跨部署回收、递归合成、不同ID不互相合成

func before_each() -> void:
	GameData.reset()
	GameData.bag = []
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	GameData.player_level = 3

# ===== 基础情况 =====

func test_no_merge_with_two_items() -> void:
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData._check_merge("bow", 1)
	# 不够3个，不合成
	assert_eq(GameData.bag.size(), 2)
	assert_eq(GameData.deployed_weapons.size(), 0)

func test_merge_three_lv1_to_lv2() -> void:
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData._check_merge("bow", 1)
	# 3个lv1 合成1个lv2
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].id, "bow")
	assert_eq(GameData.bag[0].level, 2)
	assert_eq(GameData.bag[0].type, "weapon")

func test_no_merge_at_max_level() -> void:
	# max level = 3，lv3不合成
	GameData.bag.append({id = "bow", type = "weapon", level = 3})
	GameData.bag.append({id = "bow", type = "weapon", level = 3})
	GameData.bag.append({id = "bow", type = "weapon", level = 3})
	GameData._check_merge("bow", 3)
	# lv3 不触发合成
	assert_eq(GameData.bag.size(), 3)

# ===== 跨部署回收 =====

func test_merge_recalls_deployed_weapons() -> void:
	# 1个在背包，2个在部署
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData._check_merge("bow", 1)
	# 合成后：3个lv1消耗，生成1个lv2在背包
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].level, 2)
	assert_eq(GameData.deployed_weapons.size(), 0)

func test_merge_recalls_deployed_towers() -> void:
	# 1个在背包，2个在部署
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0)})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(1, 0)})
	GameData._check_merge("pea_shooter", 1)
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].level, 2)
	assert_eq(GameData.bag[0].type, "tower")
	assert_eq(GameData.deployed_towers.size(), 0)

# ===== 递归合成 =====

func test_recursive_merge_lv1_to_lv3() -> void:
	# _check_merge 每次只消耗3个同级物品并向上递归，不会重复扫描同级
	# 9个lv1：第一次调用消耗3个lv1 → 生成1个lv2，然后检查lv2（只有1个，不合成）
	# 剩余：6个lv1 + 1个lv2 = 7个物品
	for _i in range(9):
		GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData._check_merge("bow", 1)
	assert_eq(GameData.bag.size(), 7)
	# 要触发真正的递归lv3合成，需要外部多次调用（如购买商品后逐个检查）
	# 测试真正3+3+3→lv2, lv2+lv2+lv2→lv3的情况：先有2个lv2，再触发1个lv1→lv2合成
	GameData.bag = []
	GameData.bag.append({id = "bow", type = "weapon", level = 2})
	GameData.bag.append({id = "bow", type = "weapon", level = 2})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData._check_merge("bow", 1)
	# 3个lv1 → 1个lv2，此时bag有2+1=3个lv2 → 递归合成1个lv3
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].level, 3)

func test_partial_recursive_merge_no_lv3() -> void:
	# 1个lv2 + 3个lv1：触发lv1合成得到1个lv2，此时共2个lv2，不足3个，不继续递归
	GameData.bag.append({id = "bow", type = "weapon", level = 2})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData._check_merge("bow", 1)
	# 3个lv1 → 1个lv2，共2个lv2，不触发lv3合成
	assert_eq(GameData.bag.size(), 2)
	var lv2_count: int = 0
	for item in GameData.bag:
		if item.id == "bow" and item.level == 2:
			lv2_count += 1
	assert_eq(lv2_count, 2)

# ===== 不同ID不互相合成 =====

func test_different_ids_do_not_cross_merge() -> void:
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "sword", type = "weapon", level = 1})
	GameData._check_merge("bow", 1)
	# bow只有2个，不合成
	assert_eq(GameData.bag.size(), 3)
	var bow_count: int = 0
	for item in GameData.bag:
		if item.id == "bow" and item.level == 1:
			bow_count += 1
	assert_eq(bow_count, 2)

# ===== 合成信号 =====

func test_merge_emits_signal() -> void:
	var merged_events: Array[Dictionary] = []
	EventBus.item_merged.connect(func(item_id: String, new_level: int):
		merged_events.append({id = item_id, level = new_level})
	)
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData._check_merge("bow", 1)
	assert_eq(merged_events.size(), 1)
	assert_eq(merged_events[0].id, "bow")
	assert_eq(merged_events[0].level, 2)
	for conn in EventBus.item_merged.get_connections():
		EventBus.item_merged.disconnect(conn["callable"])

# ===== 混合位置中优先从 bag 取 =====

func test_merge_prefers_bag_over_deployed() -> void:
	# 2个在背包，1个在部署武器
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.bag.append({id = "bow", type = "weapon", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData._check_merge("bow", 1)
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].level, 2)
	# 背包的2个应优先被消耗，部署的1个也被消耗
	assert_eq(GameData.deployed_weapons.size(), 0)
