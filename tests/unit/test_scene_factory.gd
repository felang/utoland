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

# Tower cost test
func test_get_tower_cost():
	# Test shooter tower cost (average of 35 and 45 = 40)
	var shooter_cost = SceneFactory.get_tower_cost(Enums.TowerId.SHOOTER)
	assert_eq(shooter_cost, 40, "Shooter tower cost should be 40 (average of 35 and 45)")

	# Test wall tower cost (average of 35 and 45 = 40)
	var wall_cost = SceneFactory.get_tower_cost(Enums.TowerId.WALL)
	assert_eq(wall_cost, 40, "Wall tower cost should be 40 (average of 35 and 45)")

	# Test slow tower cost (average of 35 and 45 = 40)
	var slow_cost = SceneFactory.get_tower_cost(Enums.TowerId.SLOW)
	assert_eq(slow_cost, 40, "Slow tower cost should be 40 (average of 35 and 45)")

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
