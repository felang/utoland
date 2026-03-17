extends GutTest
## GameData 经济系统单元测试
## 覆盖：初始状态、种群上限、部署/撤回、出售逻辑、经验系统、deploy_id、move_tower

func before_each() -> void:
	GameData.reset()
	# 清空部署状态，确保每个测试从干净状态开始
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	GameData.player_level = 1
	GameData.coins = GameConfig.PLAYER["initial_coins"]

# ===== 初始状态 =====

func test_initial_state_after_reset() -> void:
	assert_eq(GameData.player_level, 1)
	assert_eq(GameData.deployed_weapons.size(), 0)
	assert_eq(GameData.deployed_towers.size(), 0)
	assert_eq(GameData.shop_slots.size(), 0)
	assert_true(GameData.is_first_shop_visit)

# ===== 种群上限 =====

func test_get_population_cap_level1() -> void:
	GameData.player_level = 1
	# initial_population + (1-1) * 1 = 2
	assert_eq(GameData.get_population_cap(), 2)

func test_get_population_cap_level5() -> void:
	GameData.player_level = 5
	# initial_population + (5-1) * 1 = 6
	assert_eq(GameData.get_population_cap(), 6)

func test_get_population_cap_level10() -> void:
	GameData.player_level = 10
	# initial_population + (10-1) * 1 = 11
	assert_eq(GameData.get_population_cap(), 11)

# ===== 种群已用 =====

func test_get_population_used_empty() -> void:
	assert_eq(GameData.get_population_used(), 0)

func test_get_population_used_with_deployed() -> void:
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0)})
	assert_eq(GameData.get_population_used(), 2)

# ===== can_deploy =====

func test_can_deploy_when_under_cap() -> void:
	GameData.player_level = 1
	# cap=2, used=0
	assert_true(GameData.can_deploy())

func test_can_deploy_when_at_cap() -> void:
	GameData.player_level = 1
	# cap=2, fill with 2 deployed
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0)})
	assert_false(GameData.can_deploy())

# ===== buy_and_equip_weapon =====

func test_buy_and_equip_weapon_success() -> void:
	GameData.player_level = 2
	GameData.coins = 50
	var result: bool = GameData.buy_and_equip_weapon("bow", 3)
	assert_true(result)
	assert_eq(GameData.deployed_weapons.size(), 1)
	assert_eq(GameData.deployed_weapons[0].id, "bow")
	assert_eq(GameData.deployed_weapons[0].level, 1)
	assert_eq(GameData.coins, 47)

func test_buy_and_equip_weapon_fails_when_population_full() -> void:
	GameData.player_level = 1
	# 填满种群上限（cap=2）
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0)})
	GameData.coins = 50
	var result: bool = GameData.buy_and_equip_weapon("bow", 3)
	assert_false(result)
	assert_eq(GameData.deployed_weapons.size(), 1)
	assert_eq(GameData.coins, 50)

func test_buy_and_equip_weapon_fails_insufficient_coins() -> void:
	GameData.player_level = 2
	GameData.coins = 1
	var result: bool = GameData.buy_and_equip_weapon("bow", 3)
	assert_false(result)
	assert_eq(GameData.deployed_weapons.size(), 0)

# ===== buy_and_place_tower =====

func test_buy_and_place_tower_success() -> void:
	GameData.player_level = 2
	GameData.coins = 50
	var pos := Vector2i(5, 3)
	var deploy_id: int = GameData.buy_and_place_tower("pea_shooter", 3, pos)
	assert_gt(deploy_id, 0)
	assert_eq(GameData.deployed_towers.size(), 1)
	assert_eq(GameData.deployed_towers[0].id, "pea_shooter")
	assert_eq(GameData.deployed_towers[0].grid_pos, pos)
	assert_eq(GameData.coins, 47)

func test_buy_and_place_tower_returns_deploy_id() -> void:
	GameData.player_level = 2
	GameData.coins = 50
	var deploy_id: int = GameData.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	assert_gt(deploy_id, 0, "buy_and_place_tower 应返回 > 0 的 deploy_id")
	assert_eq(GameData.deployed_towers[0].deploy_id, deploy_id)

func test_buy_and_place_tower_increments_deploy_id() -> void:
	GameData.player_level = 3
	GameData.coins = 100
	var id1: int = GameData.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	var id2: int = GameData.buy_and_place_tower("ice_flower", 3, Vector2i(10, 10))
	assert_ne(id1, id2)
	assert_gt(id2, id1)

func test_buy_and_place_tower_fails_population_full() -> void:
	GameData.player_level = 1
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0)})
	GameData.coins = 50
	var deploy_id: int = GameData.buy_and_place_tower("ice_flower", 3, Vector2i(5, 5))
	assert_eq(deploy_id, 0)

func test_buy_and_place_tower_fails_insufficient_coins() -> void:
	GameData.player_level = 2
	GameData.coins = 1
	var deploy_id: int = GameData.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	assert_eq(deploy_id, 0)

func test_reset_clears_deploy_id_counter() -> void:
	GameData.player_level = 2
	GameData.coins = 100
	GameData.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	GameData.reset()
	GameData.player_level = 2
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	GameData.coins = 100
	var deploy_id: int = GameData.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	assert_eq(deploy_id, 1)

# ===== 经验系统 =====

func test_add_exp_accumulates() -> void:
	GameData.current_exp = 0
	GameData.add_exp(10)
	assert_eq(GameData.current_exp, 10)
	GameData.add_exp(5)
	assert_eq(GameData.current_exp, 15)

