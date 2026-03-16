extends GutTest

func test_bitmask_values_match_layer_numbers():
	assert_eq(CollisionLayers.PLAYER, 1 << (CollisionLayers.PLAYER_LAYER - 1))
	assert_eq(CollisionLayers.ENEMY, 1 << (CollisionLayers.ENEMY_LAYER - 1))
	assert_eq(CollisionLayers.HITBOX, 1 << (CollisionLayers.HITBOX_LAYER - 1))
	assert_eq(CollisionLayers.TOWER, 1 << (CollisionLayers.TOWER_LAYER - 1))
	assert_eq(CollisionLayers.HURTBOX, 1 << (CollisionLayers.HURTBOX_LAYER - 1))
