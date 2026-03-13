extends GutTest

func test_enemy_root_stops_movement():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	add_child(enemy)
	assert_false(enemy.is_rooted)
	enemy.apply_root(1.0)
	assert_true(enemy.is_rooted)
	assert_eq(enemy.speed, 0.0)
	enemy.queue_free()
