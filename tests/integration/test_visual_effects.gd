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
	var pd := ProjectileData.new()
	pd.speed = 800.0
	pd.lifetime = 5.0
	pd.projectile_scene = preload("res://scenes/entities/projectiles/arrow.tscn")
	var bullet: Node2D = SceneFactory.create_projectile(pd, 10.0, Vector2.ZERO, Vector2.RIGHT)
	add_child_autoqfree(bullet)
	await get_tree().process_frame
	# TrailComponent 是投射物的子节点，其内部 Line2D 挂在 TrailComponent 下
	var trail_comp = bullet.get_node_or_null("TrailComponent")
	assert_not_null(trail_comp, "箭矢投射物应有 TrailComponent 子节点")
