extends GutTest

# 视觉效果集成测试

func test_enemy_death_triggers_effects():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	add_child_autoqfree(enemy)
	await get_tree().process_frame
	enemy.take_damage(999.0)
	await get_tree().process_frame
	var labels = get_tree().get_nodes_in_group(Enums.Group.DAMAGE_NUMBERS)
	assert_gt(labels.size(), 0, "敌人受击后应生成伤害数字")

func test_bullet_projectile_creates_trail():
	var bullet: ProjectileBase = SceneFactory.create_bullet_projectile()
	add_child_autoqfree(bullet)
	await get_tree().process_frame
	var pd := ProjectileData.new()
	pd.speed = 800.0
	pd.lifetime = 5.0
	pd.trail_enabled = true
	bullet.setup(pd, 10.0, Vector2.ZERO, Vector2.RIGHT)
	await get_tree().process_frame
	var has_trail: bool = false
	for child in bullet.get_children():
		if child is Line2D:
			has_trail = true
			break
	assert_true(has_trail, "子弹投射物应有 Line2D 拖尾子节点")

func test_shuriken_projectile_rotates():
	var shuriken: ShurikenProjectile = SceneFactory.create_shuriken_projectile()
	add_child_autoqfree(shuriken)
	await get_tree().process_frame
	var shuriken_pd: ProjectileData = GameConfig.weapons[Enums.WeaponId.SHURIKEN].projectile_data
	shuriken.setup(shuriken_pd, 10.0, Vector2.ZERO, Vector2.RIGHT)
	var initial_rotation: float = shuriken.rotation
	await get_tree().create_timer(0.1).timeout
	assert_ne(shuriken.rotation, initial_rotation, "手里剑投射物应持续旋转")

