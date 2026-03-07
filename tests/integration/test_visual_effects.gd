extends GutTest

# 视觉效果集成测试

func test_enemy_death_triggers_effects():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	await get_tree().process_frame
	enemy.take_damage(999.0)
	await get_tree().process_frame
	var labels = get_tree().get_nodes_in_group("damage_numbers")
	assert_gt(labels.size(), 0, "敌人受击后应生成伤害数字")

func test_bullet_creates_trail():
	var bullet = SceneFactory.create_bullet()
	bullet.direction = Vector2.RIGHT
	add_child_autoqfree(bullet)
	await get_tree().process_frame
	var has_trail: bool = false
	for child in bullet.get_children():
		if child is Line2D:
			has_trail = true
			break
	assert_true(has_trail, "子弹应有 Line2D 拖尾子节点")

func test_boomerang_rotates():
	var boomerang = SceneFactory.create_boomerang()
	boomerang.direction = Vector2.RIGHT
	add_child_autoqfree(boomerang)
	var initial_rotation: float = boomerang.rotation
	await get_tree().create_timer(0.1).timeout
	assert_ne(boomerang.rotation, initial_rotation, "回旋镖应持续旋转")

