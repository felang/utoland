class_name ShopEffectApplier
extends RefCounted

func apply_effect(item: ShopItemData) -> void:
	var p := item.effect_params
	match item.effect_type:
		Enums.ItemEffect.STAT_BOOST:
			_apply_stat_boost(p)
		Enums.ItemEffect.TOWER_STAT:
			_apply_tower_stat(p)
		Enums.ItemEffect.CONSUMABLE:
			if p.get("effect") == "heal":
				GameData.pending_heal += p["value"]
		Enums.ItemEffect.PIERCE:
			GameData.pierce_count += p.get("pierce_count", 1)
		Enums.ItemEffect.MULTISHOT:
			GameData.multishot_active = true
			GameData.multishot_damage_mult = p.get("damage_mult", 1.0)
		Enums.ItemEffect.LIFESTEAL:
			GameData.lifesteal_ratio += p.get("ratio", 0.05)
		Enums.ItemEffect.KILL_STACK:
			GameData.kill_stack_max = max(GameData.kill_stack_max, p.get("max_stacks", 3))
			GameData.kill_stack_damage_per_stack += p.get("damage_per_stack", 0.2)
		Enums.ItemEffect.TOWER_LINK:
			GameData.tower_link_damage_per_tower += p.get("damage_per_tower", 0.04)
		Enums.ItemEffect.WAVE_GOLD:
			GameData.wave_gold_bonus += p.get("gold", 15)
		Enums.ItemEffect.WAVE_HEAL_TOWERS:
			GameData.wave_tower_heal_ratio += p.get("ratio", 0.20)
		Enums.ItemEffect.TOWER_REGEN:
			GameData.tower_regen_active = true
			GameData.tower_regen_hp += p.get("hp_per_interval", 5)
			GameData.tower_regen_interval = p.get("interval", 5.0)
		Enums.ItemEffect.SYMBIOSIS:
			GameData.symbiosis_hp_threshold = max(GameData.symbiosis_hp_threshold, p.get("hp_threshold", 0.30))
			GameData.symbiosis_tower_bonus += p.get("tower_damage_bonus", 0.60)
		Enums.ItemEffect.WAR_MACHINE:
			GameData.player_stats[Enums.Stat.DAMAGE_MULT] += p.get("damage_mult", 0.20)
			GameData.player_stats[Enums.Stat.TOWER_MULT] += p.get("tower_mult", 0.20)
			GameData.war_machine_active = true
			GameData.war_machine_wave_hp_cost += p.get("wave_hp_cost", 8)
		Enums.ItemEffect.BULLET_SPEED:
			GameData.bullet_speed_mult += p.get("mult", 0.2)
		Enums.ItemEffect.WEAPON_RANGE:
			GameData.weapon_range_mult += p.get("mult", 0.15)
		Enums.ItemEffect.CRIT:
			GameData.crit_chance += p.get("chance", 0.10)
		Enums.ItemEffect.SPLIT:
			GameData.split_count += p.get("count", 2)
			GameData.split_damage_mult = p.get("damage_mult", 0.5)
		Enums.ItemEffect.WAVE_SHIELD:
			GameData.wave_shield_count += p.get("count", 1)
		Enums.ItemEffect.WAVE_HEAL_PLAYER:
			GameData.wave_heal_ratio += p.get("ratio", 0.10)
		Enums.ItemEffect.DAMAGE_REDUCTION:
			GameData.damage_reduction += p.get("ratio", 0.10)
		Enums.ItemEffect.DODGE:
			GameData.dodge_chance += p.get("chance", 0.15)
		Enums.ItemEffect.MAGNET:
			GameData.coin_magnet_mult += p.get("mult", 0.50)
		Enums.ItemEffect.SLOW_AURA:
			GameData.slow_aura_active = true
			GameData.slow_aura_ratio += p.get("ratio", 0.15)
			GameData.slow_aura_range = max(GameData.slow_aura_range, p.get("range", 100.0))
		Enums.ItemEffect.AUTO_DASH:
			GameData.auto_dash_active = true
			GameData.auto_dash_interval = min(GameData.auto_dash_interval, p.get("interval", 10.0))
			GameData.auto_dash_distance = max(GameData.auto_dash_distance, p.get("distance", 80.0))
		Enums.ItemEffect.DESTINY:
			pass  # 天命效果在 _generate_shop 时处理（购买后重新刷新出额外稀有物品）
		_:
			push_warning("未知效果类型: %s" % item.effect_type)

func _apply_stat_boost(p: Dictionary) -> void:
	if p.has("stat"):
		GameData.player_stats[p["stat"]] += p["value"]
	elif p.has("stats"):
		for entry in p["stats"]:
			GameData.player_stats[entry["stat"]] += entry["value"]

func _apply_tower_stat(p: Dictionary) -> void:
	if p.has("stat"):
		_set_tower_stat(p["stat"], p["value"])
	elif p.has("stats"):
		for entry in p["stats"]:
			_set_tower_stat(entry["stat"], entry["value"])

func _set_tower_stat(stat: String, value: float) -> void:
	match stat:
		"tower_hp_mult":
			GameData.tower_hp_mult += value
		"tower_range_mult":
			GameData.tower_range_mult += value
		"tower_attack_speed_mult":
			GameData.tower_attack_speed_mult += value
		"tower_cost_mult":
			GameData.tower_cost_mult += value
		"tower_mult":
			GameData.player_stats[Enums.Stat.TOWER_MULT] += value
		"hp_mult":
			GameData.player_stats[Enums.Stat.HP_MULT] += value
		_:
			push_warning("未知塔属性: %s" % stat)
