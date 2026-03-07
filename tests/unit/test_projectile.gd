# test_projectile.gd — Projectile 基类单元测试
extends GutTest

func test_projectile_setup_sets_position_and_hitbox():
	var proj = Projectile.new()
	var hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	proj.add_child(hitbox)
	add_child_autofree(proj)
	await get_tree().process_frame

	proj.setup(30.0, 80.0, Vector2(100, 200), Vector2.RIGHT)

	assert_eq(proj.global_position, Vector2(100, 200))
	assert_eq(proj.hitbox.damage, 30.0)
	assert_eq(proj.hitbox.knockback_force, 80.0)
