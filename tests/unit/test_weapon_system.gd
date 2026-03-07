extends GutTest

# WeaponSystem 单元测试

func test_weapon_system_exists_on_player():
	var player_scene = preload("res://scenes/entities/player.tscn")
	var player = player_scene.instantiate()
	add_child_autoqfree(player)
	var weapon = player.get_node_or_null("WeaponSystem")
	assert_not_null(weapon, "Player 应有 WeaponSystem 子节点")
	assert_true(weapon is WeaponSystem, "应为 WeaponSystem 类型")

func test_weapon_system_has_auto_shoot():
	var ws = WeaponSystem.new()
	add_child_autoqfree(ws)
	assert_true(ws.has_method("auto_shoot"), "WeaponSystem 应有 auto_shoot 方法")

func test_weapon_system_has_shoot_weapon():
	var ws = WeaponSystem.new()
	add_child_autoqfree(ws)
	assert_true(ws.has_method("shoot_weapon"), "WeaponSystem 应有 shoot_weapon 方法")

func test_initialize_from_weapon_data():
	var ws = WeaponSystem.new()
	var node = Node2D.new()
	node.add_child(ws)
	add_child_autofree(node)

	# 从 GameConfig 获取武器资源
	var weapon_res: WeaponData = null
	for id in GameConfig.weapons:
		weapon_res = GameConfig.weapons[id]
		break

	if weapon_res:
		ws.initialize(weapon_res, 1.0, 1.0)
		assert_eq(ws.weapon_damage, weapon_res.damage, "初始化后 damage 应匹配")
		assert_eq(ws.fire_rate, weapon_res.fire_rate, "初始化后 fire_rate 应匹配")
		assert_eq(ws.weapon_range, weapon_res.weapon_range, "初始化后 range 应匹配")

func test_initialize_with_multipliers():
	var ws = WeaponSystem.new()
	var node = Node2D.new()
	node.add_child(ws)
	add_child_autofree(node)

	var weapon_res: WeaponData = null
	for id in GameConfig.weapons:
		weapon_res = GameConfig.weapons[id]
		break

	if weapon_res:
		ws.initialize(weapon_res, 2.0, 1.5)
		assert_eq(ws.weapon_damage, weapon_res.damage * 2.0, "damage 应乘以 damage_mult")
		assert_almost_eq(ws.fire_rate, weapon_res.fire_rate / 1.5, 0.01, "fire_rate 应除以 attack_speed_mult")
