extends GutTest

func test_all_towers_have_description() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_ne(td.description, "", "%s 缺少 description" % tower_id)

func test_tower_count() -> void:
	assert_eq(GameConfig.towers.size(), 3, "应有 3 种塔")

func test_all_towers_have_icon_path() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_ne(td.icon_path, "", "%s 缺少 icon_path" % tower_id)
