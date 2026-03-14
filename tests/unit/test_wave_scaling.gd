extends GutTest

func test_no_scaling_wave_1():
    var result = EnemySpawner.get_wave_scaling(1)
    assert_almost_eq(result.hp_mult, 1.0, 0.001)
    assert_almost_eq(result.damage_mult, 1.0, 0.001)

func test_no_scaling_wave_10():
    var result = EnemySpawner.get_wave_scaling(10)
    assert_almost_eq(result.hp_mult, 1.0, 0.001)
    assert_almost_eq(result.damage_mult, 1.0, 0.001)

func test_scaling_wave_11():
    var result = EnemySpawner.get_wave_scaling(11)
    assert_almost_eq(result.hp_mult, 1.06, 0.01)
    assert_almost_eq(result.damage_mult, 1.04, 0.01)

func test_scaling_wave_15():
    var result = EnemySpawner.get_wave_scaling(15)
    assert_almost_eq(result.hp_mult, 1.338, 0.01)
    assert_almost_eq(result.damage_mult, 1.217, 0.01)

func test_scaling_wave_20():
    var result = EnemySpawner.get_wave_scaling(20)
    assert_almost_eq(result.hp_mult, 1.791, 0.01)
    assert_almost_eq(result.damage_mult, 1.480, 0.01)
