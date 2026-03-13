extends GutTest

# Unit tests for SceneFactory
# Tests tower, enemy, bullet, and coin creation

# Tower creation tests
func test_create_tower_shooter():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	assert_not_null(tower, "Pea shooter tower should be created")
	assert_eq(tower.tower_type, Enums.TowerId.PEA_SHOOTER, "Tower type should be 'pea_shooter'")
	tower.queue_free()

func test_create_tower_wall():
	var tower = SceneFactory.create_tower(Enums.TowerId.STUMP)
	assert_not_null(tower, "Stump tower should be created")
	assert_eq(tower.tower_type, Enums.TowerId.STUMP, "Tower type should be 'stump'")
	tower.queue_free()

func test_create_tower_slow():
	var tower = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	assert_not_null(tower, "Ice flower tower should be created")
	assert_eq(tower.tower_type, Enums.TowerId.ICE_FLOWER, "Tower type should be 'ice_flower'")
	tower.queue_free()

func test_create_tower_cactus():
	var tower = SceneFactory.create_tower(Enums.TowerId.CACTUS)
	assert_not_null(tower, "应能创建仙人掌塔")
	assert_eq(tower.tower_type, Enums.TowerId.CACTUS)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_rose():
	var tower = SceneFactory.create_tower(Enums.TowerId.ROSE)
	assert_not_null(tower, "应能创建玫瑰塔")
	assert_eq(tower.tower_type, Enums.TowerId.ROSE)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_mushroom():
	var tower = SceneFactory.create_tower(Enums.TowerId.MUSHROOM)
	assert_not_null(tower, "应能创建毒蘑菇塔")
	assert_eq(tower.tower_type, Enums.TowerId.MUSHROOM)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_vine():
	var tower = SceneFactory.create_tower(Enums.TowerId.VINE)
	assert_not_null(tower, "应能创建藤蔓塔")
	assert_eq(tower.tower_type, Enums.TowerId.VINE)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_dandelion():
	var tower = SceneFactory.create_tower(Enums.TowerId.DANDELION)
	assert_not_null(tower, "应能创建蒲公英塔")
	assert_eq(tower.tower_type, Enums.TowerId.DANDELION)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_pitcher():
	var tower = SceneFactory.create_tower(Enums.TowerId.PITCHER)
	assert_not_null(tower, "应能创建猪笼草塔")
	assert_eq(tower.tower_type, Enums.TowerId.PITCHER)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_thorn():
	var tower = SceneFactory.create_tower(Enums.TowerId.THORN)
	assert_not_null(tower, "应能创建荆棘塔")
	assert_eq(tower.tower_type, Enums.TowerId.THORN)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_oak():
	var tower = SceneFactory.create_tower(Enums.TowerId.OAK)
	assert_not_null(tower, "应能创建橡树塔")
	assert_eq(tower.tower_type, Enums.TowerId.OAK)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_sunflower():
	var tower = SceneFactory.create_tower(Enums.TowerId.SUNFLOWER)
	assert_not_null(tower, "应能创建向日葵塔")
	assert_eq(tower.tower_type, Enums.TowerId.SUNFLOWER)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_mint():
	var tower = SceneFactory.create_tower(Enums.TowerId.MINT)
	assert_not_null(tower, "应能创建薄荷塔")
	assert_eq(tower.tower_type, Enums.TowerId.MINT)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_heal_flower():
	var tower = SceneFactory.create_tower(Enums.TowerId.HEAL_FLOWER)
	assert_not_null(tower, "应能创建治愈花塔")
	assert_eq(tower.tower_type, Enums.TowerId.HEAL_FLOWER)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_bamboo():
	var tower = SceneFactory.create_tower(Enums.TowerId.BAMBOO)
	assert_not_null(tower, "应能创建爆竹竹塔")
	assert_eq(tower.tower_type, Enums.TowerId.BAMBOO)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_invalid():
	var tower = SceneFactory.create_tower("invalid_type")
	assert_null(tower, "Invalid tower type should return null")
	assert_push_error("Unknown tower type")

