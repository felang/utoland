# test_shuriken_projectile.gd — ShurikenProjectile 单元测试
extends GutTest

func _make_shuriken() -> ShurikenProjectile:
	var b = ShurikenProjectile.new()
	var hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	b.add_child(hitbox)
	b.weapon_data = GameConfig.weapons[Enums.WeaponId.SHURIKEN]
	add_child_autofree(b)
	return b

func test_shuriken_moves_in_direction():
	var b = _make_shuriken()
	await get_tree().process_frame
	b.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
	b._physics_process(0.1)
	assert_true(b.global_position.x > 0.0, "应向右飞行")

func test_shuriken_rotates():
	var b = _make_shuriken()
	await get_tree().process_frame
	b.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
	var rot_before: float = b.rotation
	b._physics_process(0.1)
	assert_ne(b.rotation, rot_before, "应旋转")

func test_max_lifetime_from_config():
	var b = _make_shuriken()
	await get_tree().process_frame
	b.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.SHURIKEN]
	assert_eq(b.max_lifetime, w.projectile_data.lifetime, "max_lifetime 应匹配配置")

func test_hit_count_starts_at_zero():
	var b = _make_shuriken()
	await get_tree().process_frame
	b.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b._hit_count, 0)
