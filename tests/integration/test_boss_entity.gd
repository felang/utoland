extends GutTest

var test_scene: Node2D

func before_each():
	test_scene = Node2D.new()
	add_child_autofree(test_scene)

func test_boss_brute_creation():
	var boss = SceneFactory.create_enemy("boss_brute")
	assert_not_null(boss, "应能创建 boss_brute")
	test_scene.add_child(boss)
	assert_eq(boss.enemy_type, "boss_brute")
	assert_true(boss.is_in_group(Enums.Group.ENEMIES))

func test_boss_brute_has_high_hp():
	var boss = SceneFactory.create_enemy("boss_brute")
	test_scene.add_child(boss)
	var normal_data: EnemyData = GameConfig.enemies["normal"]
	assert_gt(boss.health.max_hp, normal_data.hp * 5, "Boss HP 应远高于普通怪")

func test_boss_brute_stats_from_config():
	var boss = SceneFactory.create_enemy("boss_brute")
	test_scene.add_child(boss)
	var boss_data: EnemyData = GameConfig.enemies["boss_brute"]
	assert_eq(boss.health.max_hp, boss_data.hp)
	assert_eq(boss.speed, boss_data.speed)

func test_boss_emits_boss_killed_on_death():
	var boss = SceneFactory.create_enemy("boss_brute")
	test_scene.add_child(boss)
	watch_signals(EventBus)
	boss._on_died()
	assert_signal_emitted(EventBus, "boss_killed", "Boss 死亡应发出 boss_killed 信号")
	var params = get_signal_parameters(EventBus, "boss_killed")
	assert_eq(params[0], "boss_brute")

func test_boss_also_emits_enemy_killed():
	var boss = SceneFactory.create_enemy("boss_brute")
	test_scene.add_child(boss)
	watch_signals(EventBus)
	boss._on_died()
	assert_signal_emitted(EventBus, "enemy_killed", "Boss 死亡也应发出 enemy_killed 信号")
