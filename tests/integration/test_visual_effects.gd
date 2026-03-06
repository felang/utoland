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

func test_enemy_has_all_feedback_methods():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	assert_true(enemy.has_method("apply_knockback"), "应有击退方法")
	assert_true(enemy.has_method("_flash_white"), "应有闪白方法")
	assert_true(enemy.has_method("take_damage"), "应有受伤方法")

func test_effects_manager_available():
	assert_not_null(EffectsManager, "EffectsManager 应作为 autoload 可用")
	assert_true(EffectsManager.has_method("spawn_damage_number"), "应有伤害数字方法")
	assert_true(EffectsManager.has_method("spawn_hit_sparks"), "应有击中火花方法")
	assert_true(EffectsManager.has_method("spawn_death_effect"), "应有死亡特效方法")
