extends GutTest


func test_tower_default_mult():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	add_child(tower)
	assert_eq(tower.damage_mult, 1.0)
	assert_eq(tower.speed_mult, 1.0)
	tower.queue_free()

func test_tower_apply_remove_buff():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	add_child(tower)
	tower.apply_buff(1.15, 1.1, "mint_1")
	assert_almost_eq(tower.damage_mult, 1.15, 0.01)
	assert_almost_eq(tower.speed_mult, 1.1, 0.01)
	tower.remove_buff("mint_1")
	assert_almost_eq(tower.damage_mult, 1.0, 0.01)
	assert_almost_eq(tower.speed_mult, 1.0, 0.01)
	tower.queue_free()

func test_tower_multiple_buff_sources():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	add_child(tower)
	tower.apply_buff(1.15, 1.1, "mint_1")
	tower.apply_buff(1.2, 1.05, "mint_2")
	# multiplicative: 1.15 * 1.2 = 1.38, 1.1 * 1.05 = 1.155
	assert_almost_eq(tower.damage_mult, 1.38, 0.01)
	assert_almost_eq(tower.speed_mult, 1.155, 0.01)
	tower.remove_buff("mint_1")
	assert_almost_eq(tower.damage_mult, 1.2, 0.01)
	tower.queue_free()
