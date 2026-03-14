extends GutTest

# --- Rifle ---
func test_rifle_damage_level1() -> void:
	var wd: WeaponData = GameConfig.weapons[Enums.WeaponId.RIFLE]
	assert_almost_eq(wd.damage_per_level[0], 8.0, 0.01, "Rifle Lv1 伤害应为 8")

func test_rifle_damage_level3() -> void:
	var wd: WeaponData = GameConfig.weapons[Enums.WeaponId.RIFLE]
	assert_almost_eq(wd.damage_per_level[2], 34.0, 0.01, "Rifle Lv3 伤害应为 34")

func test_rifle_fire_rate_level1() -> void:
	var wd: WeaponData = GameConfig.weapons[Enums.WeaponId.RIFLE]
	assert_almost_eq(wd.fire_rate_per_level[0], 0.12, 0.001, "Rifle Lv1 fire_rate 应为 0.12")

func test_rifle_fire_rate_level3() -> void:
	var wd: WeaponData = GameConfig.weapons[Enums.WeaponId.RIFLE]
	assert_almost_eq(wd.fire_rate_per_level[2], 0.08, 0.001, "Rifle Lv3 fire_rate 应为 0.08")

# --- Shotgun ---
func test_shotgun_damage_level1() -> void:
	var wd: WeaponData = GameConfig.weapons[Enums.WeaponId.SHOTGUN]
	assert_almost_eq(wd.damage_per_level[0], 8.0, 0.01, "Shotgun Lv1 伤害应为 8")

func test_shotgun_damage_level3() -> void:
	var wd: WeaponData = GameConfig.weapons[Enums.WeaponId.SHOTGUN]
	assert_almost_eq(wd.damage_per_level[2], 30.0, 0.01, "Shotgun Lv3 伤害应为 30")

# --- Laser ---
func test_laser_damage_level1() -> void:
	var wd: WeaponData = GameConfig.weapons[Enums.WeaponId.LASER]
	assert_almost_eq(wd.damage_per_level[0], 12.0, 0.01, "Laser Lv1 伤害应为 12")

func test_laser_damage_level3() -> void:
	var wd: WeaponData = GameConfig.weapons[Enums.WeaponId.LASER]
	assert_almost_eq(wd.damage_per_level[2], 40.0, 0.01, "Laser Lv3 伤害应为 40")

# --- 对比：Laser 伤害高于 Rifle ---
func test_laser_damage_higher_than_rifle_at_each_level() -> void:
	var rifle: WeaponData = GameConfig.weapons[Enums.WeaponId.RIFLE]
	var laser: WeaponData = GameConfig.weapons[Enums.WeaponId.LASER]
	for i in range(3):
		assert_gt(laser.damage_per_level[i], rifle.damage_per_level[i],
			"Laser Lv%d 伤害应高于 Rifle" % (i + 1))
