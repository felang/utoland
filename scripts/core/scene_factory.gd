extends Node

# Scene preloads - centralized
var _tower_scenes: Dictionary = {
	Enums.TowerId.PEA_SHOOTER: preload("res://scenes/entities/towers/tower_pea_shooter.tscn"),
	Enums.TowerId.STUMP: preload("res://scenes/entities/towers/tower_stump.tscn"),
	Enums.TowerId.ICE_FLOWER: preload("res://scenes/entities/towers/tower_ice_flower.tscn")
}

var _enemy_scenes: Dictionary = {
	Enums.Enemy.NORMAL: preload("res://scenes/entities/enemies/enemy_normal.tscn"),
	Enums.Enemy.FAST: preload("res://scenes/entities/enemies/enemy_fast.tscn"),
	Enums.Enemy.TANK: preload("res://scenes/entities/enemies/enemy_tank.tscn"),
	Enums.Enemy.BOSS_BRUTE: preload("res://scenes/entities/enemies/boss_brute.tscn"),
}

var _bullet_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/bullet_projectile.tscn")
var _boomerang_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/boomerang_projectile.tscn")
var _laser_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/laser_projectile.tscn")
var _coin_scene: PackedScene = preload("res://scenes/entities/coin.tscn")

# Tower creation — 注入 TowerData Resource
func create_tower(type: String) -> Node2D:
	if not _tower_scenes.has(type):
		push_error("Unknown tower type: " + type)
		return null

	var tower = _tower_scenes[type].instantiate()
	tower.tower_type = type
	# 注入 Resource 数据
	if GameConfig.towers.has(type):
		tower.data = GameConfig.towers[type]
	return tower

func get_tower_cost(type: String) -> int:
	if not GameConfig.towers.has(type):
		push_error("Unknown tower type: " + type)
		return 0

	var td: TowerData = GameConfig.towers[type]
	var level: int = GameData.owned_towers.get(type, 1)
	return td.place_cost_per_level[level - 1]

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

# BulletProjectile creation — 新投射物系统
func create_bullet_projectile() -> BulletProjectile:
	return _bullet_projectile_scene.instantiate()

# BoomerangProjectile creation — 新投射物系统
func create_boomerang_projectile() -> BoomerangProjectile:
	return _boomerang_projectile_scene.instantiate()

# LaserProjectile creation — 新投射物系统
func create_laser_projectile() -> LaserProjectile:
	return _laser_projectile_scene.instantiate()
