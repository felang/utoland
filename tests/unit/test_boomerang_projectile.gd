# test_boomerang_projectile.gd — BoomerangProjectile 单元测试
extends GutTest

func _make_boomerang() -> BoomerangProjectile:
	var b = BoomerangProjectile.new()
	var hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	b.add_child(hitbox)
	add_child_autofree(b)
	return b

func test_boomerang_moves_outbound():
	var b = _make_boomerang()
	await get_tree().process_frame
	b.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
	b._physics_process(0.1)
	assert_true(b.global_position.x > 0.0, "should move right")

func test_boomerang_switches_to_returning_after_distance():
	var b = _make_boomerang()
	await get_tree().process_frame
	b.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
	b._traveled = b.outbound_distance + 1.0
	b._physics_process(0.016)
	assert_eq(b._state, Enums.BoomerangState.RETURNING)

func test_boomerang_returns_toward_player():
	var b = _make_boomerang()
	await get_tree().process_frame
	b.setup(10.0, 50.0, Vector2(100, 0), Vector2.RIGHT)
	b._state = Enums.BoomerangState.RETURNING
	var player_node = Node2D.new()
	player_node.global_position = Vector2(-100, 0)
	add_child_autofree(player_node)
	b.set_player(player_node)
	var start_x: float = b.global_position.x
	b._physics_process(0.1)
	assert_true(b.global_position.x < start_x, "should move toward player")
