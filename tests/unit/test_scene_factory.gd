extends GutTest

# Unit tests for SceneFactory
# Tests tower, enemy, bullet, and coin creation

# Tower creation tests
func test_create_tower_shooter():
	var tower = SceneFactory.create_tower("shooter")
	assert_not_null(tower, "Shooter tower should be created")
	assert_eq(tower.tower_type, "shooter", "Tower type should be 'shooter'")
	tower.queue_free()

func test_create_tower_wall():
	var tower = SceneFactory.create_tower("wall")
	assert_not_null(tower, "Wall tower should be created")
	assert_eq(tower.tower_type, "wall", "Tower type should be 'wall'")
	tower.queue_free()

func test_create_tower_slow():
	var tower = SceneFactory.create_tower("slow")
	assert_not_null(tower, "Slow tower should be created")
	assert_eq(tower.tower_type, "slow", "Tower type should be 'slow'")
	tower.queue_free()

func test_create_tower_invalid():
	var tower = SceneFactory.create_tower("invalid_type")
	assert_null(tower, "Invalid tower type should return null")

# Enemy creation tests
func test_create_enemy_normal():
	var enemy = SceneFactory.create_enemy("normal")
	assert_not_null(enemy, "Normal enemy should be created")
	assert_eq(enemy.enemy_type, "normal", "Enemy type should be 'normal'")
	enemy.queue_free()

func test_create_enemy_fast():
	var enemy = SceneFactory.create_enemy("fast")
	assert_not_null(enemy, "Fast enemy should be created")
	assert_eq(enemy.enemy_type, "fast", "Enemy type should be 'fast'")
	enemy.queue_free()

func test_create_enemy_tank():
	var enemy = SceneFactory.create_enemy("tank")
	assert_not_null(enemy, "Tank enemy should be created")
	assert_eq(enemy.enemy_type, "tank", "Enemy type should be 'tank'")
	enemy.queue_free()

func test_create_enemy_invalid():
	var enemy = SceneFactory.create_enemy("invalid_type")
	assert_null(enemy, "Invalid enemy type should return null")

# Bullet and coin tests
func test_create_bullet():
	var bullet = SceneFactory.create_bullet()
	assert_not_null(bullet, "Bullet should be created")
	bullet.queue_free()

func test_create_coin():
	var coin = SceneFactory.create_coin()
	assert_not_null(coin, "Coin should be created")
	coin.queue_free()

# Tower cost test
func test_get_tower_cost():
	# Test shooter tower cost (average of 35 and 45 = 40)
	var shooter_cost = SceneFactory.get_tower_cost("shooter")
	assert_eq(shooter_cost, 40, "Shooter tower cost should be 40 (average of 35 and 45)")

	# Test wall tower cost (average of 35 and 45 = 40)
	var wall_cost = SceneFactory.get_tower_cost("wall")
	assert_eq(wall_cost, 40, "Wall tower cost should be 40 (average of 35 and 45)")

	# Test slow tower cost (average of 35 and 45 = 40)
	var slow_cost = SceneFactory.get_tower_cost("slow")
	assert_eq(slow_cost, 40, "Slow tower cost should be 40 (average of 35 and 45)")

	# Test invalid tower type
	var invalid_cost = SceneFactory.get_tower_cost("invalid_type")
	assert_eq(invalid_cost, 0, "Invalid tower type should return 0")
