# tests/unit/test_weapon_manager.gd
extends GutTest

var _wm: WeaponManager
var _owner: Node2D

func before_each() -> void:
	GameData.reset()
	_owner = Node2D.new()
	add_child(_owner)
	_wm = WeaponManager.new()
	_owner.add_child(_wm)

func after_each() -> void:
	_owner.queue_free()

func test_add_weapon_creates_weapon_node() -> void:
	var count_before: int = _wm._weapons.size()
	_wm.add_weapon("bow", 1)
	assert_eq(_wm._weapons.size(), count_before + 1)
	assert_eq(_wm._weapon_sprites.size(), count_before + 1)

func test_remove_weapon_removes_weapon_node() -> void:
	_wm.add_weapon("bow", 1)
	_wm.add_weapon("shuriken", 1)
	assert_eq(_wm._weapons.size(), 2)
	_wm.remove_weapon(0)
	assert_eq(_wm._weapons.size(), 1)
	assert_eq(_wm._weapon_sprites.size(), 1)

func test_remove_weapon_invalid_index_does_nothing() -> void:
	_wm.add_weapon("bow", 1)
	_wm.remove_weapon(99)
	assert_eq(_wm._weapons.size(), 1)

func test_refresh_weapons_syncs_with_deployed() -> void:
	GameData.deployed_weapons = [
		{id = "bow", level = 1},
		{id = "shuriken", level = 1}
	]
	_wm.refresh_weapons()
	assert_eq(_wm._weapons.size(), 2)
