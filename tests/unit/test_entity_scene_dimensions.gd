extends GutTest

func test_player_size_matches_30_grid():
	var scene = load("res://scenes/entities/player.tscn").instantiate()
	add_child_autofree(scene)
	var shape: RectangleShape2D = scene.get_node("CollisionShape2D").shape
	assert_eq(shape.size, Vector2(30, 30))

func test_enemy_sizes_match_new_standard():
	var normal = SceneFactory.create_enemy("normal")
	add_child_autofree(normal)
	assert_eq(normal.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var fast = SceneFactory.create_enemy("fast")
	add_child_autofree(fast)
	assert_eq(fast.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var tank = SceneFactory.create_enemy("tank")
	add_child_autofree(tank)
	assert_eq(tank.get_node("CollisionShape2D").shape.size, Vector2(45, 45))

func test_tower_sizes_match_new_standard():
	var shooter = SceneFactory.create_tower("shooter")
	add_child_autofree(shooter)
	assert_eq(shooter.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var wall = SceneFactory.create_tower("wall")
	add_child_autofree(wall)
	assert_eq(wall.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var slow = SceneFactory.create_tower("slow")
	add_child_autofree(slow)
	assert_eq(slow.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

func test_bullet_and_coin_sizes_match_new_standard():
	var bullet = load("res://scenes/entities/bullet.tscn").instantiate()
	add_child_autofree(bullet)
	assert_eq(bullet.get_node("CollisionShape2D").shape.size, Vector2(6, 6))

	var coin = load("res://scenes/entities/coin.tscn").instantiate()
	add_child_autofree(coin)
	assert_eq(coin.get_node("CollisionShape2D").shape.radius, 6.0)
