extends GutTest
## 经济系统单元测试（原 GameData，已拆分为 InventoryManager/PlayerProgression/PlayerState）
## 覆盖：初始状态、部署/撤回、出售逻辑、经验系统、deploy_id、move_tower

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	StatsTracker.reset()
	# 清空部署状态，确保每个测试从干净状态开始
	InventoryManager.deployed_towers = []
	PlayerProgression.player_level = 1
	InventoryManager.coins = GameConfig.PLAYER["initial_coins"]

# ===== 初始状态 =====

func test_initial_state_after_reset() -> void:
	assert_eq(PlayerProgression.player_level, 1)
	assert_eq(InventoryManager.deployed_towers.size(), 0)
	assert_eq(InventoryManager.shop_slots.size(), 0)
	assert_true(InventoryManager.is_first_shop_visit)

# ===== buy_and_place_tower =====

func test_buy_and_place_tower_success() -> void:
	PlayerProgression.player_level = 2
	InventoryManager.coins = 50
	var pos := Vector2i(5, 3)
	var deploy_id: int = InventoryManager.buy_and_place_tower("pea_shooter", 3, pos)
	assert_gt(deploy_id, 0)
	assert_eq(InventoryManager.deployed_towers.size(), 1)
	assert_eq(InventoryManager.deployed_towers[0].id, "pea_shooter")
	assert_eq(InventoryManager.deployed_towers[0].grid_pos, pos)
	assert_eq(InventoryManager.coins, 47)

func test_buy_and_place_tower_returns_deploy_id() -> void:
	PlayerProgression.player_level = 2
	InventoryManager.coins = 50
	var deploy_id: int = InventoryManager.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	assert_gt(deploy_id, 0, "buy_and_place_tower 应返回 > 0 的 deploy_id")
	assert_eq(InventoryManager.deployed_towers[0].deploy_id, deploy_id)

func test_buy_and_place_tower_increments_deploy_id() -> void:
	PlayerProgression.player_level = 3
	InventoryManager.coins = 100
	var id1: int = InventoryManager.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	var id2: int = InventoryManager.buy_and_place_tower("ice_flower", 3, Vector2i(10, 10))
	assert_ne(id1, id2)
	assert_gt(id2, id1)

func test_buy_and_place_tower_fails_insufficient_coins() -> void:
	PlayerProgression.player_level = 2
	InventoryManager.coins = 1
	var deploy_id: int = InventoryManager.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	assert_eq(deploy_id, 0)

func test_reset_clears_deploy_id_counter() -> void:
	PlayerProgression.player_level = 2
	InventoryManager.coins = 100
	InventoryManager.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	InventoryManager.reset()
	PlayerProgression.player_level = 2
	InventoryManager.deployed_towers = []
	InventoryManager.coins = 100
	var deploy_id: int = InventoryManager.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	assert_eq(deploy_id, 1)

# ===== 经验系统 =====

func test_add_exp_accumulates() -> void:
	PlayerProgression.current_exp = 0
	PlayerProgression.add_exp(10)
	assert_eq(PlayerProgression.current_exp, 10)
	PlayerProgression.add_exp(5)
	assert_eq(PlayerProgression.current_exp, 15)

func test_add_exp_records_total() -> void:
	PlayerProgression.total_exp_earned = 0
	PlayerProgression.current_exp = 0
	PlayerProgression.add_exp(10)
	assert_eq(PlayerProgression.total_exp_earned, 10)

func test_add_exp_auto_level_up() -> void:
	PlayerProgression.player_level = 1
	PlayerProgression.current_exp = 0
	# exp_for_level(2) = floor(5 * 2^1.6) = 15
	PlayerProgression.add_exp(15)
	assert_eq(PlayerProgression.player_level, 2)

func test_add_exp_no_level_up_below_threshold() -> void:
	PlayerProgression.player_level = 1
	PlayerProgression.current_exp = 0
	# exp_for_level(2) = 15，加 14 不升级
	PlayerProgression.add_exp(14)
	assert_eq(PlayerProgression.player_level, 1)

