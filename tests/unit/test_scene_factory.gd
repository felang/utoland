extends GutTest

# Unit tests for SceneFactory
# Tests tower, enemy, bullet, and coin creation

# Tower creation tests
func test_create_tower_shooter():
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	assert_not_null(tower, "Shooter tower should be created")
	assert_eq(tower.tower_type, Enums.TowerId.SHOOTER, "Tower type should be 'shooter'")
	tower.queue_free()

func test_create_tower_wall():
	var tower = SceneFactory.create_tower(Enums.TowerId.WALL)
	assert_not_null(tower, "Wall tower should be created")
	assert_eq(tower.tower_type, Enums.TowerId.WALL, "Tower type should be 'wall'")
	tower.queue_free()

func test_create_tower_slow():
	var tower = SceneFactory.create_tower(Enums.TowerId.SLOW)
	assert_not_null(tower, "Slow tower should be created")
	assert_eq(tower.tower_type, Enums.TowerId.SLOW, "Tower type should be 'slow'")
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
	var shooter_cost = SceneFactory.get_tower_cost(Enums.TowerId.SHOOTER)
	var shooter_td: TowerData = GameConfig.towers[Enums.TowerId.SHOOTER]
	assert_eq(shooter_cost, shooter_td.place_cost_per_level[0], "Shooter tower cost should match level 1 place_cost")

	var wall_cost = SceneFactory.get_tower_cost(Enums.TowerId.WALL)
	var wall_td: TowerData = GameConfig.towers[Enums.TowerId.WALL]
	assert_eq(wall_cost, wall_td.place_cost_per_level[0], "Wall tower cost should match level 1 place_cost")

	var slow_cost = SceneFactory.get_tower_cost(Enums.TowerId.SLOW)
	var slow_td: TowerData = GameConfig.towers[Enums.TowerId.SLOW]
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
