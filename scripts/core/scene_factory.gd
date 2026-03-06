extends Node

# Scene preloads - centralized
var _tower_scenes: Dictionary = {
	"shooter": preload("res://scenes/towers/tower_shooter.tscn"),
	"wall": preload("res://scenes/towers/tower_wall.tscn"),
	"slow": preload("res://scenes/towers/tower_slow.tscn")
}

var _enemy_scenes: Dictionary = {
	"normal": preload("res://scenes/enemies/enemy_normal.tscn"),
	"fast": preload("res://scenes/enemies/enemy_fast.tscn"),
	"tank": preload("res://scenes/enemies/enemy_tank.tscn")
}

var _bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var _coin_scene: PackedScene = preload("res://scenes/coin.tscn")
var _boomerang_scene: PackedScene = preload("res://scenes/boomerang.tscn")
var _laser_beam_scene: PackedScene = preload("res://scenes/laser_beam.tscn")

# Tower creation
func create_tower(type: String) -> Node2D:
	if not _tower_scenes.has(type):
		push_error("Unknown tower type: " + type)
		return null

	var tower = _tower_scenes[type].instantiate()
	tower.tower_type = type
	# Config is applied in tower._ready()
	return tower

func get_tower_cost(type: String) -> int:
	if not GameConfig.TOWERS.has(type):
		push_error("Unknown tower type: " + type)
		return 0

	var config = GameConfig.TOWERS[type]
	# Use average of min/max for consistent pricing
	return (config["shop_price_min"] + config["shop_price_max"]) / 2

# Enemy creation
func create_enemy(type: String) -> CharacterBody2D:
	if not _enemy_scenes.has(type):
		push_error("Unknown enemy type: " + type)
		return null

	var enemy = _enemy_scenes[type].instantiate()
	enemy.enemy_type = type
	# Config is applied in enemy._ready()

	return enemy

# Bullet creation
func create_bullet() -> Area2D:
	return _bullet_scene.instantiate()

# Coin creation
func create_coin() -> Area2D:
	return _coin_scene.instantiate()

# Boomerang creation
func create_boomerang() -> Area2D:
	return _boomerang_scene.instantiate()

# Laser beam creation
func create_laser_beam() -> Node2D:
	return _laser_beam_scene.instantiate()
