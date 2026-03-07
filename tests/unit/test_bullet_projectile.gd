# test_bullet_projectile.gd — BulletProjectile 单元测试
extends GutTest

func _make_bullet() -> BulletProjectile:
	var bullet = BulletProjectile.new()
	var hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	bullet.add_child(hitbox)
	add_child_autofree(bullet)
	return bullet

func test_bullet_moves_in_direction():
	var bullet = _make_bullet()
	await get_tree().process_frame
	bullet.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
	var start_x: float = bullet.global_position.x
	bullet._physics_process(0.1)
	assert_true(bullet.global_position.x > start_x, "bullet should move right")

func test_bullet_queue_frees_after_lifetime():
	var bullet = _make_bullet()
	await get_tree().process_frame
	bullet.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
	bullet._physics_process(bullet.lifetime + 0.1)
	assert_true(bullet.is_queued_for_deletion())
