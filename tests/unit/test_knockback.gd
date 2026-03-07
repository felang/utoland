extends GutTest

# 击退系统单元测试

func test_knockback_changes_position():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	await get_tree().process_frame
	var original_pos: Vector2 = enemy.global_position
	var knockback_dir: Vector2 = Vector2.RIGHT
	enemy.apply_knockback(knockback_dir)
	await get_tree().create_timer(0.15).timeout
	assert_ne(enemy.global_position, original_pos, "击退后位置应改变")

func test_enemy_still_takes_damage_during_knockback():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	await get_tree().process_frame
	enemy.apply_knockback(Vector2.RIGHT)
	var hp_before: float = enemy.health.current_hp
	enemy.take_damage(10.0)
	assert_lt(enemy.health.current_hp, hp_before, "击退期间仍应可以受伤")
