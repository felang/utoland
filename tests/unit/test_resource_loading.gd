extends GutTest

# Resource 加载测试
# 验证 GameConfig 从 .tres 文件正确加载资源并构建向后兼容字典


# ===== 武器资源加载 =====

func test_weapons_loaded_count() -> void:
	assert_eq(GameConfig.weapons.size(), 3, "应加载 3 种武器")

func test_weapon_bow_resource() -> void:
	assert_true(GameConfig.weapons.has(Enums.WeaponId.BOW), "应包含 bow")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.BOW]
	assert_eq(w.id, Enums.WeaponId.BOW)
	assert_eq(w.display_name, "弓")
	assert_eq(w.projectile_type, Enums.ProjectileId.BULLET)
	assert_almost_eq(w.fire_rate_per_level[0], 0.5, 0.001)
	assert_almost_eq(w.damage_per_level[0], 8.0, 0.001)
	assert_almost_eq(w.weapon_range_per_level[0], 150.0, 0.001)
	assert_eq(w.bullet_count, 1)
	assert_eq(w.bullet_speed, 300.0)

func test_weapon_shuriken_resource() -> void:
	assert_true(GameConfig.weapons.has(Enums.WeaponId.SHURIKEN), "应包含 shuriken")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.SHURIKEN]
	assert_eq(w.projectile_type, Enums.ProjectileId.SHURIKEN)
	assert_almost_eq(w.fire_rate_per_level[0], 0.8, 0.001)
	assert_almost_eq(w.damage_per_level[0], 15.0, 0.001)
	assert_eq(w.shuriken_speed, 175.0)
	assert_eq(w.outbound_distance, 100.0)
	assert_eq(w.return_speed_mult, 1.3)

func test_weapon_sword_resource() -> void:
	assert_true(GameConfig.weapons.has(Enums.WeaponId.SWORD), "应包含 sword")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.SWORD]
	assert_eq(w.weapon_type, "sword")
	assert_almost_eq(w.damage_per_level[0], 20.0, 0.001)


# ===== 敌人资源加载 =====

func test_enemies_loaded_count() -> void:
	assert_eq(GameConfig.enemies.size(), 6, "应加载 6 种敌人")

func test_enemy_normal_resource() -> void:
	var e: EnemyData = GameConfig.enemies[Enums.Enemy.NORMAL]
	assert_eq(e.display_name, "普通敌人")
	assert_eq(e.hp, 50.0)
	assert_eq(e.speed, 50.0)
	assert_eq(e.damage, 10.0)
	assert_eq(e.coin_drop_min, 1)
	assert_eq(e.coin_drop_max, 3)

func test_enemy_fast_resource() -> void:
	var e: EnemyData = GameConfig.enemies[Enums.Enemy.FAST]
	assert_eq(e.hp, 35.0)
	assert_eq(e.speed, 90.0)
	assert_eq(e.coin_drop_min, 2)
	assert_eq(e.coin_drop_max, 4)

func test_enemy_tank_resource() -> void:
	var e: EnemyData = GameConfig.enemies[Enums.Enemy.TANK]
	assert_eq(e.hp, 200.0)
	assert_eq(e.speed, 25.0)
	assert_eq(e.damage, 25.0)
	assert_eq(e.coin_drop_min, 5)
	assert_eq(e.coin_drop_max, 10)


# ===== 塔资源加载 =====

func test_towers_loaded_count() -> void:
	assert_eq(GameConfig.towers.size(), 3, "应加载 3 种塔")

func test_tower_pea_shooter_resource() -> void:
	var t: TowerData = GameConfig.towers[Enums.TowerId.PEA_SHOOTER]
	assert_eq(t.display_name, "射手塔")
	assert_almost_eq(t.hp_per_level[0], 80.0, 0.001)
	assert_almost_eq(t.damage_per_level[0], 15.0, 0.001)
	assert_almost_eq(t.fire_rate_per_level[0], 1.0, 0.001)
	assert_almost_eq(t.attack_range_per_level[0], 150.0, 0.001)

