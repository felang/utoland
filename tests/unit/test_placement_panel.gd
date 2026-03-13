extends GutTest

var placement: Node2D
var _original_coins: int
var _original_map: String
var _original_owned_towers: Dictionary

func before_each():
	_original_coins = GameData.coins
	_original_map = GameData.selected_map
	_original_owned_towers = GameData.owned_towers.duplicate()
	GameData.tower_inventory.clear()
	GameData.owned_towers = {"shooter": 1, "wall": 1, "slow": 1}
	GameData.coins = 200
	# 清理残留在 TOWERS 组中的节点（可能来自其他测试的 queue_free 延迟）
	for node in get_tree().get_nodes_in_group(Enums.Group.TOWERS):
		node.remove_from_group(Enums.Group.TOWERS)
	var placement_scene = load("res://scenes/levels/placement.tscn")
	placement = placement_scene.instantiate()
	add_child_autofree(placement)

func after_each():
	GameData.coins = _original_coins
	GameData.selected_map = _original_map
	GameData.owned_towers = _original_owned_towers

func test_place_tower_deducts_coins():
	var cost: int = SceneFactory.get_tower_cost(Enums.TowerId.SHOOTER)
	var initial_coins: int = GameData.coins
	placement._placement_panel._select_tower(Enums.TowerId.SHOOTER)
	assert_not_null(placement._placement_panel._preview_tower, "应有预览塔")
	# 使用远离玩家出生点 (0,0) 的位置，确保 can_place_at 通过
	var place_pos := Vector2(200, 200)
	placement._placement_panel._preview_tower.global_position = place_pos
	# 验证 can_place_at 确实返回 true，否则测试前提不成立
	assert_true(placement.can_place_at(place_pos), "测试位置应允许放置")
	placement._placement_panel._place_tower()
	assert_eq(GameData.coins, initial_coins - cost, "放置应扣除金币")

func test_remove_tower_refunds_coins():
	GameData.coins = 60
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)
	var cost: int = SceneFactory.get_tower_cost(Enums.TowerId.SHOOTER)
	placement._placement_panel._remove_tower_at(Vector2(110, 110))
	assert_eq(GameData.coins, 60 + cost, "移除应退还金币")

func test_cannot_select_tower_when_coins_insufficient():
	GameData.coins = 0
	placement._placement_panel._select_tower(Enums.TowerId.SHOOTER)
	assert_null(placement._placement_panel._preview_tower, "金币不足不应创建预览")

func test_cancel_placement_clears_preview():
	placement._placement_panel._select_tower(Enums.TowerId.SHOOTER)
	assert_true(placement._placement_panel.has_preview())
	placement._placement_panel.cancel_placement()
	assert_false(placement._placement_panel.has_preview())

func test_has_preview_returns_correct_state():
	assert_false(placement._placement_panel.has_preview())
	placement._placement_panel._select_tower(Enums.TowerId.SHOOTER)
	assert_true(placement._placement_panel.has_preview())
