extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	InventoryManager.coins = 0

func test_sell_lv1_tower_70_percent() -> void:
	var data: TowerData = GameConfig.towers["pea_shooter"]
	var base: int = data.sell_price_per_level[0]
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 1,
		grid_pos = Vector2i(0, 0), deploy_id = 1,
	})
	var refund: int = InventoryManager.sell_from_deployed_tower(1)
	assert_eq(refund, int(round(base * 0.7)))
	assert_eq(InventoryManager.coins, refund)
	assert_eq(InventoryManager.deployed_towers.size(), 0)

func test_sell_lv2_tower_70_percent_of_lv2_price() -> void:
	var data: TowerData = GameConfig.towers["pea_shooter"]
	if data.sell_price_per_level.size() < 2:
		pending("塔配置无 lv2 售价")
		return
	var base: int = data.sell_price_per_level[1]
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 2,
		grid_pos = Vector2i(0, 0), deploy_id = 1,
	})
	var refund: int = InventoryManager.sell_from_deployed_tower(1)
	assert_eq(refund, int(round(base * 0.7)))

func test_sell_weapon_70_percent() -> void:
	var data: WeaponData = GameConfig.weapons["bow"]
	var base: int = data.sell_price_per_level[0]
	InventoryManager.deployed_weapons.append({id = "bow", level = 1})
	var refund: int = InventoryManager.sell_from_deployed_weapon(0)
	assert_eq(refund, int(round(base * 0.7)))
