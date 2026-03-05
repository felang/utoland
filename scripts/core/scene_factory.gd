extends Node
class_name SceneFactory

# Scene preloads - centralized
static var _tower_scenes = {
	"shooter": preload("res://scenes/towers/tower_shooter.tscn"),
	"wall": preload("res://scenes/towers/tower_wall.tscn"),
	"slow": preload("res://scenes/towers/tower_slow.tscn")
}

static var _enemy_scenes = {
	"normal": preload("res://scenes/enemies/enemy_normal.tscn"),
	"fast": preload("res://scenes/enemies/enemy_fast.tscn"),
	"tank": preload("res://scenes/enemies/enemy_tank.tscn")
}

static var _bullet_scene = preload("res://scenes/bullet.tscn")
static var _coin_scene = preload("res://scenes/coin.tscn")

# Tower creation
static func create_tower(type: String) -> Node2D:
	if not _tower_scenes.has(type):
		push_error("Unknown tower type: " + type)
		return null

	var tower = _tower_scenes[type].instantiate()
	var config = GameConfig.TOWERS[type]

	# Apply config
	tower.tower_type = type
	tower.max_hp = config["hp"]

	# Type-specific config
	if type == "shooter":
		tower.damage = config["damage"]
		tower.fire_rate = config["fire_rate"]
		tower.range = config["range"]
	elif type == "slow":
		tower.range = config["range"]
		tower.slow_percent = config["slow_percent"]

	return tower

static func get_tower_cost(type: String) -> int:
	if not GameConfig.TOWERS.has(type):
		push_error("Unknown tower type: " + type)
		return 0

	var config = GameConfig.TOWERS[type]
	return randi_range(config["shop_price_min"], config["shop_price_max"])

# Enemy creation
static func create_enemy(type: String) -> CharacterBody2D:
	if not _enemy_scenes.has(type):
		push_error("Unknown enemy type: " + type)
		return null

	var enemy = _enemy_scenes[type].instantiate()
	enemy.enemy_type = type
	# Config is applied in enemy._ready()

	return enemy

# Bullet creation
static func create_bullet() -> Area2D:
	return _bullet_scene.instantiate()

# Coin creation
static func create_coin() -> Area2D:
	return _coin_scene.instantiate()