# Enemy creation tests
func test_create_enemy_normal():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	assert_not_null(enemy, "Normal enemy should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.NORMAL, "Enemy type should be 'normal'")
	enemy.queue_free()

func test_create_enemy_fast():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.FAST)
	assert_not_null(enemy, "Fast enemy should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.FAST, "Enemy type should be 'fast'")
	enemy.queue_free()

func test_create_enemy_tank():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.TANK)
	assert_not_null(enemy, "Tank enemy should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.TANK, "Enemy type should be 'tank'")
	enemy.queue_free()

func test_create_enemy_invalid():
	var enemy = SceneFactory.create_enemy("invalid_type")
	assert_null(enemy, "Invalid enemy type should return null")
	assert_push_error("Unknown enemy type")

# Coin tests
func test_create_coin():
	var coin = SceneFactory.create_coin()
	assert_not_null(coin, "Coin should be created")
	coin.queue_free()

# Tower cost test — 费用现在按等级读取 place_cost_per_level
func test_get_tower_cost():
	var shooter_cost = SceneFactory.get_tower_cost(Enums.TowerId.PEA_SHOOTER)
	var shooter_td: TowerData = GameConfig.towers[Enums.TowerId.PEA_SHOOTER]
	assert_eq(shooter_cost, shooter_td.place_cost_per_level[0], "Shooter tower cost should match level 1 place_cost")

	var wall_cost = SceneFactory.get_tower_cost(Enums.TowerId.STUMP)
	var wall_td: TowerData = GameConfig.towers[Enums.TowerId.STUMP]
	assert_eq(wall_cost, wall_td.place_cost_per_level[0], "Wall tower cost should match level 1 place_cost")

	var slow_cost = SceneFactory.get_tower_cost(Enums.TowerId.ICE_FLOWER)
	var slow_td: TowerData = GameConfig.towers[Enums.TowerId.ICE_FLOWER]
	assert_eq(slow_cost, slow_td.place_cost_per_level[0], "Slow tower cost should match level 1 place_cost")

	# Test invalid tower type
	var invalid_cost = SceneFactory.get_tower_cost("invalid_type")
	assert_eq(invalid_cost, 0, "Invalid tower type should return 0")
	assert_push_error("Unknown tower type")

# 新投射物工厂方法测试
func test_create_bullet_projectile():
	var bullet = SceneFactory.create_bullet_projectile()
	assert_not_null(bullet, "BulletProjectile should be created")
	bullet.queue_free()

func test_create_boomerang_projectile():
	var boomerang = SceneFactory.create_boomerang_projectile()
	assert_not_null(boomerang, "BoomerangProjectile should be created")
	boomerang.queue_free()

func test_create_laser_projectile():
	var beam = SceneFactory.create_laser_projectile()
	assert_not_null(beam, "LaserProjectile should be created")
	beam.queue_free()

func test_all_towers_can_be_created():
	var all_ids: Array[String] = [
		Enums.TowerId.PEA_SHOOTER, Enums.TowerId.STUMP, Enums.TowerId.ICE_FLOWER,
		Enums.TowerId.CACTUS, Enums.TowerId.ROSE, Enums.TowerId.MUSHROOM,
		Enums.TowerId.VINE, Enums.TowerId.DANDELION, Enums.TowerId.PITCHER,
		Enums.TowerId.THORN, Enums.TowerId.OAK, Enums.TowerId.SUNFLOWER,
		Enums.TowerId.MINT, Enums.TowerId.HEAL_FLOWER, Enums.TowerId.BAMBOO,
	]
	for id in all_ids:
		var tower = SceneFactory.create_tower(id)
		assert_not_null(tower, "应能创建塔: " + id)
		add_child(tower)
		assert_eq(tower.tower_type, id)
		assert_not_null(tower.data, id + " 应注入 TowerData")
		tower.queue_free()

func test_all_weapons_loaded():
	var all_ids: Array[String] = [
		Enums.WeaponId.RIFLE, Enums.WeaponId.BOOMERANG, Enums.WeaponId.LASER,
		Enums.WeaponId.SHOTGUN, Enums.WeaponId.MINIGUN, Enums.WeaponId.ROCKET,
		Enums.WeaponId.FLAMETHROWER, Enums.WeaponId.LIGHTNING,
		Enums.WeaponId.ICE_GUN, Enums.WeaponId.BLADE,
	]
	for id in all_ids:
		assert_true(GameConfig.weapons.has(id), "应包含武器: " + id)
		var w: WeaponData = GameConfig.weapons[id]
		assert_ne(w.weapon_type, "", id + " 应有 weapon_type")
		assert_eq(w.damage_per_level.size(), w.max_level, id + " damage_per_level 数量应匹配 max_level")
