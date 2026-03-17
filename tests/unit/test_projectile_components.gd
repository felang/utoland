extends GutTest

func test_pierce_component_tracks_hits() -> void:
	var pierce := PierceComponent.new()
	add_child(pierce)
	pierce.max_pierce_count = 2
	var dummy := Node2D.new()
	add_child(dummy)
	pierce.on_hit(dummy, null)
	assert_eq(pierce._hit_count, 1)
	pierce.on_hit(dummy, null)
	assert_eq(pierce._hit_count, 2)
	pierce.on_hit(dummy, null)
	assert_eq(pierce._hit_count, 3)
	dummy.queue_free()
	pierce.queue_free()

func test_pierce_component_reset() -> void:
	var pierce := PierceComponent.new()
	add_child(pierce)
	pierce._hit_count = 5
	pierce.reset()
	assert_eq(pierce._hit_count, 0)
	pierce.queue_free()

func test_pierce_manages_lifecycle() -> void:
	var pierce := PierceComponent.new()
	assert_true(pierce.manages_lifecycle)
	pierce.free()

func test_bounce_manages_lifecycle() -> void:
	var bounce := BounceOnHitComponent.new()
	assert_true(bounce.manages_lifecycle)
	bounce.free()

func test_bounce_reset_clears_state() -> void:
	var bounce := BounceOnHitComponent.new()
	add_child(bounce)
	bounce._bounce_count = 3
	bounce._hit_enemies.append(Node2D.new())
	bounce.reset()
	assert_eq(bounce._bounce_count, 0)
	assert_eq(bounce._hit_enemies.size(), 0)
	bounce.queue_free()

func test_slow_on_hit_graceful_without_handler() -> void:
	var slow := SlowOnHitComponent.new()
	add_child(slow)
	var target := Node2D.new()
	add_child(target)
	slow.on_hit(target, null)
	target.queue_free()
	slow.queue_free()

func test_knockback_on_hit_graceful_without_handler() -> void:
	var kb := KnockbackOnHitComponent.new()
	add_child(kb)
	var target := Node2D.new()
	add_child(target)
	var fake_proj := Node2D.new()
	kb.on_hit(target, fake_proj)
	target.queue_free()
	kb.queue_free()
	fake_proj.free()
