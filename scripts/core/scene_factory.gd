extends Node

# Scene preloads - centralized
var _tower_scenes: Dictionary = {
	Enums.TowerId.PEA_SHOOTER: preload("res://scenes/entities/towers/tower_pea_shooter.tscn"),
	Enums.TowerId.STUMP: preload("res://scenes/entities/towers/tower_stump.tscn"),
	Enums.TowerId.ICE_FLOWER: preload("res://scenes/entities/towers/tower_ice_flower.tscn"),
	Enums.TowerId.CACTUS: preload("res://scenes/entities/towers/tower_cactus.tscn"),
	Enums.TowerId.ROSE: preload("res://scenes/entities/towers/tower_rose.tscn"),
	Enums.TowerId.MUSHROOM: preload("res://scenes/entities/towers/tower_mushroom.tscn"),
	Enums.TowerId.VINE: preload("res://scenes/entities/towers/tower_vine.tscn"),
	Enums.TowerId.DANDELION: preload("res://scenes/entities/towers/tower_dandelion.tscn"),
	Enums.TowerId.PITCHER: preload("res://scenes/entities/towers/tower_pitcher.tscn"),
	Enums.TowerId.THORN: preload("res://scenes/entities/towers/tower_thorn.tscn"),
	Enums.TowerId.OAK: preload("res://scenes/entities/towers/tower_oak.tscn"),
	Enums.TowerId.SUNFLOWER: preload("res://scenes/entities/towers/tower_sunflower.tscn"),
	Enums.TowerId.MINT: preload("res://scenes/entities/towers/tower_mint.tscn"),
	Enums.TowerId.HEAL_FLOWER: preload("res://scenes/entities/towers/tower_heal_flower.tscn"),
	Enums.TowerId.BAMBOO: preload("res://scenes/entities/towers/tower_bamboo.tscn"),
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
var _boomerang_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/boomerang_projectile.tscn")
var _laser_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/laser_projectile.tscn")
var _rocket_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/rocket_projectile.tscn")
var _chain_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/chain_projectile.tscn")
var _melee_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/melee_projectile.tscn")
var _flame_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/flame_projectile.tscn")
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

func get_tower_cost(_type: String) -> int:
	# 布置免费，place_cost 已移除
	return 0

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

# RocketProjectile creation
func create_rocket_projectile() -> RocketProjectile:
	return _rocket_projectile_scene.instantiate()

# ChainProjectile creation
func create_chain_projectile() -> ChainProjectile:
	return _chain_projectile_scene.instantiate()

# MeleeProjectile creation
func create_melee_projectile() -> MeleeProjectile:
	return _melee_projectile_scene.instantiate()

# FlameProjectile creation
func create_flame_projectile() -> FlameProjectile:
	return _flame_projectile_scene.instantiate()
