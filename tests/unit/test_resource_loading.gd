extends GutTest

# Resource 加载测试
# 验证 GameConfig 从 .tres 文件正确加载资源并构建向后兼容字典


# ===== 武器资源加载 =====

func test_weapons_loaded_count() -> void:
	assert_eq(GameConfig.weapons.size(), 3, "应加载 3 种武器")

func test_weapon_rifle_resource() -> void:
	assert_true(GameConfig.weapons.has(Enums.WeaponId.RIFLE), "应包含 rifle")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.RIFLE]
	assert_eq(w.id, Enums.WeaponId.RIFLE)
	assert_eq(w.display_name, "步枪")
	assert_eq(w.projectile_type, Enums.ProjectileId.BULLET)
	assert_eq(w.fire_rate, 0.1)
	assert_eq(w.damage, 10.0)
	assert_eq(w.weapon_range, 300.0)
	assert_eq(w.bullet_count, 1)
	assert_eq(w.bullet_speed, 600.0)

func test_weapon_boomerang_resource() -> void:
	assert_true(GameConfig.weapons.has(Enums.WeaponId.BOOMERANG), "应包含 boomerang")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.BOOMERANG]
	assert_eq(w.projectile_type, Enums.ProjectileId.BOOMERANG)
	assert_eq(w.fire_rate, 0.8)
	assert_eq(w.damage, 15.0)
	assert_eq(w.boomerang_speed, 350.0)
	assert_eq(w.outbound_distance, 200.0)
	assert_eq(w.return_speed_mult, 1.3)

func test_weapon_laser_resource() -> void:
	assert_true(GameConfig.weapons.has(Enums.WeaponId.LASER), "应包含 laser")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.LASER]
	assert_eq(w.projectile_type, Enums.ProjectileId.LASER)
	assert_eq(w.fire_rate, 0.15)
	assert_eq(w.damage, 8.0)
	assert_eq(w.beam_range, 400.0)
	assert_eq(w.beam_width, 2.0)
	assert_eq(w.beam_duration, 0.08)


# ===== 敌人资源加载 =====

func test_enemies_loaded_count() -> void:
	assert_eq(GameConfig.enemies.size(), 4, "应加载 4 种敌人")

func test_enemy_normal_resource() -> void:
	var e: EnemyData = GameConfig.enemies[Enums.Enemy.NORMAL]
	assert_eq(e.display_name, "普通敌人")
	assert_eq(e.hp, 50.0)
	assert_eq(e.speed, 100.0)
	assert_eq(e.damage, 10.0)
	assert_eq(e.coin_drop_min, 1)
	assert_eq(e.coin_drop_max, 3)

func test_enemy_fast_resource() -> void:
	var e: EnemyData = GameConfig.enemies[Enums.Enemy.FAST]
	assert_eq(e.hp, 35.0)
	assert_eq(e.speed, 180.0)
	assert_eq(e.coin_drop_min, 2)
	assert_eq(e.coin_drop_max, 4)

func test_enemy_tank_resource() -> void:
	var e: EnemyData = GameConfig.enemies[Enums.Enemy.TANK]
	assert_eq(e.hp, 200.0)
	assert_eq(e.speed, 50.0)
	assert_eq(e.damage, 25.0)
	assert_eq(e.coin_drop_min, 5)
	assert_eq(e.coin_drop_max, 10)


# ===== 塔资源加载 =====

func test_towers_loaded_count() -> void:
	assert_eq(GameConfig.towers.size(), 3, "应加载 3 种塔")

func test_tower_shooter_resource() -> void:
	var t: TowerData = GameConfig.towers[Enums.TowerId.SHOOTER]
	assert_eq(t.display_name, "射手塔")
	assert_eq(t.hp, 80.0)
	assert_eq(t.damage, 15.0)
	assert_eq(t.fire_rate, 1.0)
	assert_eq(t.attack_range, 300.0)

func test_tower_wall_resource() -> void:
	var t: TowerData = GameConfig.towers[Enums.TowerId.WALL]
	assert_eq(t.hp, 300.0)
	assert_eq(t.damage, 0.0)

func test_tower_slow_resource() -> void:
	var t: TowerData = GameConfig.towers[Enums.TowerId.SLOW]
	assert_eq(t.hp, 70.0)
	assert_eq(t.slow_percent, 0.3)
	assert_eq(t.attack_range, 200.0)


# ===== 波次资源加载 =====

func test_waves_loaded_count() -> void:
	assert_eq(GameConfig.waves.size(), 18, "应加载 18 个波次")

func test_waves_sorted_by_number() -> void:
	for i in range(GameConfig.waves.size()):
		assert_eq(GameConfig.waves[i].wave_number, i + 1, "波次 %d 的编号应为 %d" % [i, i + 1])

func test_wave_1_defaults() -> void:
	var w: WaveData = GameConfig.waves[0]
	assert_eq(w.time_limit, 45.0, "波次1的time_limit应为45.0")
	assert_eq(w.spawn_interval, 2.0, "波次1的spawn_interval应为2.0")
	assert_true(w.enemy_weights.has("normal"), "波次1应包含normal敌人权重")

func test_wave_6_values() -> void:
	var w: WaveData = GameConfig.waves[5]
	assert_eq(w.time_limit, 55.0, "波次6的time_limit应为55.0")
	assert_eq(w.spawn_interval, 1.2, "波次6的spawn_interval应为1.2")
	assert_true(w.enemy_weights.has("tank"), "波次6应包含tank敌人权重")


# ===== 角色资源加载 =====

func test_characters_loaded_count() -> void:
	assert_eq(GameConfig.characters.size(), 4, "应加载 4 种角色")

func test_character_warrior_resource() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.WARRIOR]
	assert_eq(c.display_name, "战士")
	assert_eq(c.max_hp, 150.0)
	assert_eq(c.speed, 180.0)
	assert_eq(c.damage_mult, 1.2)

func test_character_ranger_resource() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.RANGER]
	assert_eq(c.max_hp, 80.0)
	assert_eq(c.attack_speed_mult, 1.1)
	assert_eq(c.move_speed_mult, 1.25)

func test_character_tank_resource() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.TANK]
	assert_eq(c.max_hp, 200.0)
	assert_eq(c.hp_regen, 1.0)

func test_character_warrior_has_default_weapon() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.WARRIOR]
	assert_eq(c.default_weapon, Enums.WeaponId.RIFLE, "战士默认武器应为步枪")

func test_character_ranger_has_default_weapon() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.RANGER]
	assert_eq(c.default_weapon, Enums.WeaponId.BOOMERANG, "游侠默认武器应为回旋镖")

func test_character_tank_has_default_weapon() -> void:
	var c: CharacterData = GameConfig.characters[Enums.Character.TANK]
	assert_eq(c.default_weapon, Enums.WeaponId.LASER, "坦克默认武器应为激光枪")


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


func test_player_const_unchanged() -> void:
	# PLAYER 保持 const，确保 GameData 初始化不受影响
	assert_eq(GameConfig.PLAYER["initial_coins"], 100)
	assert_eq(GameConfig.PLAYER["initial_hp"], 100.0)
	assert_eq(GameConfig.PLAYER["initial_speed"], 200.0)

func test_sprites_const_unchanged() -> void:
	# SPRITES 保持 const
	assert_true(GameConfig.SPRITES.has(Enums.Group.PLAYER))
	assert_true(GameConfig.SPRITES.has(Enums.Group.ENEMIES))
	assert_true(GameConfig.SPRITES.has(Enums.Group.TOWERS))
