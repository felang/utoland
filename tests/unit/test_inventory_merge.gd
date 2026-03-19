extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	StatsTracker.reset()
	InventoryManager.coins = 100
	PlayerProgression.player_level = 10

# ===== _check_merge 二合一 =====

func test_check_merge_two_same_weapons() -> void:
	InventoryManager.deployed_weapons = [
		{id = "bow", level = 1},
		{id = "bow", level = 1},
	]
	InventoryManager._check_merge("bow", 1)
	assert_eq(InventoryManager.deployed_weapons.size(), 1)
	assert_eq(InventoryManager.deployed_weapons[0].level, 2)

func test_check_merge_no_merge_with_one() -> void:
	InventoryManager.deployed_weapons = [{id = "bow", level = 1}]
	InventoryManager._check_merge("bow", 1)
	assert_eq(InventoryManager.deployed_weapons.size(), 1)
	assert_eq(InventoryManager.deployed_weapons[0].level, 1)

func test_check_merge_max_level() -> void:
	InventoryManager.deployed_weapons = [
		{id = "bow", level = 3},
		{id = "bow", level = 3},
	]
	InventoryManager._check_merge("bow", 3)
	assert_eq(InventoryManager.deployed_weapons.size(), 2)

func test_check_merge_towers_preserves_position() -> void:
	InventoryManager.deployed_towers = [
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1},
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(10, 10), deploy_id = 2},
	]
	InventoryManager._check_merge("pea_shooter", 1)
	assert_eq(InventoryManager.deployed_towers.size(), 1)
	assert_eq(InventoryManager.deployed_towers[0].level, 2)

# ===== merge_weapon 手动合成 =====

func test_merge_weapon_success() -> void:
	InventoryManager.deployed_weapons = [
		{id = "bow", level = 1},
		{id = "bow", level = 1},
	]
	var result: bool = InventoryManager.merge_weapon(0)
	assert_true(result)
	assert_eq(InventoryManager.deployed_weapons.size(), 1)
	assert_eq(InventoryManager.deployed_weapons[0].id, "bow")
	assert_eq(InventoryManager.deployed_weapons[0].level, 2)

func test_merge_weapon_no_pair() -> void:
	InventoryManager.deployed_weapons = [
		{id = "bow", level = 1},
		{id = "sword", level = 1},
	]
	var result: bool = InventoryManager.merge_weapon(0)
	assert_false(result)
	assert_eq(InventoryManager.deployed_weapons.size(), 2)

func test_merge_weapon_invalid_index() -> void:
	InventoryManager.deployed_weapons = [{id = "bow", level = 1}]
	var result: bool = InventoryManager.merge_weapon(5)
	assert_false(result)

# ===== merge_tower 手动合成 =====

func test_merge_tower_success() -> void:
	InventoryManager.deployed_towers = [
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1},
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(10, 10), deploy_id = 2},
	]
	var result: bool = InventoryManager.merge_tower(1)
	assert_true(result)
	assert_eq(InventoryManager.deployed_towers.size(), 1)
	assert_eq(InventoryManager.deployed_towers[0].level, 2)
	assert_eq(InventoryManager.deployed_towers[0].deploy_id, 1)
	assert_eq(InventoryManager.deployed_towers[0].grid_pos, Vector2i(5, 5))

func test_merge_tower_no_pair() -> void:
	InventoryManager.deployed_towers = [
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1},
		{id = "ice_flower", level = 1, grid_pos = Vector2i(10, 10), deploy_id = 2},
	]
	var result: bool = InventoryManager.merge_tower(1)
	assert_false(result)

# ===== can_buy_item 简化 =====

func test_can_buy_item_population_available() -> void:
	assert_true(InventoryManager.can_buy_item("bow", 1))

func test_can_buy_item_population_full() -> void:
	var cap: int = PlayerProgression.get_population_cap()
	for i in cap:
		InventoryManager.deployed_weapons.append({id = "bow", level = 1})
	assert_false(InventoryManager.can_buy_item("bow", 1))

# ===== 购买不再自动合成 =====

func test_buy_weapon_no_auto_merge() -> void:
	InventoryManager.deployed_weapons = [{id = "bow", level = 1}]
	InventoryManager.buy_and_equip_weapon("bow", 3)
	assert_eq(InventoryManager.deployed_weapons.size(), 2)
	assert_eq(InventoryManager.deployed_weapons[0].level, 1)
	assert_eq(InventoryManager.deployed_weapons[1].level, 1)

