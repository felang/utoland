extends GutTest

# WeaponManager 单元测试

func test_weapon_manager_exists_on_player():
	var player_scene = preload("res://scenes/entities/player.tscn")
	var player = player_scene.instantiate()
	add_child_autoqfree(player)
	var weapon = player.get_node_or_null("WeaponManager")
	assert_not_null(weapon, "Player 应有 WeaponManager 子节点")
	assert_true(weapon is WeaponManager, "应为 WeaponManager 类型")
