extends GutTest

# Resource 加载测试
# 验证 GameConfig 从 .tres 文件正确加载资源并构建向后兼容字典


# ===== 武器资源加载 =====

func test_weapons_loaded_count() -> void:
	assert_eq(GameConfig.weapons.size(), 3, "应加载 3 种武器")

func test_weapon_rifle_resource() -> void:
	assert_true(GameConfig.weapons.has("rifle"), "应包含 rifle")
	var w: WeaponData = GameConfig.weapons["rifle"]
	assert_eq(w.id, "rifle")
	assert_eq(w.display_name, "步枪")
	assert_eq(w.projectile_type, "bullet")
	assert_eq(w.fire_rate, 0.1)
	assert_eq(w.damage, 10.0)
	assert_eq(w.weapon_range, 300.0)
	assert_eq(w.bullet_count, 1)
	assert_eq(w.bullet_speed, 600.0)

func test_weapon_boomerang_resource() -> void:
	assert_true(GameConfig.weapons.has("boomerang"), "应包含 boomerang")
	var w: WeaponData = GameConfig.weapons["boomerang"]
	assert_eq(w.projectile_type, "boomerang")
	assert_eq(w.fire_rate, 0.8)
	assert_eq(w.damage, 15.0)
	assert_eq(w.boomerang_speed, 350.0)
	assert_eq(w.outbound_distance, 200.0)
	assert_eq(w.return_speed_mult, 1.3)

func test_weapon_laser_resource() -> void:
	assert_true(GameConfig.weapons.has("laser"), "应包含 laser")
	var w: WeaponData = GameConfig.weapons["laser"]
	assert_eq(w.projectile_type, "laser")
	assert_eq(w.fire_rate, 0.15)
	assert_eq(w.damage, 8.0)
	assert_eq(w.beam_range, 400.0)
	assert_eq(w.beam_width, 2.0)
	assert_eq(w.beam_duration, 0.08)


# ===== 敌人资源加载 =====

func test_enemies_loaded_count() -> void:
	assert_eq(GameConfig.enemies.size(), 3, "应加载 3 种敌人")

func test_enemy_normal_resource() -> void:
	var e: EnemyData = GameConfig.enemies["normal"]
	assert_eq(e.display_name, "普通敌人")
	assert_eq(e.hp, 50.0)
	assert_eq(e.speed, 100.0)
	assert_eq(e.damage, 10.0)
	assert_eq(e.coin_drop_min, 1)
	assert_eq(e.coin_drop_max, 3)

func test_enemy_fast_resource() -> void:
	var e: EnemyData = GameConfig.enemies["fast"]
	assert_eq(e.hp, 35.0)
	assert_eq(e.speed, 180.0)
	assert_eq(e.coin_drop_min, 2)
	assert_eq(e.coin_drop_max, 4)

func test_enemy_tank_resource() -> void:
	var e: EnemyData = GameConfig.enemies["tank"]
	assert_eq(e.hp, 200.0)
	assert_eq(e.speed, 50.0)
	assert_eq(e.damage, 25.0)
	assert_eq(e.coin_drop_min, 5)
	assert_eq(e.coin_drop_max, 10)


# ===== 塔资源加载 =====

func test_towers_loaded_count() -> void:
	assert_eq(GameConfig.towers.size(), 3, "应加载 3 种塔")

func test_tower_shooter_resource() -> void:
	var t: TowerData = GameConfig.towers["shooter"]
	assert_eq(t.display_name, "射手塔")
	assert_eq(t.hp, 80.0)
	assert_eq(t.damage, 15.0)
	assert_eq(t.fire_rate, 1.0)
	assert_eq(t.attack_range, 300.0)

func test_tower_wall_resource() -> void:
	var t: TowerData = GameConfig.towers["wall"]
	assert_eq(t.hp, 300.0)
	assert_eq(t.damage, 0.0)

