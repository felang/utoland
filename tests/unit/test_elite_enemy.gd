extends GutTest

var test_scene: Node2D

func before_each():
	test_scene = Node2D.new()
	add_child_autofree(test_scene)

func test_enemy_default_not_elite():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	assert_eq(enemy.is_elite, false)
	assert_eq(enemy._elite_exp_mult, 1.0)

func test_apply_elite_sets_flag():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.apply_elite(1.5, 1.3, 1.2, 3.0)
	assert_true(enemy.is_elite)
	assert_true(enemy.is_in_group("elites"))

func test_apply_elite_boosts_hp():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	var base_hp: float = enemy.health.max_hp
	enemy.apply_elite(1.5, 1.3, 1.2, 3.0)
	assert_almost_eq(enemy.health.max_hp, base_hp * 1.5, 0.01)
	assert_almost_eq(enemy.health.current_hp, base_hp * 1.5, 0.01)

func test_apply_elite_boosts_damage():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	var base_damage: float = enemy._hitbox.damage
	enemy.apply_elite(1.5, 1.3, 1.2, 3.0)
	assert_almost_eq(enemy._hitbox.damage, base_damage * 1.3, 0.01)

func test_apply_elite_scales_size():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	var base_scale: Vector2 = enemy.scale
	enemy.apply_elite(1.5, 1.3, 1.2, 3.0)
	assert_almost_eq(enemy.scale.x, base_scale.x * 1.2, 0.01)
	assert_almost_eq(enemy.scale.y, base_scale.y * 1.2, 0.01)

func test_apply_elite_sets_exp_mult():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.apply_elite(1.5, 1.3, 1.2, 3.0)
	assert_eq(enemy._elite_exp_mult, 3.0)
