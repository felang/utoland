extends GutTest

func test_hurtbox_emits_hit_taken_when_hitbox_enters():
	var hurtbox = Hurtbox.new()
	add_child_autofree(hurtbox)

	var hitbox = Hitbox.new()
	add_child_autofree(hitbox)
	hitbox.damage = 25.0
	hitbox.knockback_force = 100.0
	hitbox.global_position = Vector2(10, 0)

	var results: Array = [-1.0, Vector2.ZERO]
	hurtbox.hit_taken.connect(func(dmg, kb): results[0] = dmg; results[1] = kb)

	# 直接调用，绕过物理引擎
	hurtbox._on_area_entered(hitbox)

	assert_eq(results[0], 25.0)
	assert_true((results[1] as Vector2).length() > 0.0, "knockback should have direction")

func test_hurtbox_ignores_non_hitbox_areas():
	var hurtbox = Hurtbox.new()
	add_child_autofree(hurtbox)

	var results: Array = [false]
	hurtbox.hit_taken.connect(func(_d, _k): results[0] = true)

	var other_area = Area2D.new()
	add_child_autofree(other_area)
	hurtbox._on_area_entered(other_area)

	assert_false(results[0])
