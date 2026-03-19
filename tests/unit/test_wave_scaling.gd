extends GutTest

func test_hp_scaling_wave_1():
	# Wave 1: hp_mult = 1.0 + 0 * 0.055 = 1.0
	var result = EnemySpawner.get_wave_scaling(1)
	assert_almost_eq(result.hp_mult, 1.0, 0.001)
	assert_almost_eq(result.damage_mult, 1.0, 0.001)

func test_hp_scaling_wave_6():
	# Wave 6: hp_mult = 1.0 + 5 * 0.055 = 1.275，damage_mult = 1.0（未到第 9 波）
	var result = EnemySpawner.get_wave_scaling(6)
	assert_almost_eq(result.hp_mult, 1.275, 0.001)
	assert_almost_eq(result.damage_mult, 1.0, 0.001)

func test_damage_scaling_starts_at_wave_9():
	# Wave 8: damage_mult 仍为 1.0
	var result_8 = EnemySpawner.get_wave_scaling(8)
	assert_almost_eq(result_8.damage_mult, 1.0, 0.001)
	# Wave 9: damage_mult = 1.0 + 0 * 0.0375 = 1.0（起始波，尚无增量）
	var result_9 = EnemySpawner.get_wave_scaling(9)
	assert_almost_eq(result_9.damage_mult, 1.0, 0.001)

func test_scaling_wave_12():
	# Wave 12: hp_mult = 1.0 + 11 * 0.055 = 1.605，damage_mult = 1.0 + 3 * 0.0375 = 1.1125
	var result = EnemySpawner.get_wave_scaling(12)
	assert_almost_eq(result.hp_mult, 1.605, 0.001)
	assert_almost_eq(result.damage_mult, 1.1125, 0.001)
