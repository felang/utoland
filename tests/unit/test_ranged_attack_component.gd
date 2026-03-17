extends GutTest

var comp: RangedAttackComponent

func before_each() -> void:
	comp = RangedAttackComponent.new()
	add_child(comp)

func after_each() -> void:
	comp.queue_free()

func test_initial_cooldown_zero() -> void:
	assert_eq(comp._cooldown_remaining, 0.0)

func test_get_final_damage_with_multiplier() -> void:
	comp._base_damage = 10.0
	comp.damage_multiplier = 1.5
	assert_almost_eq(comp.get_final_damage(), 15.0, 0.01)

func test_get_final_cooldown_with_multiplier() -> void:
	comp._base_cooldown = 1.0
	comp.speed_multiplier = 2.0
	assert_almost_eq(comp.get_final_cooldown(), 0.5, 0.01)

func test_set_level_reads_attack_config() -> void:
	var config := AttackConfigData.new()
	config.damage_per_level = PackedFloat32Array([10, 20, 30])
	config.fire_rate_per_level = PackedFloat32Array([1.0, 0.8, 0.6])
	config.attack_range_per_level = PackedFloat32Array([100, 150, 200])
	comp.attack_config = config
	comp.set_level(2)
	assert_almost_eq(comp._base_damage, 20.0, 0.01)
	assert_almost_eq(comp._base_cooldown, 0.8, 0.01)

func test_tick_decrements_cooldown() -> void:
	comp._cooldown_remaining = 1.0
	comp.tick(0.5)
	assert_almost_eq(comp._cooldown_remaining, 0.5, 0.01)
