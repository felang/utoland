extends GutTest

func _make_weapon_option() -> Dictionary:
	return {
		"type": "weapon",
		"id": Enums.WeaponId.RIFLE,
		"is_new": false,
		"current_level": 1,
		"target_level": 2,
	}

func _make_tower_option() -> Dictionary:
	return {
		"type": "tower",
		"id": Enums.TowerId.PEA_SHOOTER,
		"is_new": true,
		"current_level": 0,
		"target_level": 1,
	}

func test_create_weapon_card():
	var card: PanelContainer = UpgradeCardBuilder.create_card(
		_make_weapon_option(), func(): pass
	)
	assert_not_null(card, "应创建武器卡片")
	assert_eq(card.custom_minimum_size, Vector2(UpgradeCardBuilder.CARD_WIDTH, UpgradeCardBuilder.CARD_HEIGHT))
	card.queue_free()

func test_create_tower_card():
	var card: PanelContainer = UpgradeCardBuilder.create_card(
		_make_tower_option(), func(): pass
	)
	assert_not_null(card, "应创建塔卡片")
	card.queue_free()

func test_create_new_item_card():
	var opt: Dictionary = _make_tower_option()
	opt["is_new"] = true
	var card: PanelContainer = UpgradeCardBuilder.create_card(opt, func(): pass)
	assert_not_null(card)
	card.queue_free()

func test_create_upgrade_card():
	var opt: Dictionary = _make_weapon_option()
	opt["is_new"] = false
	opt["current_level"] = 2
	opt["target_level"] = 3
	var card: PanelContainer = UpgradeCardBuilder.create_card(opt, func(): pass)
	assert_not_null(card)
	card.queue_free()
