# test_laser_projectile.gd — LaserProjectile 单元测试
extends GutTest

func _make_laser() -> LaserProjectile:
	var laser = LaserProjectile.new()
	var hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	var shape = CollisionShape2D.new()
	shape.name = "HitboxShape"
	hitbox.add_child(shape)
	laser.add_child(hitbox)
	add_child_autofree(laser)
	return laser

func test_laser_sets_correct_damage():
	var laser = _make_laser()
	await get_tree().process_frame
	laser.setup(42.0, 0.0, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(laser.hitbox.damage, 42.0)

func test_laser_frees_after_duration():
	var laser = _make_laser()
	await get_tree().process_frame
	laser.setup(20.0, 0.0, Vector2.ZERO, Vector2.RIGHT)
	laser._process(laser.beam_duration + 0.01)
	assert_true(laser.is_queued_for_deletion())

func test_laser_does_not_free_before_duration():
	var laser = _make_laser()
	await get_tree().process_frame
	laser.setup(20.0, 0.0, Vector2.ZERO, Vector2.RIGHT)
	laser._process(laser.beam_duration * 0.5)
	assert_false(laser.is_queued_for_deletion())
