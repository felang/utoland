extends GutTest
## SynergyManager 单元测试
## 覆盖：标签统计、档位计算、recalculate 更新 GameData

var manager: SynergyManager


func before_each() -> void:
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	manager = SynergyManager.new()


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
