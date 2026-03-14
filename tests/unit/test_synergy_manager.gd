extends GutTest
## SynergyManager 单元测试
## 覆盖：标签统计、档位计算、recalculate 更新 GameData

var manager: SynergyManager


func before_each() -> void:
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	manager = SynergyManager.new()


func after_each() -> void:
	# 清理羁绊状态避免污染其他测试文件
	GameData.synergy_active_tiers = {}
	GameData.synergy_tag_counts = {}
	GameData.deployed_weapons = []
	GameData.deployed_towers = []


# ===== count_tags =====

func test_count_tags_empty() -> void:
	# 清空角色和部署，验证零标签计数
	GameData.current_character = ""
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	var counts: Dictionary = manager.count_tags()
	assert_eq(counts.size(), 0)


func test_count_tags_with_character() -> void:
	GameData.current_character = "kaze"
	var counts: Dictionary = manager.count_tags()
	assert_eq(counts.get("assault", 0), 1)


func test_count_tags_with_deployed_weapons() -> void:
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [{id = "rifle", level = 1}, {id = "minigun", level = 2}]
	var counts: Dictionary = manager.count_tags()
	assert_eq(counts.get("assault", 0), 3)


func test_count_tags_with_deployed_towers() -> void:
	GameData.current_character = "merlin"
	GameData.deployed_towers = [{id = "sunflower", level = 1, grid_pos = Vector2i(0, 0)}, {id = "mint", level = 1, grid_pos = Vector2i(1, 0)}]
	var counts: Dictionary = manager.count_tags()
	assert_eq(counts.get("boost", 0), 3)


func test_count_tags_mixed() -> void:
	GameData.current_character = "nemo"
	GameData.deployed_weapons = [{id = "ice_gun", level = 1}]
	GameData.deployed_towers = [{id = "ice_flower", level = 1, grid_pos = Vector2i(0, 0)}, {id = "stump", level = 1, grid_pos = Vector2i(1, 0)}]
	var counts: Dictionary = manager.count_tags()
	assert_eq(counts.get("control", 0), 3)
	assert_eq(counts.get("fortify", 0), 1)


# ===== _calculate_tier =====

func test_calculate_tier_none() -> void:
	assert_eq(manager._calculate_tier(0), 0)
	assert_eq(manager._calculate_tier(1), 0)


func test_calculate_tier_2() -> void:
	assert_eq(manager._calculate_tier(2), 2)


func test_calculate_tier_3() -> void:
	assert_eq(manager._calculate_tier(3), 3)
	assert_eq(manager._calculate_tier(4), 3)


func test_calculate_tier_5() -> void:
	assert_eq(manager._calculate_tier(5), 5)
	assert_eq(manager._calculate_tier(6), 5)


# ===== recalculate =====

func test_recalculate_updates_game_data() -> void:
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [{id = "rifle", level = 1}, {id = "minigun", level = 1}]
	manager.recalculate()
	assert_eq(GameData.synergy_tag_counts.get("assault", 0), 3)
	assert_eq(GameData.synergy_active_tiers.get("assault", 0), 3)


# ===== 升级不重复计数 =====

func test_upgrade_does_not_double_count() -> void:
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [{id = "rifle", level = 3}]
	var counts: Dictionary = manager.count_tags()
	# rifle level 3 仍然只贡献 1 个 assault 标签，加上角色 kaze 的 1 个 = 2
	assert_eq(counts.get("assault", 0), 2)


# ===== get_tag =====

func test_get_tag_weapon() -> void:
	assert_eq(manager.get_tag("rifle"), "assault")


func test_get_tag_tower() -> void:
	assert_eq(manager.get_tag("ice_flower"), "control")


func test_get_tag_character() -> void:
	assert_eq(manager.get_tag("kaze"), "assault")


func test_get_tag_unknown() -> void:
	assert_eq(manager.get_tag("nonexistent"), "")


# ===== is_tier3_active =====

func test_is_tier3_active_true() -> void:
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [{id = "rifle", level = 1}, {id = "minigun", level = 1}]
	manager.recalculate()
	assert_true(manager.is_tier3_active("assault"))


func test_is_tier3_active_false() -> void:
	GameData.current_character = "kaze"
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	manager.recalculate()
	assert_false(manager.is_tier3_active("assault"))


# ===== 2 档效果查询 =====

func test_tier2_damage_mult_bonus() -> void:
	# kaze(assault) + rifle(assault) = 2 个 assault → 2 档激活
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [{id = "rifle", level = 1}]
	manager.recalculate()
	var bonus: float = manager.get_damage_mult_bonus("rifle")
	assert_almost_eq(bonus, 0.15, 0.001)


func test_tier2_no_bonus_below_threshold() -> void:
	# kaze(assault) 仅 1 个 assault → 不足 2 档
	GameData.current_character = "kaze"
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	manager.recalculate()
	var bonus: float = manager.get_damage_mult_bonus("rifle")
	assert_almost_eq(bonus, 0.0, 0.001)


func test_tier2_damage_mult_non_assault_unit() -> void:
	# 非 assault 标签单位不享受 assault 伤害加成
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [{id = "rifle", level = 1}]
	manager.recalculate()
	var bonus: float = manager.get_damage_mult_bonus("ice_gun")
	assert_almost_eq(bonus, 0.0, 0.001)


func test_tier2_control_duration_bonus() -> void:
	# nemo(control) + ice_gun(control) = 2 个 control → 2 档激活
	GameData.current_character = "nemo"
	GameData.deployed_weapons = [{id = "ice_gun", level = 1}]
	manager.recalculate()
	assert_almost_eq(manager.get_control_duration_bonus(), 0.25, 0.001)


func test_tier2_control_duration_no_bonus() -> void:
	# 仅 1 个 control → 不足 2 档
	GameData.current_character = "nemo"
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	manager.recalculate()
	assert_almost_eq(manager.get_control_duration_bonus(), 0.0, 0.001)


func test_tier2_aoe_range_bonus() -> void:
	# gorg(blast) + rocket(blast) = 2 个 blast → 2 档激活
	GameData.current_character = "gorg"
	GameData.deployed_weapons = [{id = "rocket", level = 1}]
	manager.recalculate()
	assert_almost_eq(manager.get_aoe_range_bonus(), 0.2, 0.001)


func test_tier2_boost_strength_bonus() -> void:
	# merlin(boost) + sunflower(boost) = 2 个 boost → 2 档激活
	GameData.current_character = "merlin"
	GameData.deployed_towers = [{id = "sunflower", level = 1, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	assert_almost_eq(manager.get_boost_strength_bonus(), 0.25, 0.001)


func test_tier2_boost_fallback_damage() -> void:
	# boost 2 档激活，pea_shooter 无内在 boost 机制 → 回退为伤害加成
	GameData.current_character = "merlin"
	GameData.deployed_towers = [{id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	var bonus: float = manager.get_damage_mult_bonus("pea_shooter")
	assert_almost_eq(bonus, 0.25, 0.001)


func test_tier2_boost_no_fallback_for_buff_tower() -> void:
	# boost 2 档激活，mint 有内在 boost 机制 → 不回退为伤害加成
	GameData.current_character = "merlin"
	GameData.deployed_towers = [{id = "mint", level = 1, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	var bonus: float = manager.get_damage_mult_bonus("mint")
	assert_almost_eq(bonus, 0.0, 0.001)
