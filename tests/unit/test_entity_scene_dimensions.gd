extends GutTest

func test_player_size_matches_30_grid():
	var scene = load("res://scenes/player.tscn").instantiate()
	add_child_autofree(scene)
	var shape: RectangleShape2D = scene.get_node("CollisionShape2D").shape
	assert_eq(shape.size, Vector2(30, 30))

func test_enemy_sizes_match_new_standard():
	var normal = load("res://scenes/enemies/enemy_normal.tscn").instantiate()
	add_child_autofree(normal)
	assert_eq(normal.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var fast = load("res://scenes/enemies/enemy_fast.tscn").instantiate()
	add_child_autofree(fast)
	assert_eq(fast.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var tank = load("res://scenes/enemies/enemy_tank.tscn").instantiate()
	add_child_autofree(tank)
	assert_eq(tank.get_node("CollisionShape2D").shape.size, Vector2(45, 45))

func test_tower_sizes_match_new_standard():
	var shooter = load("res://scenes/towers/tower_shooter.tscn").instantiate()
	add_child_autofree(shooter)
	assert_eq(shooter.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var wall = load("res://scenes/towers/tower_wall.tscn").instantiate()
	add_child_autofree(wall)
	assert_eq(wall.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var slow = load("res://scenes/towers/tower_slow.tscn").instantiate()
	add_child_autofree(slow)
	assert_eq(slow.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

func test_bullet_and_coin_sizes_match_new_standard():
	var bullet = load("res://scenes/bullet.tscn").instantiate()
	add_child_autofree(bullet)
	assert_eq(bullet.get_node("CollisionShape2D").shape.size, Vector2(6, 6))

	var coin = load("res://scenes/coin.tscn").instantiate()
	add_child_autofree(coin)
	assert_eq(coin.get_node("CollisionShape2D").shape.radius, 6.0)
