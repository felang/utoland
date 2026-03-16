# test_weapon_manager.gd — WeaponManager 单元测试
extends GutTest

func test_weapon_manager_starts_empty():
	var mgr = WeaponManager.new()
	add_child_autofree(mgr)
	assert_eq(mgr._weapons.size(), 0)

func test_add_weapon_creates_weapon_for_bow():
	var mgr = WeaponManager.new()
	add_child_autofree(mgr)
	var data = WeaponData.new()
	data.id = "test_bow"
	data.attack_mode = 0
	data.fire_rate_per_level = PackedFloat32Array([0.5])
	data.damage_per_level = PackedFloat32Array([10.0])
	data.weapon_range_per_level = PackedFloat32Array([300.0])
	mgr._add_weapon(data, "bow")
	assert_eq(mgr._weapons.size(), 1)
	assert_true(mgr._weapons[0] is Weapon)

func test_add_weapon_creates_shuriken_weapon():
	var mgr = WeaponManager.new()
	add_child_autofree(mgr)
	var data = WeaponData.new()
	data.id = "test_shuriken"
	data.attack_mode = 0
	data.fire_rate_per_level = PackedFloat32Array([1.0])
	data.damage_per_level = PackedFloat32Array([15.0])
	data.weapon_range_per_level = PackedFloat32Array([200.0])
	mgr._add_weapon(data, "shuriken")
	assert_eq(mgr._weapons.size(), 1)
	assert_true(mgr._weapons[0] is ShurikenWeapon)

func test_add_weapon_creates_weapon_for_sword():
	var mgr = WeaponManager.new()
	add_child_autofree(mgr)
	var data = WeaponData.new()
	data.id = "test_sword"
	data.attack_mode = 1
	data.fire_rate_per_level = PackedFloat32Array([0.4])
	data.damage_per_level = PackedFloat32Array([20.0])
	data.weapon_range_per_level = PackedFloat32Array([60.0])
	mgr._add_weapon(data, "sword")
	assert_eq(mgr._weapons.size(), 1)
	assert_true(mgr._weapons[0] is Weapon)
