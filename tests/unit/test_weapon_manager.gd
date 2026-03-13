# test_weapon_manager.gd — WeaponManager 单元测试
extends GutTest

func test_weapon_manager_starts_empty():
	var mgr = WeaponManager.new()
	add_child_autofree(mgr)
	assert_eq(mgr._weapons.size(), 0)

func test_add_weapon_creates_bullet_weapon():
	var mgr = WeaponManager.new()
	add_child_autofree(mgr)
	var data = WeaponData.new()
	data.id = "test_bullet"
	data.projectile_type = Enums.ProjectileId.BULLET
	data.weapon_type = "bullet"
	data.fire_rate_per_level = PackedFloat32Array([0.5])
	data.damage_per_level = PackedFloat32Array([10.0])
	data.weapon_range_per_level = PackedFloat32Array([300.0])
	GameData.owned_weapons[data.id] = 1
	mgr._add_weapon(data)
	assert_eq(mgr._weapons.size(), 1)
	assert_true(mgr._weapons[0] is BulletWeapon)
	GameData.owned_weapons.erase(data.id)

func test_add_weapon_creates_boomerang_weapon():
	var mgr = WeaponManager.new()
	add_child_autofree(mgr)
	var data = WeaponData.new()
	data.id = "test_boomerang"
	data.projectile_type = Enums.ProjectileId.BOOMERANG
	data.weapon_type = "boomerang"
	data.fire_rate_per_level = PackedFloat32Array([1.0])
	data.damage_per_level = PackedFloat32Array([15.0])
	data.weapon_range_per_level = PackedFloat32Array([200.0])
	GameData.owned_weapons[data.id] = 1
	mgr._add_weapon(data)
	assert_eq(mgr._weapons.size(), 1)
	assert_true(mgr._weapons[0] is BoomerangWeapon)
	GameData.owned_weapons.erase(data.id)

func test_add_weapon_creates_laser_weapon():
	var mgr = WeaponManager.new()
	add_child_autofree(mgr)
	var data = WeaponData.new()
	data.id = "test_laser"
	data.projectile_type = Enums.ProjectileId.LASER
	data.weapon_type = "laser"
	data.fire_rate_per_level = PackedFloat32Array([2.0])
	data.damage_per_level = PackedFloat32Array([30.0])
	data.weapon_range_per_level = PackedFloat32Array([400.0])
	GameData.owned_weapons[data.id] = 1
	mgr._add_weapon(data)
	assert_eq(mgr._weapons.size(), 1)
	assert_true(mgr._weapons[0] is LaserWeapon)
	GameData.owned_weapons.erase(data.id)
