extends GutTest

var comp: MeleeAttackComponent

func before_each() -> void:
	comp = MeleeAttackComponent.new()
	add_child(comp)

func after_each() -> void:
	comp.queue_free()

func test_get_final_damage_with_multiplier() -> void:
	comp._base_damage = 20.0
	comp.damage_multiplier = 1.1
	assert_almost_eq(comp.get_final_damage(), 22.0, 0.01)

func test_set_level_reads_attack_config() -> void:
	var config := AttackConfigData.new()
	config.damage_per_level = PackedFloat32Array([20, 38, 65])
	config.fire_rate_per_level = PackedFloat32Array([0.4, 0.32, 0.24])
	config.attack_range_per_level = PackedFloat32Array([50, 60, 70])
	comp.attack_config = config
	comp.set_level(3)
	assert_almost_eq(comp._base_damage, 65.0, 0.01)
	assert_almost_eq(comp._base_cooldown, 0.24, 0.01)

func test_tick_decrements_cooldown() -> void:
	comp._cooldown_remaining = 0.5
	comp.tick(0.3)
	assert_almost_eq(comp._cooldown_remaining, 0.2, 0.01)

func test_tick_blocked_during_attack() -> void:
	comp._is_attacking = true
	comp._cooldown_remaining = 0.0
	comp.tick(0.1)
	# cooldown should not change when attacking
	assert_almost_eq(comp._cooldown_remaining, 0.0, 0.01)

# ===== Perk bonus 应用 =====

func test_melee_damage_bonus_applied() -> void:
	PlayerState.reset()
	var comp := MeleeAttackComponent.new()
	comp._base_damage = 10.0
	comp.damage_multiplier = 1.0
	PlayerState.player_stats[Enums.Stat.DAMAGE_BONUS_PERCENT] = 0.5
	assert_almost_eq(comp.get_final_damage(), 15.0, 0.01)

func test_melee_attack_speed_bonus_reduces_cooldown() -> void:
	PlayerState.reset()
	var comp := MeleeAttackComponent.new()
	comp._base_cooldown = 1.0
	comp.speed_multiplier = 1.0
	PlayerState.player_stats[Enums.Stat.ATTACK_SPEED_BONUS_PERCENT] = 1.0
	assert_almost_eq(comp.get_final_cooldown(), 0.5, 0.01)
