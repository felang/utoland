class_name CollisionLayers

# 层编号（1-32），用于 set_collision_layer_value() / set_collision_mask_value()
const PLAYER_LAYER = 1     # bit value: 1
const ENEMY_LAYER = 2      # bit value: 2
const HITBOX_LAYER = 3     # bit value: 4
const TOWER_LAYER = 4      # bit value: 8
const HURTBOX_LAYER = 8    # bit value: 128

# 位掩码值，用于直接赋值 collision_layer / collision_mask
const PLAYER = 1
const ENEMY = 2
const HITBOX = 4
const TOWER = 8
const HURTBOX = 128
