extends GutTest

func test_player_size_matches_grid():
	var scene = load("res://scenes/entities/player.tscn").instantiate()
	add_child_autofree(scene)
	var shape: RectangleShape2D = scene.get_node("CollisionShape2D").shape
	assert_eq(shape.size, Vector2(16, 16))

func test_enemy_sizes_match_new_standard():
	var normal = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	add_child_autofree(normal)
	assert_eq(normal.get_node("CollisionShape2D").shape.size, Vector2(16, 16))

	var fast = SceneFactory.create_enemy(Enums.Enemy.FAST)
	add_child_autofree(fast)
	assert_eq(fast.get_node("CollisionShape2D").shape.size, Vector2(16, 16))

	var tank = SceneFactory.create_enemy(Enums.Enemy.TANK)
	add_child_autofree(tank)
	assert_eq(tank.get_node("CollisionShape2D").shape.size, Vector2(32, 32))

func test_tower_sizes_match_new_standard():
	var shooter = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	add_child_autofree(shooter)
	assert_eq(shooter.get_node("CollisionShape2D").shape.size, Vector2(16, 16))

	var wall = SceneFactory.create_tower(Enums.TowerId.STUMP)
	add_child_autofree(wall)
	assert_eq(wall.get_node("CollisionShape2D").shape.size, Vector2(16, 16))

	var slow = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	add_child_autofree(slow)
	assert_eq(slow.get_node("CollisionShape2D").shape.size, Vector2(16, 16))

func test_bullet_projectile_and_coin_sizes_match_new_standard():
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	add_child_autofree(bullet)
	var hitbox_shape: CollisionShape2D = bullet.get_node("Hitbox/CollisionShape2D")
	assert_not_null(hitbox_shape, "BulletProjectile 应有 Hitbox/CollisionShape2D")
	assert_true(hitbox_shape.shape is CircleShape2D, "BulletProjectile 碰撞形状应为 CircleShape2D")

	var coin = load("res://scenes/entities/coin.tscn").instantiate()
	add_child_autofree(coin)
	assert_eq(coin.get_node("CollisionShape2D").shape.radius, 3.0)

func test_coin_sprite_scale_is_integer():
	var coin = load("res://scenes/entities/coin.tscn").instantiate()
	add_child_autofree(coin)
	var visual: Sprite2D = coin.get_node("Visual")
	assert_eq(visual.scale, Vector2(1.0, 1.0))
