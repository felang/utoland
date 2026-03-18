extends GutTest

# --- Dora ---
func test_dora_max_hp() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_eq(cd.max_hp, 100.0, "Dora max_hp 应为 100")

func test_dora_speed() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_eq(cd.speed, 200.0, "Dora speed 应为 200")

func test_dora_starting_gold() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_eq(cd.starting_gold, 30, "Dora starting_gold 应为 30")

func test_dora_recommended_weapon() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_eq(cd.recommended_weapon, "bow", "Dora recommended_weapon 应为 bow")

func test_dora_passive_type() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_eq(cd.passive_type, "coin_bonus", "Dora passive_type 应为 coin_bonus")

func test_dora_passive_value() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_almost_eq(cd.passive_value, 0.2, 0.001, "Dora passive_value 应为 0.2")

# --- Gorg ---
func test_gorg_max_hp() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.GORG]
	assert_eq(cd.max_hp, 140.0, "Gorg max_hp 应为 140")

func test_gorg_speed() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.GORG]
	assert_eq(cd.speed, 160.0, "Gorg speed 应为 160")

func test_gorg_damage_mult() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.GORG]
	assert_almost_eq(cd.damage_mult, 1.1, 0.001, "Gorg damage_mult 应为 1.1")

func test_gorg_attack_speed_mult() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.GORG]
	assert_almost_eq(cd.attack_speed_mult, 0.9, 0.001, "Gorg attack_speed_mult 应为 0.9")

func test_gorg_starting_gold() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.GORG]
	assert_eq(cd.starting_gold, 20, "Gorg starting_gold 应为 20")

func test_gorg_recommended_weapon() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.GORG]
	assert_eq(cd.recommended_weapon, "sword", "Gorg recommended_weapon 应为 sword")

func test_gorg_passive_type() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.GORG]
	assert_eq(cd.passive_type, "kill_heal", "Gorg passive_type 应为 kill_heal")

func test_gorg_passive_value() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.GORG]
	assert_almost_eq(cd.passive_value, 3.0, 0.001, "Gorg passive_value 应为 3.0")

# --- Kaze ---
func test_kaze_max_hp() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.KAZE]
	assert_eq(cd.max_hp, 75.0, "Kaze max_hp 应为 75")

func test_kaze_speed() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.KAZE]
	assert_eq(cd.speed, 260.0, "Kaze speed 应为 260")

func test_kaze_attack_speed_mult() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.KAZE]
	assert_almost_eq(cd.attack_speed_mult, 1.15, 0.001, "Kaze attack_speed_mult 应为 1.15")

func test_kaze_starting_gold() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.KAZE]
	assert_eq(cd.starting_gold, 25, "Kaze starting_gold 应为 25")

func test_kaze_recommended_weapon() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.KAZE]
	assert_eq(cd.recommended_weapon, "bow", "Kaze recommended_weapon 应为 bow")

func test_kaze_passive_type() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.KAZE]
	assert_eq(cd.passive_type, "damage_on_low_hp", "Kaze passive_type 应为 damage_on_low_hp")

func test_kaze_passive_value() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.KAZE]
	assert_almost_eq(cd.passive_value, 0.4, 0.001, "Kaze passive_value 应为 0.4")

# --- Merlin ---
func test_merlin_max_hp() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.MERLIN]
	assert_eq(cd.max_hp, 85.0, "Merlin max_hp 应为 85")

func test_merlin_speed() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.MERLIN]
	assert_eq(cd.speed, 190.0, "Merlin speed 应为 190")

func test_merlin_damage_mult() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.MERLIN]
	assert_almost_eq(cd.damage_mult, 0.9, 0.001, "Merlin damage_mult 应为 0.9")

func test_merlin_starting_gold() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.MERLIN]
	assert_eq(cd.starting_gold, 40, "Merlin starting_gold 应为 40")

func test_merlin_recommended_weapon() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.MERLIN]
	assert_eq(cd.recommended_weapon, "shuriken", "Merlin recommended_weapon 应为 shuriken")

func test_merlin_recommended_tower() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.MERLIN]
	assert_eq(cd.recommended_tower, "sunflower", "Merlin recommended_tower 应为 sunflower")

func test_merlin_passive_type() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.MERLIN]
	assert_eq(cd.passive_type, "tower_attack_speed_bonus", "Merlin passive_type 应为 tower_attack_speed_bonus")

func test_merlin_passive_value() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.MERLIN]
	assert_almost_eq(cd.passive_value, 0.15, 0.001, "Merlin passive_value 应为 0.15")

# --- Nemo ---
func test_nemo_max_hp() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.NEMO]
	assert_eq(cd.max_hp, 90.0, "Nemo max_hp 应为 90")

func test_nemo_speed() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.NEMO]
	assert_eq(cd.speed, 210.0, "Nemo speed 应为 210")

func test_nemo_damage_mult() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.NEMO]
	assert_almost_eq(cd.damage_mult, 0.95, 0.001, "Nemo damage_mult 应为 0.95")

func test_nemo_starting_gold() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.NEMO]
	assert_eq(cd.starting_gold, 35, "Nemo starting_gold 应为 35")

func test_nemo_recommended_weapon() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.NEMO]
	assert_eq(cd.recommended_weapon, "shuriken", "Nemo recommended_weapon 应为 shuriken")

func test_nemo_recommended_tower() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.NEMO]
	assert_eq(cd.recommended_tower, "sunflower", "Nemo recommended_tower 应为 sunflower")

func test_nemo_passive_type() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.NEMO]
	assert_eq(cd.passive_type, "tower_hp_bonus", "Nemo passive_type 应为 tower_hp_bonus")

func test_nemo_passive_value() -> void:
	var cd: CharacterData = GameConfig.characters[Enums.Character.NEMO]
	assert_almost_eq(cd.passive_value, 0.25, 0.001, "Nemo passive_value 应为 0.25")

# --- 唯一性验证 ---
func test_all_characters_have_unique_passives() -> void:
	var passives: Array = []
	for char_id in GameConfig.characters:
		var cd: CharacterData = GameConfig.characters[char_id]
		if cd.passive_type != "":
			assert_false(passives.has(cd.passive_type), "%s passive_type '%s' 与其他角色重复" % [char_id, cd.passive_type])
			passives.append(cd.passive_type)