func test_add_exp_multi_level_up() -> void:
	PlayerProgression.player_level = 1
	PlayerProgression.current_exp = 0
	# exp_for_level(2) = 15, exp_for_level(3) = 28
	PlayerProgression.add_exp(28)
	assert_eq(PlayerProgression.player_level, 3)

func test_add_exp_emits_level_changed() -> void:
	PlayerProgression.player_level = 1
	PlayerProgression.current_exp = 0
	var level_changes: Array[int] = []
	var _cb := func(lvl: int): level_changes.append(lvl)
	EventBus.player_level_changed.connect(_cb)
	PlayerProgression.add_exp(20)
	assert_eq(level_changes, [2])
	EventBus.player_level_changed.disconnect(_cb)

func test_add_exp_emits_exp_changed() -> void:
	PlayerProgression.player_level = 1
	PlayerProgression.current_exp = 0
	var exp_events: Array[Array] = []
	EventBus.exp_changed.connect(func(cur: int, to_next: int): exp_events.append([cur, to_next]))
	PlayerProgression.add_exp(10)
	assert_eq(exp_events.size(), 1)
	assert_eq(exp_events[0][0], 10)
	for conn in EventBus.exp_changed.get_connections():
		EventBus.exp_changed.disconnect(conn["callable"])

# ===== sell_from_deployed_tower =====

func test_sell_from_deployed_tower() -> void:
	PlayerProgression.player_level = 2
	InventoryManager.coins = 100
	var deploy_id: int = InventoryManager.buy_and_place_tower("pea_shooter", 3, Vector2i(0, 0))
	var coins_after_buy: int = InventoryManager.coins
	var refund: int = InventoryManager.sell_from_deployed_tower(deploy_id)
	var expected: int = int(round(3 * GameConfig.shop_config.sell_return_ratio))
	assert_eq(refund, expected)
	assert_eq(InventoryManager.coins, coins_after_buy + expected)
	assert_eq(InventoryManager.deployed_towers.size(), 0)

func test_sell_from_deployed_tower_invalid_deploy_id() -> void:
	var initial_coins: int = InventoryManager.coins
	var refund: int = InventoryManager.sell_from_deployed_tower(999)
	assert_eq(refund, 0)
	assert_eq(InventoryManager.coins, initial_coins)

# ===== move_tower =====

func test_move_tower_success() -> void:
	PlayerProgression.player_level = 2
	InventoryManager.coins = 100
	var deploy_id: int = InventoryManager.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	var result: bool = InventoryManager.move_tower(deploy_id, Vector2i(10, 10))
	assert_true(result)
	assert_eq(InventoryManager.deployed_towers[0].grid_pos, Vector2i(10, 10))

func test_move_tower_invalid_id() -> void:
	var result: bool = InventoryManager.move_tower(999, Vector2i(10, 10))
	assert_false(result)

func test_move_tower_occupied() -> void:
	PlayerProgression.player_level = 3
	InventoryManager.coins = 100
	InventoryManager.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	var id2: int = InventoryManager.buy_and_place_tower("ice_flower", 3, Vector2i(10, 10))
	var result: bool = InventoryManager.move_tower(id2, Vector2i(5, 5))
	assert_false(result)

func test_move_tower_out_of_bounds() -> void:
	PlayerProgression.player_level = 2
	InventoryManager.coins = 100
	var deploy_id: int = InventoryManager.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	assert_false(InventoryManager.move_tower(deploy_id, Vector2i(-1, 5)))
	assert_false(InventoryManager.move_tower(deploy_id, Vector2i(GameConfig.MAP_GRID_WIDTH, 5)))

func test_move_tower_same_position() -> void:
	PlayerProgression.player_level = 2
	InventoryManager.coins = 100
	var deploy_id: int = InventoryManager.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	assert_true(InventoryManager.move_tower(deploy_id, Vector2i(5, 5)))

# ===== reset 经验字段 =====

func test_reset_clears_exp_fields() -> void:
	PlayerProgression.current_exp = 999
	PlayerProgression.total_exp_earned = 888
	PlayerProgression.player_level = 5
	PlayerProgression.reset()
	assert_eq(PlayerProgression.current_exp, 0)
	assert_eq(PlayerProgression.total_exp_earned, 0)
	assert_eq(PlayerProgression.player_level, 1)
