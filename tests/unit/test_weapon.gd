# test_weapon.gd — Weapon 基类单元测试（组合 AttackerComponent）
extends GutTest

func _create_weapon_with_data() -> Weapon:
	var w = Weapon.new()
	add_child_autofree(w)
	var data = WeaponData.new()
	data.id = "test_weapon"
	data.attack_mode = 0
	data.fire_rate_per_level = PackedFloat32Array([1.0])
	data.damage_per_level = PackedFloat32Array([10.0])
	data.weapon_range_per_level = PackedFloat32Array([300.0])
	w.initialize(data)
	w.set_level(1)
	return w

func test_weapon_initialize_creates_attacker():
	var w = _create_weapon_with_data()
	assert_not_null(w.attacker, "initialize 应创建 AttackerComponent")
	assert_true(w.attacker is AttackerComponent)

func test_weapon_set_level_updates_attacker_stats():
	var w = _create_weapon_with_data()
	assert_almost_eq(w.attacker.base_damage, 10.0, 0.01, "set_level 应更新 attacker base_damage")
	assert_almost_eq(w.attacker.attack_range, 300.0, 0.01, "set_level 应更新 attacker attack_range")
	assert_almost_eq(w.attacker.base_cooldown, 1.0, 0.01, "set_level 应更新 attacker base_cooldown")

func test_weapon_get_current_level():
	var w = _create_weapon_with_data()
	assert_eq(w.get_current_level(), 1)
