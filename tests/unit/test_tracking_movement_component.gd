extends GutTest

func test_on_projectile_setup_reads_data() -> void:
	var comp := TrackingMovementComponent.new()
	add_child(comp)
	var proj := Node2D.new()
	proj.set_script(load("res://scripts/entities/projectiles/projectile.gd"))
	add_child(proj)
	var data := ProjectileData.new()
	data.speed = 500.0
	data.lifetime = 3.0
	proj.data = data
	var target := Node2D.new()
	add_child(target)
	proj.target = target
	comp.on_projectile_setup(proj)
	assert_eq(comp.speed, 500.0)
	assert_eq(comp.lifetime, 3.0)
	assert_eq(comp._target, target)
	target.queue_free()
	proj.queue_free()
	comp.queue_free()

func test_tracking_adjusts_direction() -> void:
	var comp := TrackingMovementComponent.new()
	comp.turn_speed = 20.0
	var proj := Node2D.new()
	proj.set_script(load("res://scripts/entities/projectiles/projectile.gd"))
	add_child(proj)
	proj.global_position = Vector2.ZERO
	proj.direction = Vector2.RIGHT
	var data := ProjectileData.new()
	data.speed = 100.0
	data.lifetime = 5.0
	proj.data = data
	var target := Node2D.new()
	add_child(target)
	target.global_position = Vector2(0, 100)
	proj.target = target
	proj.add_child(comp)
	comp.on_projectile_setup(proj)
	comp._physics_process(0.1)
	assert_gt(proj.direction.y, 0.0, "方向应该朝目标偏转")
	target.queue_free()
	proj.queue_free()

func test_invalid_target_keeps_direction() -> void:
	var comp := TrackingMovementComponent.new()
	var proj := Node2D.new()
	proj.set_script(load("res://scripts/entities/projectiles/projectile.gd"))
	add_child(proj)
	proj.direction = Vector2.RIGHT
	var data := ProjectileData.new()
	data.speed = 100.0
	data.lifetime = 5.0
	proj.data = data
	proj.target = null
	proj.add_child(comp)
	comp.on_projectile_setup(proj)
	comp._physics_process(0.1)
	assert_almost_eq(proj.direction.x, 1.0, 0.01)
	proj.queue_free()

func test_reset_clears_state() -> void:
	var comp := TrackingMovementComponent.new()
	add_child(comp)
	comp._elapsed = 3.0
	var t := Node2D.new()
	comp._target = t
	comp.reset()
	assert_eq(comp._elapsed, 0.0)
	assert_null(comp._target)
	t.free()
	comp.queue_free()

func test_pooled_target_not_in_tree_ignored() -> void:
	var comp := TrackingMovementComponent.new()
	var proj := Node2D.new()
	proj.set_script(load("res://scripts/entities/projectiles/projectile.gd"))
	add_child(proj)
	proj.direction = Vector2.RIGHT
	proj.global_position = Vector2.ZERO
	var data := ProjectileData.new()
	data.speed = 100.0
	data.lifetime = 5.0
	proj.data = data
	var target := Node2D.new()
	proj.target = target
	proj.add_child(comp)
	comp.on_projectile_setup(proj)
	comp._physics_process(0.1)
	assert_almost_eq(proj.direction.x, 1.0, 0.01)
	target.free()
	proj.queue_free()
