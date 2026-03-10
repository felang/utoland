extends GutTest

## EnemyData 冲锋字段测试

func test_default_charge_fields_are_zero():
	var data := EnemyData.new()
	assert_eq(data.charge_cooldown, 0.0, "默认冲锋冷却应为 0")
	assert_eq(data.charge_speed_mult, 0.0, "默认冲锋速度倍率应为 0")
	assert_eq(data.charge_damage_mult, 0.0, "默认冲锋伤害倍率应为 0")
	assert_eq(data.charge_windup_time, 0.0, "默认冲锋预备时间应为 0")

func test_boss_brute_has_charge_data():
	var data: EnemyData = GameConfig.enemies["boss_brute"]
	assert_gt(data.charge_cooldown, 0.0, "蛮兽应有冲锋冷却")
	assert_gt(data.charge_speed_mult, 1.0, "蛮兽冲锋速度应大于正常")
	assert_gt(data.charge_damage_mult, 1.0, "蛮兽冲锋伤害应大于正常")
	assert_gt(data.charge_windup_time, 0.0, "蛮兽应有冲锋预备时间")

func test_normal_enemy_no_charge():
	var data: EnemyData = GameConfig.enemies["normal"]
	assert_eq(data.charge_cooldown, 0.0, "普通敌人不应有冲锋")
