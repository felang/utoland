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
	data.projectile_type = Enums.ProjectileId.BULLET
	data.fire_rate = 0.5
	data.damage = 10.0
	mgr._add_weapon(data)
	assert_eq(mgr._weapons.size(), 1)
	assert_true(mgr._weapons[0] is BulletWeapon)

func test_add_weapon_creates_boomerang_weapon():
	var mgr = WeaponManager.new()
	add_child_autofree(mgr)
	var data = WeaponData.new()
	data.projectile_type = Enums.ProjectileId.BOOMERANG
	data.fire_rate = 1.0
	data.damage = 15.0
	mgr._add_weapon(data)
	assert_eq(mgr._weapons.size(), 1)
	assert_true(mgr._weapons[0] is BoomerangWeapon)

func test_add_weapon_creates_laser_weapon():
	var mgr = WeaponManager.new()
	add_child_autofree(mgr)
	var data = WeaponData.new()
	data.projectile_type = Enums.ProjectileId.LASER
	data.fire_rate = 2.0
	data.damage = 30.0
	mgr._add_weapon(data)
	assert_eq(mgr._weapons.size(), 1)
	assert_true(mgr._weapons[0] is LaserWeapon)
