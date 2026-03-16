# test_projectile.gd — ProjectileBase 基类单元测试
extends GutTest

var _projectile: ProjectileBase

func before_each():
	var scene = preload("res://scenes/entities/projectiles/bullet_projectile.tscn")
	_projectile = scene.instantiate()
	add_child(_projectile)

func after_each():
	if is_instance_valid(_projectile):
		_projectile.queue_free()

func test_setup_sets_position_and_damage():
	await get_tree().process_frame
	var data := ProjectileData.new()
	data.speed = 300.0
	data.lifetime = 5.0
	data.knockback_force = 40.0
	_projectile.setup(data, 25.0, Vector2(100, 200), Vector2.RIGHT)
	assert_eq(_projectile.global_position, Vector2(100, 200))
	assert_eq(_projectile.hitbox.damage, 25.0)
	assert_eq(_projectile.hitbox.knockback_force, 40.0)

func test_setup_with_pierce():
	await get_tree().process_frame
	var data := ProjectileData.new()
	data.base_pierce_count = 1
	data.speed = 100.0
	data.lifetime = 5.0
	_projectile.setup(data, 10.0, Vector2.ZERO, Vector2.RIGHT, 2)
	assert_eq(_projectile._pierce_count, 3)

func test_default_projectile_data():
	await get_tree().process_frame
	var data := ProjectileData.new()
	data.speed = 100.0
	data.lifetime = 5.0
	_projectile.setup(data, 10.0, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(_projectile._speed, 100.0)
	assert_eq(_projectile._lifetime, 5.0)

func test_moves_in_direction():
	await get_tree().process_frame
	var data := ProjectileData.new()
	data.speed = 800.0
	data.lifetime = 5.0
	_projectile.setup(data, 10.0, Vector2.ZERO, Vector2.RIGHT)
	var start_x: float = _projectile.global_position.x
	_projectile._physics_process(0.1)
	assert_true(_projectile.global_position.x > start_x, "应向右飞行")

func test_queue_frees_after_lifetime():
	await get_tree().process_frame
	var data := ProjectileData.new()
	data.speed = 100.0
	data.lifetime = 2.0
	_projectile.setup(data, 10.0, Vector2.ZERO, Vector2.RIGHT)
	_projectile._physics_process(2.1)
	assert_true(_projectile.is_queued_for_deletion())
