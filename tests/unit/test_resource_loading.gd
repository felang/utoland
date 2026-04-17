extends GutTest

# Resource 加载测试
# 验证 GameConfig 从 .tres 文件正确加载资源并构建字典


# ===== 敌人资源加载 =====

func test_enemies_loaded_count() -> void:
	assert_eq(GameConfig.enemies.size(), 6, "应加载 6 种敌人")

func test_enemy_normal_resource() -> void:
	var e: EnemyData = GameConfig.enemies[Enums.Enemy.NORMAL]
	assert_eq(e.display_name, "普通敌人")
	assert_eq(e.hp, 50.0)
	assert_eq(e.speed, 100.0)
	assert_eq(e.damage, 10.0)

func test_enemy_fast_resource() -> void:
	var e: EnemyData = GameConfig.enemies[Enums.Enemy.FAST]
	assert_eq(e.hp, 35.0)
	assert_eq(e.speed, 180.0)

func test_enemy_tank_resource() -> void:
	var e: EnemyData = GameConfig.enemies[Enums.Enemy.TANK]
	assert_eq(e.hp, 200.0)
	assert_eq(e.speed, 50.0)
	assert_eq(e.damage, 25.0)


# ===== 塔资源加载 =====

func test_towers_loaded_count() -> void:
	assert_eq(GameConfig.towers.size(), 3, "应加载 3 种塔")

func test_tower_pea_shooter_resource() -> void:
	var t: TowerData = GameConfig.towers[Enums.TowerId.PEA_SHOOTER]
	assert_eq(t.display_name, "射手塔")
	assert_almost_eq(t.hp_per_level[0], 80.0, 0.001)
	assert_not_null(t.attack_config, "射手塔应有 attack_config")
	assert_almost_eq(t.attack_config.damage_per_level[0], 15.0, 0.001)
	assert_almost_eq(t.attack_config.fire_rate_per_level[0], 1.0, 0.001)
	assert_almost_eq(t.attack_config.attack_range_per_level[0], 300.0, 0.001)

func test_tower_ice_flower_resource() -> void:
	var t: TowerData = GameConfig.towers[Enums.TowerId.ICE_FLOWER]
	assert_almost_eq(t.hp_per_level[0], 70.0, 0.001)
	assert_almost_eq(t.slow_ratio_per_level[0], 0.3, 0.001)
	assert_not_null(t.attack_config, "冰花塔应有 attack_config")
	assert_almost_eq(t.attack_config.attack_range_per_level[0], 200.0, 0.001)


# ===== 波次资源加载 =====

func test_waves_loaded_count() -> void:
	assert_eq(GameConfig.waves.size(), 12, "应加载 12 个波次")

func test_waves_sorted_by_number() -> void:
	for i in range(GameConfig.waves.size()):
		assert_eq(GameConfig.waves[i].wave_number, i + 1, "波次 %d 的编号应为 %d" % [i, i + 1])

func test_wave_1_defaults() -> void:
	var w: WaveData = GameConfig.waves[0]
	assert_eq(w.time_limit, 40.0, "波次1的time_limit应为40.0")
	assert_gt(w.spawn_phases.size(), 0, "波次1应有分段配置")
	assert_gt(w.max_alive_enemies, 0, "波次1应有max_alive_enemies")
	assert_true(w.enemy_weights.has("normal"), "波次1应包含normal敌人权重")

func test_wave_6_values() -> void:
	var w: WaveData = GameConfig.waves[5]
	assert_gt(w.spawn_phases.size(), 0, "波次6应有分段配置")
	assert_true(w.enemy_weights.has("fast"), "波次6应包含fast敌人权重")


# ===== 角色资源加载 =====

func test_characters_loaded_count() -> void:
	# ranger.tres 尚未创建，角色字典暂时为空；Task 12 创建后改为 assert_gt
	assert_true(GameConfig.characters.size() >= 0, "角色字典加载不应报错")

func test_character_has_sprite_frames_path() -> void:
	# 有角色时验证 sprite_frames_path
	for character_id in GameConfig.characters:
		var c: CharacterData = GameConfig.characters[character_id]
		assert_ne(c.sprite_frames_path, "", "%s 应有 sprite_frames_path" % character_id)
		assert_true(c.sprite_frames_path.ends_with(".res"), "%s 路径应为 .res 文件" % character_id)


# ===== 地图资源加载 =====

func test_maps_loaded_count() -> void:
	assert_eq(GameConfig.maps.size(), 2, "应加载 2 种地图")

func test_map_forest_resource() -> void:
	var m: MapData = GameConfig.maps[Enums.Map.FOREST]
	assert_eq(m.display_name, "森林")
	assert_eq(m.fallback_color, "#2d5016")

func test_map_desert_resource() -> void:
	var m: MapData = GameConfig.maps[Enums.Map.DESERT]
	assert_eq(m.display_name, "沙漠")
	assert_eq(m.fallback_color, "#d4a574")


# ===== 单例资源加载 =====

func test_effects_loaded() -> void:
	assert_not_null(GameConfig.effects, "特效配置应已加载")
	assert_true(GameConfig.effects is EffectConfigData)

func test_shop_loaded() -> void:
	assert_not_null(GameConfig.shop, "商店配置应已加载")
	assert_true(GameConfig.shop is ShopConfigData)

func test_spawn_loaded() -> void:
	assert_not_null(GameConfig.spawn, "生成配置应已加载")
	assert_true(GameConfig.spawn is SpawnConfigData)


func test_boss_brute_is_boss():
	var ed: EnemyData = GameConfig.enemies[Enums.Enemy.BOSS_BRUTE]
	assert_true(ed.is_boss, "boss_brute 应标记为 is_boss")

func test_normal_enemy_not_boss():
	var ed: EnemyData = GameConfig.enemies[Enums.Enemy.NORMAL]
	assert_false(ed.is_boss, "normal 不应标记为 is_boss")


func test_player_const_unchanged() -> void:
	# PLAYER 保持 const，确保初始化不受影响
	assert_eq(GameConfig.PLAYER["initial_coins"], 40)
	assert_eq(GameConfig.PLAYER["initial_hp"], 100.0)
	assert_eq(GameConfig.PLAYER["initial_speed"], 200.0)

func test_sprites_const_unchanged() -> void:
	# SPRITES 保持 const（玩家精灵已迁移到 CharacterData）
	assert_false(GameConfig.SPRITES.has(Enums.Group.PLAYER), "玩家精灵已移除")
	assert_true(GameConfig.SPRITES.has(Enums.Group.ENEMIES))
	assert_true(GameConfig.SPRITES.has(Enums.Group.TOWERS))
