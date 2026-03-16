extends Node

# Scene preloads - centralized
var _tower_scenes: Dictionary = {
	Enums.TowerId.PEA_SHOOTER: preload("res://scenes/entities/towers/tower_pea_shooter.tscn"),
	Enums.TowerId.ICE_FLOWER: preload("res://scenes/entities/towers/tower_ice_flower.tscn"),
	Enums.TowerId.SUNFLOWER: preload("res://scenes/entities/towers/tower_sunflower.tscn"),
}

var _enemy_scenes: Dictionary = {
	Enums.Enemy.NORMAL: preload("res://scenes/entities/enemies/enemy_normal.tscn"),
	Enums.Enemy.FAST: preload("res://scenes/entities/enemies/enemy_fast.tscn"),
	Enums.Enemy.TANK: preload("res://scenes/entities/enemies/enemy_tank.tscn"),
	Enums.Enemy.BOSS_BRUTE: preload("res://scenes/entities/enemies/boss_brute.tscn"),
	Enums.Enemy.BOSS_SUMMONER: preload("res://scenes/entities/enemies/boss_summoner.tscn"),
	Enums.Enemy.BOSS_GUARDIAN: preload("res://scenes/entities/enemies/boss_guardian.tscn"),
}

var _bullet_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/bullet_projectile.tscn")
var _shuriken_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/shuriken_projectile.tscn")
var _coin_scene: PackedScene = preload("res://scenes/entities/coin.tscn")

# Tower creation — 注入 TowerData Resource，level 直接注入
func create_tower(type: String, level: int = 1) -> Node2D:
	if not _tower_scenes.has(type):
		push_error("Unknown tower type: " + type)
		return null

	var tower = _tower_scenes[type].instantiate()
	tower.tower_type = type
	tower.current_level = level
	# 注入 Resource 数据
	if GameConfig.towers.has(type):
		tower.data = GameConfig.towers[type]
	return tower

# Enemy creation — 注入 EnemyData Resource
func create_enemy(type: String) -> CharacterBody2D:
	if not _enemy_scenes.has(type):
		push_error("Unknown enemy type: " + type)
		return null

	var enemy = _enemy_scenes[type].instantiate()
	enemy.enemy_type = type
	# 注入 Resource 数据
	if GameConfig.enemies.has(type):
		enemy.data = GameConfig.enemies[type]
	return enemy

# Coin creation
func create_coin() -> Area2D:
	return _coin_scene.instantiate()

# 统一投射物创建 — 从 ProjectileData 实例化
func create_projectile(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, extra_pierce: int = 0) -> ProjectileBase:
	assert(p_data != null, "SceneFactory.create_projectile: data 不能为 null")
	assert(p_data.projectile_scene != null, "SceneFactory.create_projectile: projectile_scene 未配置")
	var proj: ProjectileBase = p_data.projectile_scene.instantiate()
	proj.setup(p_data, damage, from, direction, extra_pierce)
	return proj

# [过渡兼容] BulletProjectile 创建 — 后续 Task 16 删除
func create_bullet_projectile() -> ProjectileBase:
	return _bullet_projectile_scene.instantiate()

# [过渡兼容] ShurikenProjectile 创建 — 后续 Task 16 删除
func create_shuriken_projectile() -> ShurikenProjectile:
	return _shuriken_projectile_scene.instantiate()
