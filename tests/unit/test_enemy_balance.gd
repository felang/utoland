extends GutTest

func test_boss_guardian_hp() -> void:
	var ed: EnemyData = GameConfig.enemies[Enums.Enemy.BOSS_GUARDIAN]
	assert_almost_eq(ed.hp, 1500.0, 0.01, "Guardian Boss HP 应为 1500")

func test_boss_guardian_is_boss() -> void:
	var ed: EnemyData = GameConfig.enemies[Enums.Enemy.BOSS_GUARDIAN]
	assert_true(ed.is_boss, "Guardian 应标记为 is_boss")

func test_boss_guardian_hp_greater_than_brute() -> void:
	var guardian: EnemyData = GameConfig.enemies[Enums.Enemy.BOSS_GUARDIAN]
	var brute: EnemyData = GameConfig.enemies[Enums.Enemy.BOSS_BRUTE]
	assert_gt(guardian.hp, brute.hp, "Guardian HP 应大于 Brute HP")
