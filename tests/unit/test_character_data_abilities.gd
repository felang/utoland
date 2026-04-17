extends GutTest

func test_character_data_has_new_fields():
	var cd: CharacterData = CharacterData.new()
	assert_eq(cd.ability_scenes.size(), 0, "ability_scenes 默认为空数组")
	assert_eq(cd.perk_pool.size(), 0, "perk_pool 默认为空数组")
	assert_null(cd.exp_config, "exp_config 默认为 null")

func test_character_data_no_old_passive_fields():
	var cd: CharacterData = CharacterData.new()
	var prop_names: Array = []
	for prop in cd.get_property_list():
		prop_names.append(prop.name)
	assert_false("passive_type" in prop_names, "passive_type 应已删除")
	assert_false("new_passive_id" in prop_names, "new_passive_id 应已删除")
	assert_false("passive_evolution" in prop_names, "passive_evolution 应已删除")
	assert_false("starting_weapon" in prop_names, "starting_weapon 应已删除")
	assert_false("recommended_weapon" in prop_names, "recommended_weapon 应已删除")
	assert_false("recommended_tower" in prop_names, "recommended_tower 应已删除")
