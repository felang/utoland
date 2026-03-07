extends GutTest

func test_hitbox_has_default_values():
	var hitbox = Hitbox.new()
	add_child_autofree(hitbox)
	assert_eq(hitbox.damage, 0.0)
	assert_eq(hitbox.knockback_force, 0.0)

func test_hitbox_values_can_be_set():
	var hitbox = Hitbox.new()
	add_child_autofree(hitbox)
	hitbox.damage = 25.0
	hitbox.knockback_force = 150.0
	assert_eq(hitbox.damage, 25.0)
	assert_eq(hitbox.knockback_force, 150.0)
