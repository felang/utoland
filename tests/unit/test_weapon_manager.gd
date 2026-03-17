# tests/unit/test_weapon_manager.gd
extends GutTest

var _wm: WeaponManager
var _owner: Node2D

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	StatsTracker.reset()
	_owner = Node2D.new()
	add_child(_owner)
	_wm = WeaponManager.new()
	_owner.add_child(_wm)

func after_each() -> void:
	_owner.queue_free()

func test_add_weapon_creates_pivot() -> void:
	var count_before: int = _wm._pivots.size()
	_wm.add_weapon("bow", 1)
	assert_eq(_wm._pivots.size(), count_before + 1)
	assert_eq(_wm._weapon_data_list.size(), count_before + 1)

func test_pivot_has_target_finder_and_offset() -> void:
	_wm.add_weapon("bow", 1)
	var pivot: Node2D = _wm._pivots[0]
	assert_not_null(pivot.get_node_or_null("WeaponOffset"))
	assert_not_null(pivot.get_node_or_null("WeaponOffset/WeaponSprite"))
	assert_not_null(pivot.get_node_or_null("WeaponOffset/FirePoint"))
	# 索敌在 Pivot 下（以轨道位置为中心），攻击组件在 Offset 下
	assert_not_null(pivot.get_node_or_null("TargetFinderComponent"))

func test_pivot_has_attack_component() -> void:
	_wm.add_weapon("bow", 1)
	var pivot: Node2D = _wm._pivots[0]
	var ranged = pivot.get_node_or_null("RangedAttackComponent")
	var melee = pivot.get_node_or_null("MeleeAttackComponent")
	assert_true(ranged != null or melee != null, "Pivot 应有攻击组件")

func test_remove_weapon_removes_pivot() -> void:
	_wm.add_weapon("bow", 1)
	_wm.add_weapon("shuriken", 1)
	assert_eq(_wm._pivots.size(), 2)
	_wm.remove_weapon(0)
	assert_eq(_wm._pivots.size(), 1)
	assert_eq(_wm._weapon_data_list.size(), 1)

func test_remove_weapon_invalid_index_does_nothing() -> void:
	_wm.add_weapon("bow", 1)
	_wm.remove_weapon(99)
	assert_eq(_wm._pivots.size(), 1)

func test_refresh_weapons_syncs_with_deployed() -> void:
	InventoryManager.deployed_weapons = [
		{id = "bow", level = 1},
		{id = "shuriken", level = 1}
	]
	_wm.refresh_weapons()
	assert_eq(_wm._pivots.size(), 2)
	assert_eq(_wm._weapon_data_list.size(), 2)