func test_tower_ice_flower_resource() -> void:
	var t: TowerData = GameConfig.towers[Enums.TowerId.ICE_FLOWER]
	assert_almost_eq(t.hp_per_level[0], 70.0, 0.001)
	assert_almost_eq(t.slow_ratio_per_level[0], 0.3, 0.001)
	assert_almost_eq(t.attack_range_per_level[0], 100.0, 0.001)


# ===== 波次资源加载 =====

func test_waves_loaded_count() -> void:
	assert_eq(GameConfig.waves.size(), 20, "应加载 20 个波次")

func test_waves_sorted_by_number() -> void:
	for i in range(GameConfig.waves.size()):
		assert_eq(GameConfig.waves[i].wave_number, i + 1, "波次 %d 的编号应为 %d" % [i, i + 1])

func test_wave_1_defaults() -> void:
	var w: WaveData = GameConfig.waves[0]
	assert_eq(w.time_limit, 60.0, "波次1的time_limit应为60.0")
	assert_eq(w.spawn_interval, 1.5, "波次1的spawn_interval应为1.5")
	assert_true(w.enemy_weights.has("normal"), "波次1应包含normal敌人权重")

func test_wave_6_values() -> void:
	var w: WaveData = GameConfig.waves[5]
	assert_eq(w.time_limit, 70.0, "波次6的time_limit应为70.0")
	assert_eq(w.spawn_interval, 0.9, "波次6的spawn_interval应为0.9")
	assert_true(w.enemy_weights.has("tank"), "波次6应包含tank敌人权重")


# ===== 角色资源加载 =====

func test_characters_loaded_count() -> void:
	assert_eq(GameConfig.characters.size(), 5, "应加载 5 种角色")

func test_character_dora_resource() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_eq(c.display_name, "朵拉")
	assert_eq(c.max_hp, 100.0)
	assert_eq(c.speed, 100.0)
	assert_eq(c.damage_mult, 1.0)
	assert_eq(c.recommended_weapon, Enums.WeaponId.BOW)

func test_character_gorg_resource() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.GORG]
	assert_eq(c.display_name, "格格")
	assert_eq(c.recommended_weapon, Enums.WeaponId.SWORD)

func test_character_kaze_resource() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.KAZE]
	assert_eq(c.display_name, "风")
	assert_eq(c.recommended_weapon, Enums.WeaponId.BOW)

func test_character_merlin_resource() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.MERLIN]
	assert_eq(c.display_name, "梅林")
	assert_eq(c.recommended_weapon, Enums.WeaponId.SHURIKEN)

func test_character_nemo_resource() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.NEMO]
	assert_eq(c.display_name, "尼莫")
	assert_eq(c.recommended_weapon, Enums.WeaponId.SHURIKEN)

func test_character_has_sprite_frames_path() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_ne(c.sprite_frames_path, "", "角色应有 sprite_frames_path")
	assert_true(c.sprite_frames_path.ends_with(".res"), "路径应为 .res 文件")


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


func test_weapon_has_weapon_type():
	var bow: WeaponData = GameConfig.weapons[Enums.WeaponId.BOW]
	assert_eq(bow.weapon_type, "bow", "bow weapon_type 应为 bow")
	var shuriken: WeaponData = GameConfig.weapons[Enums.WeaponId.SHURIKEN]
	assert_eq(shuriken.weapon_type, "shuriken", "shuriken weapon_type 应为 shuriken")
	var sword: WeaponData = GameConfig.weapons[Enums.WeaponId.SWORD]
	assert_eq(sword.weapon_type, "sword", "sword weapon_type 应为 sword")


func test_player_const_unchanged() -> void:
	# PLAYER 保持 const，确保 GameData 初始化不受影响
	assert_eq(GameConfig.PLAYER["initial_coins"], 100)
	assert_eq(GameConfig.PLAYER["initial_hp"], 100.0)
	assert_eq(GameConfig.PLAYER["initial_speed"], 100.0)

func test_sprites_const_unchanged() -> void:
	# SPRITES 保持 const（玩家精灵已迁移到 CharacterData）
	assert_false(GameConfig.SPRITES.has(Enums.Group.PLAYER), "玩家精灵已移除")
	assert_true(GameConfig.SPRITES.has(Enums.Group.ENEMIES))
	assert_true(GameConfig.SPRITES.has(Enums.Group.TOWERS))
