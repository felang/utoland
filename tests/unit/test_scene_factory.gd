extends GutTest

# Unit tests for SceneFactory
# Tests tower, enemy, bullet, and coin creation

# Tower creation tests
func test_create_tower_shooter():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	assert_not_null(tower, "Pea shooter tower should be created")
	assert_eq(tower.tower_type, Enums.TowerId.PEA_SHOOTER, "Tower type should be 'pea_shooter'")
	tower.queue_free()

func test_create_tower_ice_flower():
	var tower = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	assert_not_null(tower, "Ice flower tower should be created")
	assert_eq(tower.tower_type, Enums.TowerId.ICE_FLOWER, "Tower type should be 'ice_flower'")
	tower.queue_free()

func test_create_tower_sunflower():
	var tower = SceneFactory.create_tower(Enums.TowerId.SUNFLOWER)
	assert_not_null(tower, "应能创建向日葵塔")
	assert_eq(tower.tower_type, Enums.TowerId.SUNFLOWER)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()

func test_create_tower_invalid():
	var tower = SceneFactory.create_tower("invalid_type")
	assert_null(tower, "Invalid tower type should return null")
	assert_push_error("Unknown tower type")

# Enemy creation tests
func test_create_enemy_normal():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	assert_not_null(enemy, "Normal enemy should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.NORMAL, "Enemy type should be 'normal'")
	enemy.queue_free()

func test_create_enemy_fast():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.FAST)
	assert_not_null(enemy, "Fast enemy should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.FAST, "Enemy type should be 'fast'")
	enemy.queue_free()

func test_create_enemy_tank():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.TANK)
	assert_not_null(enemy, "Tank enemy should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.TANK, "Enemy type should be 'tank'")
	enemy.queue_free()

func test_create_enemy_boss_brute():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.BOSS_BRUTE)
	assert_not_null(enemy, "Boss brute should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.BOSS_BRUTE)
	enemy.queue_free()

func test_create_enemy_boss_summoner():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.BOSS_SUMMONER)
	assert_not_null(enemy, "Boss summoner should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.BOSS_SUMMONER)
	enemy.queue_free()

func test_create_enemy_boss_guardian():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.BOSS_GUARDIAN)
	assert_not_null(enemy, "Boss guardian should be created")
	assert_eq(enemy.enemy_type, Enums.Enemy.BOSS_GUARDIAN)
	enemy.queue_free()

func test_all_enemies_can_be_created():
	var all_ids: Array[String] = [
		Enums.Enemy.NORMAL, Enums.Enemy.FAST, Enums.Enemy.TANK,
		Enums.Enemy.BOSS_BRUTE, Enums.Enemy.BOSS_SUMMONER, Enums.Enemy.BOSS_GUARDIAN,
	]
	for id in all_ids:
		var enemy = SceneFactory.create_enemy(id)
		assert_not_null(enemy, "应能创建敌人: " + id)
		assert_eq(enemy.enemy_type, id)
		assert_not_null(enemy.data, id + " 应注入 EnemyData")
		enemy.queue_free()

func test_create_enemy_invalid():
	var enemy = SceneFactory.create_enemy("invalid_type")
	assert_null(enemy, "Invalid enemy type should return null")
	assert_push_error("Unknown enemy type")

# Coin tests
func test_create_coin():
	var coin = SceneFactory.create_coin()
	assert_not_null(coin, "Coin should be created")
	coin.queue_free()

# Tower level injection test
func test_create_tower_with_level():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER, 2)
	assert_not_null(tower, "Shooter tower should be created")
	add_child_autofree(tower)
	var td: TowerData = GameConfig.towers[Enums.TowerId.PEA_SHOOTER]
	assert_almost_eq(tower.health.max_hp, td.hp_per_level[1], 0.01,
		"Lv2 tower HP should match hp_per_level[1]")

# 统一投射物工厂方法测试
func test_create_projectile():
	var pd := ProjectileData.new()
	pd.speed = 800.0
	pd.lifetime = 5.0
	pd.projectile_scene = preload("res://scenes/entities/projectiles/bullet_projectile.tscn")
	var proj: ProjectileBase = SceneFactory.create_projectile(pd, 10.0, Vector2.ZERO, Vector2.RIGHT)
	assert_not_null(proj, "ProjectileBase should be created via create_projectile")
	proj.queue_free()

func test_create_shuriken_via_projectile():
	var wd: WeaponData = GameConfig.weapons[Enums.WeaponId.SHURIKEN]
	assert_not_null(wd.projectile_data, "Shuriken weapon should have projectile_data")
	var proj: ProjectileBase = SceneFactory.create_projectile(wd.projectile_data, 10.0, Vector2.ZERO, Vector2.RIGHT)
	assert_not_null(proj, "ShurikenProjectile should be created via create_projectile")
	proj.queue_free()

func test_all_towers_can_be_created():
	var all_ids: Array[String] = [
		Enums.TowerId.PEA_SHOOTER, Enums.TowerId.ICE_FLOWER,
		Enums.TowerId.SUNFLOWER,
	]
	for id in all_ids:
		var tower = SceneFactory.create_tower(id)
		assert_not_null(tower, "应能创建塔: " + id)
		add_child(tower)
		assert_eq(tower.tower_type, id)
		assert_not_null(tower.data, id + " 应注入 TowerData")
		tower.queue_free()

func test_all_weapons_loaded():
	var all_ids: Array[String] = [
		Enums.WeaponId.BOW, Enums.WeaponId.SHURIKEN, Enums.WeaponId.SWORD,
	]
	for id in all_ids:
		assert_true(GameConfig.weapons.has(id), "应包含武器: " + id)
		var w: WeaponData = GameConfig.weapons[id]
		assert_true(w.attack_mode == 0 or w.attack_mode == 1, id + " attack_mode 应为 0 或 1")
		assert_eq(w.damage_per_level.size(), w.max_level, id + " damage_per_level 数量应匹配 max_level")
