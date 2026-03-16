# test_shuriken_projectile.gd — ShurikenProjectile 单元测试
extends GutTest

func _make_shuriken() -> ShurikenProjectile:
	var scene = preload("res://scenes/entities/projectiles/shuriken_projectile.tscn")
	var b: ShurikenProjectile = scene.instantiate()
	add_child_autofree(b)
	return b

func _get_shuriken_data() -> ProjectileData:
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.SHURIKEN]
	return w.projectile_data

func test_shuriken_moves_in_direction():
	var b = _make_shuriken()
	await get_tree().process_frame
	b.setup(_get_shuriken_data(), 10.0, Vector2.ZERO, Vector2.RIGHT)
	b._physics_process(0.1)
	assert_true(b.global_position.x > 0.0, "应向右飞行")

func test_shuriken_rotates():
	var b = _make_shuriken()
	await get_tree().process_frame
	b.setup(_get_shuriken_data(), 10.0, Vector2.ZERO, Vector2.RIGHT)
	var rot_before: float = b.rotation
	b._physics_process(0.1)
	assert_ne(b.rotation, rot_before, "应旋转")

func test_speed_from_projectile_data():
	var b = _make_shuriken()
	await get_tree().process_frame
	var pd: ProjectileData = _get_shuriken_data()
	b.setup(pd, 10.0, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b._speed, pd.speed, "速度应匹配 ProjectileData")

func test_lifetime_from_projectile_data():
	var b = _make_shuriken()
	await get_tree().process_frame
	var pd: ProjectileData = _get_shuriken_data()
	b.setup(pd, 10.0, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b._lifetime, pd.lifetime, "lifetime 应匹配 ProjectileData")

func test_shuriken_hit_count_starts_at_zero():
	var b = _make_shuriken()
	await get_tree().process_frame
	b.setup(_get_shuriken_data(), 10.0, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b._shuriken_hit_count, 0)