func test_tower_slow_resource() -> void:
	var t: TowerData = GameConfig.towers["slow"]
	assert_eq(t.hp, 70.0)
	assert_eq(t.slow_percent, 0.3)
	assert_eq(t.attack_range, 200.0)


# ===== 波次资源加载 =====

func test_waves_loaded_count() -> void:
	assert_eq(GameConfig.waves.size(), 10, "应加载 10 个波次")

func test_waves_sorted_by_number() -> void:
	for i in range(GameConfig.waves.size()):
		assert_eq(GameConfig.waves[i].wave_number, i + 1, "波次 %d 的编号应为 %d" % [i, i + 1])

func test_wave_1_defaults() -> void:
	var w: WaveData = GameConfig.waves[0]
	assert_eq(w.duration, 45.0)
	assert_eq(w.spawn_interval, 1.5)
	assert_eq(Array(w.enemy_types), ["normal"])

func test_wave_6_values() -> void:
	var w: WaveData = GameConfig.waves[5]
	assert_eq(w.duration, 55.0)
	assert_eq(w.spawn_interval, 0.8)
	assert_eq(Array(w.enemy_types), ["normal", "fast", "tank"])


# ===== 角色资源加载 =====

func test_characters_loaded_count() -> void:
	assert_eq(GameConfig.characters.size(), 3, "应加载 3 种角色")

func test_character_warrior_resource() -> void:
	var c: CharacterData = GameConfig.characters["warrior"]
	assert_eq(c.display_name, "战士")
	assert_eq(c.max_hp, 150.0)
	assert_eq(c.speed, 180.0)
	assert_eq(c.damage_mult, 1.2)

func test_character_ranger_resource() -> void:
	var c: CharacterData = GameConfig.characters["ranger"]
	assert_eq(c.max_hp, 80.0)
	assert_eq(c.attack_speed_mult, 1.1)
	assert_eq(c.move_speed_mult, 1.25)

func test_character_tank_resource() -> void:
	var c: CharacterData = GameConfig.characters["tank"]
	assert_eq(c.max_hp, 200.0)
	assert_eq(c.hp_regen, 1.0)


# ===== 地图资源加载 =====

func test_maps_loaded_count() -> void:
	assert_eq(GameConfig.maps.size(), 2, "应加载 2 种地图")

func test_map_forest_resource() -> void:
	var m: MapData = GameConfig.maps["forest"]
	assert_eq(m.display_name, "森林")
	assert_eq(m.fallback_color, "#2d5016")

func test_map_desert_resource() -> void:
	var m: MapData = GameConfig.maps["desert"]
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


# ===== 向后兼容字典测试 =====

func test_compat_weapons_dict() -> void:
	assert_eq(GameConfig.WEAPONS.size(), 3)
	assert_eq(GameConfig.WEAPONS["rifle"]["projectile_type"], "bullet")
	assert_eq(GameConfig.WEAPONS["rifle"]["fire_rate"], 0.1)
	assert_eq(GameConfig.WEAPONS["rifle"]["damage"], 10.0)
	assert_eq(GameConfig.WEAPONS["rifle"]["range"], 300.0)
	assert_eq(GameConfig.WEAPONS["rifle"]["bullet_count"], 1)
	assert_eq(GameConfig.WEAPONS["rifle"]["bullet_speed"], 600.0)
	# 回旋镖特有字段
	assert_eq(GameConfig.WEAPONS["boomerang"]["speed"], 350.0)
	assert_eq(GameConfig.WEAPONS["boomerang"]["outbound_distance"], 200.0)
	# 激光特有字段
	assert_eq(GameConfig.WEAPONS["laser"]["beam_range"], 400.0)
	assert_eq(GameConfig.WEAPONS["laser"]["beam_duration"], 0.08)

func test_compat_enemies_dict() -> void:
	assert_eq(GameConfig.ENEMIES.size(), 3)
	assert_eq(GameConfig.ENEMIES["normal"]["hp"], 50.0)
	assert_eq(GameConfig.ENEMIES["fast"]["speed"], 180.0)
	assert_eq(GameConfig.ENEMIES["tank"]["damage"], 25.0)

