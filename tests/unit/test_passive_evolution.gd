extends GutTest

func test_passive_evolution_data_tier_selection() -> void:
	var evo := PassiveEvolutionData.new()
	evo.tier_1 = { "melee_damage_mult": 1.1 }
	evo.tier_2 = { "melee_damage_mult": 1.2, "melee_attack_speed_mult": 1.1 }
	evo.tier_3 = { "melee_damage_mult": 1.3, "melee_attack_speed_mult": 1.2, "kill_heal": 1.0 }
	evo.tier_2_level = 4
	evo.tier_3_level = 7

	var t1: Dictionary = evo.get_tier_for_level(1)
	assert_eq(t1.get("melee_damage_mult"), 1.1, "Lv1 应返回 tier_1")
	assert_false(t1.has("melee_attack_speed_mult"), "tier_1 不应有攻速")

	var t1_3: Dictionary = evo.get_tier_for_level(3)
	assert_eq(t1_3.get("melee_damage_mult"), 1.1, "Lv3 仍为 tier_1")

	var t2: Dictionary = evo.get_tier_for_level(4)
	assert_eq(t2.get("melee_damage_mult"), 1.2, "Lv4 应返回 tier_2")
	assert_eq(t2.get("melee_attack_speed_mult"), 1.1, "tier_2 应有攻速")

	var t3: Dictionary = evo.get_tier_for_level(7)
	assert_eq(t3.get("melee_damage_mult"), 1.3, "Lv7 应返回 tier_3")
	assert_eq(t3.get("kill_heal"), 1.0, "tier_3 应有击杀回血")

	var t3_9: Dictionary = evo.get_tier_for_level(9)
	assert_eq(t3_9.get("kill_heal"), 1.0, "Lv9 仍为 tier_3")

func test_dora_passive_evolution_loaded() -> void:
	var dora: CharacterData = GameConfig.characters["dora"]
	assert_not_null(dora.passive_evolution, "Dora 应有 passive_evolution")
	var evo: PassiveEvolutionData = dora.passive_evolution
	assert_eq(evo.passive_id, "sword_saint")
	assert_eq(evo.tier_2_level, 4)
	assert_eq(evo.tier_3_level, 7)
	assert_almost_eq(evo.tier_1.get("melee_damage_mult", 0.0), 1.1, 0.01)
	assert_almost_eq(evo.tier_3.get("kill_heal", 0.0), 1.0, 0.01)