func test_add_exp_records_total() -> void:
	GameData.total_exp_earned = 0
	GameData.current_exp = 0
	GameData.add_exp(10)
	assert_eq(GameData.total_exp_earned, 10)

func test_add_exp_auto_level_up() -> void:
	GameData.player_level = 1
	GameData.current_exp = 0
	# exp_for_level(2) = floor(5 * 2^2) = 20
	GameData.add_exp(20)
	assert_eq(GameData.player_level, 2)

func test_add_exp_no_level_up_below_threshold() -> void:
	GameData.player_level = 1
	GameData.current_exp = 0
	GameData.add_exp(19)
	assert_eq(GameData.player_level, 1)

func test_add_exp_multi_level_up() -> void:
	GameData.player_level = 1
	GameData.current_exp = 0
	# exp_for_level(2) = 20, exp_for_level(3) = 45
	GameData.add_exp(45)
	assert_eq(GameData.player_level, 3)

func test_add_exp_emits_level_changed() -> void:
	GameData.player_level = 1
	GameData.current_exp = 0
	var level_changes: Array[int] = []
	EventBus.player_level_changed.connect(func(lvl: int): level_changes.append(lvl))
	GameData.add_exp(20)
	assert_eq(level_changes, [2])
	for conn in EventBus.player_level_changed.get_connections():
		EventBus.player_level_changed.disconnect(conn["callable"])

func test_add_exp_emits_exp_changed() -> void:
	GameData.player_level = 1
	GameData.current_exp = 0
	var exp_events: Array[Array] = []
	EventBus.exp_changed.connect(func(cur: int, to_next: int): exp_events.append([cur, to_next]))
	GameData.add_exp(10)
	assert_eq(exp_events.size(), 1)
	assert_eq(exp_events[0][0], 10)
	for conn in EventBus.exp_changed.get_connections():
		EventBus.exp_changed.disconnect(conn["callable"])

# ===== sell_from_deployed_weapon =====

func test_sell_from_deployed_weapon() -> void:
	# bow lv1 sell_price = 3
	GameData.deployed_weapons.append({id = "bow", level = 1})
	var initial_coins: int = GameData.coins
	var refund: int = GameData.sell_from_deployed_weapon(0)
	assert_eq(refund, 3)
	assert_eq(GameData.coins, initial_coins + 3)
	assert_eq(GameData.deployed_weapons.size(), 0)

func test_sell_from_deployed_weapon_lv2() -> void:
	# bow lv2 sell_price = 7
	GameData.deployed_weapons.append({id = "bow", level = 2})
	var initial_coins: int = GameData.coins
	var refund: int = GameData.sell_from_deployed_weapon(0)
	assert_eq(refund, 7)
	assert_eq(GameData.coins, initial_coins + 7)

func test_sell_from_deployed_weapon_invalid_index() -> void:
	var initial_coins: int = GameData.coins
	var refund: int = GameData.sell_from_deployed_weapon(0)
	assert_eq(refund, 0)
	assert_eq(GameData.coins, initial_coins)

# ===== sell_from_deployed_tower =====

func test_sell_from_deployed_tower() -> void:
	GameData.player_level = 2
	GameData.coins = 100
	var deploy_id: int = GameData.buy_and_place_tower("pea_shooter", 3, Vector2i(0, 0))
	var coins_after_buy: int = GameData.coins
	var refund: int = GameData.sell_from_deployed_tower(deploy_id)
	assert_eq(refund, 3)
	assert_eq(GameData.coins, coins_after_buy + 3)
	assert_eq(GameData.deployed_towers.size(), 0)

func test_sell_from_deployed_tower_invalid_deploy_id() -> void:
	var initial_coins: int = GameData.coins
	var refund: int = GameData.sell_from_deployed_tower(999)
	assert_eq(refund, 0)
	assert_eq(GameData.coins, initial_coins)

# ===== move_tower =====

func test_move_tower_success() -> void:
	GameData.player_level = 2
	GameData.coins = 100
	var deploy_id: int = GameData.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	var result: bool = GameData.move_tower(deploy_id, Vector2i(10, 10))
	assert_true(result)
	assert_eq(GameData.deployed_towers[0].grid_pos, Vector2i(10, 10))

func test_move_tower_invalid_id() -> void:
	var result: bool = GameData.move_tower(999, Vector2i(10, 10))
	assert_false(result)

func test_move_tower_occupied() -> void:
	GameData.player_level = 3
	GameData.coins = 100
	GameData.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	var id2: int = GameData.buy_and_place_tower("ice_flower", 3, Vector2i(10, 10))
	var result: bool = GameData.move_tower(id2, Vector2i(5, 5))
	assert_false(result)

func test_move_tower_out_of_bounds() -> void:
	GameData.player_level = 2
	GameData.coins = 100
	var deploy_id: int = GameData.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	assert_false(GameData.move_tower(deploy_id, Vector2i(-1, 5)))
	assert_false(GameData.move_tower(deploy_id, Vector2i(GameConfig.MAP_GRID_WIDTH, 5)))

func test_move_tower_same_position() -> void:
	GameData.player_level = 2
	GameData.coins = 100
	var deploy_id: int = GameData.buy_and_place_tower("pea_shooter", 3, Vector2i(5, 5))
	assert_true(GameData.move_tower(deploy_id, Vector2i(5, 5)))

# ===== reset 经验字段 =====

func test_reset_clears_exp_fields() -> void:
	GameData.current_exp = 999
	GameData.total_exp_earned = 888
	GameData.player_level = 5
	GameData.reset()
	assert_eq(GameData.current_exp, 0)
	assert_eq(GameData.total_exp_earned, 0)
	assert_eq(GameData.player_level, 1)