func test_compat_towers_dict() -> void:
	assert_eq(GameConfig.TOWERS.size(), 3)
	assert_eq(GameConfig.TOWERS["shooter"]["damage"], 15.0)
	assert_eq(GameConfig.TOWERS["wall"]["hp"], 300.0)
	assert_true(GameConfig.TOWERS["slow"].has("slow_percent"))
	assert_eq(GameConfig.TOWERS["slow"]["slow_percent"], 0.3)

func test_compat_waves_dict() -> void:
	assert_eq(GameConfig.WAVES["total_waves"], 10)
	assert_eq(GameConfig.WAVES["wave_configs"].size(), 10)
	# 第一波
	assert_eq(GameConfig.WAVES["wave_configs"][0]["duration"], 45)
	assert_eq(GameConfig.WAVES["wave_configs"][0]["spawn_interval"], 1.5)
	assert_eq(GameConfig.WAVES["wave_configs"][0]["enemy_types"], ["normal"])
	# 第六波
	assert_eq(GameConfig.WAVES["wave_configs"][5]["spawn_interval"], 0.8)
	assert_true(GameConfig.WAVES["wave_configs"][5]["enemy_types"].has("tank"))

func test_compat_characters_dict() -> void:
	assert_eq(GameConfig.CHARACTERS.size(), 3)
	assert_eq(GameConfig.CHARACTERS["warrior"]["max_hp"], 150.0)
	assert_eq(GameConfig.CHARACTERS["ranger"]["move_speed_mult"], 1.25)
	assert_eq(GameConfig.CHARACTERS["tank"]["hp_regen"], 1.0)

func test_compat_shop_dict() -> void:
	assert_eq(GameConfig.SHOP["refresh_cost"], 10)
	assert_eq(GameConfig.SHOP["item_count"], 4)
	assert_eq(GameConfig.SHOP["heal_price"], 12)
	assert_eq(GameConfig.SHOP["heal_amount"], 50)

func test_compat_maps_dict() -> void:
	assert_eq(GameConfig.MAPS.size(), 2)
	assert_eq(GameConfig.MAPS["forest"]["name"], "森林")
	assert_eq(GameConfig.MAPS["desert"]["fallback_color"], "#d4a574")

func test_compat_effects_dict() -> void:
	assert_eq(GameConfig.EFFECTS["camera_shake"]["player_hit"]["intensity"], 3.0)
	assert_eq(GameConfig.EFFECTS["knockback"]["distance"], 15.0)
	assert_eq(GameConfig.EFFECTS["hit_flash"]["duration"], 0.05)
	assert_eq(GameConfig.EFFECTS["damage_number"]["float_distance"], 30.0)
	assert_eq(GameConfig.EFFECTS["death_particles"]["count"], 10)
	assert_eq(GameConfig.EFFECTS["bullet_trail"]["length"], 15.0)
	assert_eq(GameConfig.EFFECTS["boomerang"]["rotation_speed"], 720.0)
	assert_eq(GameConfig.EFFECTS["laser"]["beam_width"], 4.0)
	assert_eq(GameConfig.EFFECTS["camera"]["smoothing_speed"], 8.0)

func test_player_const_unchanged() -> void:
	# PLAYER 保持 const，确保 GameData 初始化不受影响
	assert_eq(GameConfig.PLAYER["initial_coins"], 100)
	assert_eq(GameConfig.PLAYER["initial_hp"], 100.0)
	assert_eq(GameConfig.PLAYER["initial_speed"], 200.0)

func test_sprites_const_unchanged() -> void:
	# SPRITES 保持 const
	assert_true(GameConfig.SPRITES.has("player"))
	assert_true(GameConfig.SPRITES.has("enemies"))
	assert_true(GameConfig.SPRITES.has("towers"))
