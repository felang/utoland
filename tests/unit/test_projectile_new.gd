extends GutTest

func test_projectile_has_direction() -> void:
	var proj := Projectile.new()
	proj.direction = Vector2.RIGHT
	assert_eq(proj.direction, Vector2.RIGHT)
	proj.free()

func test_projectile_should_destroy_default_false() -> void:
	var proj := Projectile.new()
	assert_false(proj._should_destroy)
	proj.free()

func test_has_lifecycle_component_false_when_none() -> void:
	var proj := Projectile.new()
	add_child(proj)
	assert_false(proj._has_lifecycle_component())
	proj.queue_free()

func test_has_lifecycle_component_true_with_pierce() -> void:
	var proj := Projectile.new()
	var pierce := PierceComponent.new()
	proj.add_child(pierce)
	add_child(proj)
	assert_true(proj._has_lifecycle_component())
	proj.queue_free()

func test_reset_for_pool_clears_destroy_flag() -> void:
	var proj := Projectile.new()
	add_child(proj)
	proj._should_destroy = true
	proj.reset_for_pool()
	assert_false(proj._should_destroy)
	proj.queue_free()
