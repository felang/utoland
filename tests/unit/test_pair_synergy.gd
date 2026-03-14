extends GutTest

var manager: PairSynergyManager

func before_each() -> void:
	GameData.reset()
	manager = PairSynergyManager.new()

func test_no_pair_synergy_by_default() -> void:
	manager.recalculate()
	assert_eq(GameData.active_pair_synergies.size(), 0)

func test_ice_gun_vine_pair() -> void:
	GameData.current_character = "nemo"
	GameData.deployed_weapons = [{id = "ice_gun", level = 1}]
	GameData.deployed_towers = [{id = "vine", level = 1, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("frozen_cage"))

func test_gorg_blade_pair() -> void:
	GameData.current_character = "gorg"
	GameData.deployed_weapons = [{id = "blade", level = 1}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("bloodthirst"))

func test_pair_deactivates_on_undeploy() -> void:
	GameData.current_character = "gorg"
	GameData.deployed_weapons = [{id = "blade", level = 1}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("bloodthirst"))
	GameData.deployed_weapons = []
	manager.recalculate()
	assert_false(GameData.active_pair_synergies.has("bloodthirst"))

func test_merlin_mint_pair() -> void:
	GameData.current_character = "merlin"
	GameData.deployed_towers = [{id = "mint", level = 1, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("magic_resonance"))

func test_lightning_ice_flower_pair() -> void:
	GameData.deployed_weapons = [{id = "lightning", level = 1}]
	GameData.deployed_towers = [{id = "ice_flower", level = 1, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("superconductor"))

func test_kaze_minigun_pair() -> void:
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [{id = "minigun", level = 1}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("bullet_time"))

func test_rocket_bamboo_pair() -> void:
	GameData.deployed_weapons = [{id = "rocket", level = 1}]
	GameData.deployed_towers = [{id = "bamboo", level = 2, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("chain_detonation"))

func test_multiple_pairs_active() -> void:
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [{id = "minigun", level = 1}, {id = "lightning", level = 1}]
	GameData.deployed_towers = [{id = "ice_flower", level = 1, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("bullet_time"))
	assert_true(GameData.active_pair_synergies.has("superconductor"))

func test_signal_emitted_on_activate() -> void:
	var activated_ids: Array[String] = []
	EventBus.pair_synergy_activated.connect(func(sid: String) -> void: activated_ids.append(sid))
	GameData.current_character = "gorg"
	GameData.deployed_weapons = [{id = "blade", level = 1}]
	manager.recalculate()
	assert_true(activated_ids.has("bloodthirst"))

func test_signal_emitted_on_deactivate() -> void:
	var deactivated_ids: Array[String] = []
	EventBus.pair_synergy_deactivated.connect(func(sid: String) -> void: deactivated_ids.append(sid))
	GameData.current_character = "gorg"
	GameData.deployed_weapons = [{id = "blade", level = 1}]
	manager.recalculate()
	GameData.deployed_weapons = []
	manager.recalculate()
	assert_true(deactivated_ids.has("bloodthirst"))

func test_no_false_positive_single_unit() -> void:
	GameData.deployed_weapons = [{id = "ice_gun", level = 1}]
	manager.recalculate()
	assert_false(GameData.active_pair_synergies.has("frozen_cage"))
