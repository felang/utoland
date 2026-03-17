extends Node

class PoolEntry:
	var scene: PackedScene
	var idle_queue: Array[Node] = []
	var active_count: int = 0
	var warmup_count: int = 0

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

var _coin_scene: PackedScene = preload("res://scenes/entities/coin.tscn")
var _exp_orb_scene: PackedScene = preload("res://scenes/entities/exp_orb.tscn")

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

# 经验球创建
func create_exp_orb() -> Area2D:
	return _exp_orb_scene.instantiate()

# 统一投射物创建 — 从 ProjectileData 实例化
func create_projectile(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, extra_pierce: int = 0) -> ProjectileBase:
	assert(p_data != null, "SceneFactory.create_projectile: data 不能为 null")
	assert(p_data.projectile_scene != null, "SceneFactory.create_projectile: projectile_scene 未配置")
	var proj: ProjectileBase = p_data.projectile_scene.instantiate()
	proj.setup(p_data, damage, from, direction, extra_pierce)
	return proj

# ---- 对象池核心 ----
var _pools: Dictionary = {}

func _register_pool(key: String, scene: PackedScene, warmup: int = 0) -> void:
	var entry := PoolEntry.new()
	entry.scene = scene
	entry.warmup_count = warmup
	_pools[key] = entry

func _pool_acquire(key: String) -> Node:
	var entry: PoolEntry = _pools[key]
	var obj: Node
	if entry.idle_queue.size() > 0:
		obj = entry.idle_queue.pop_back()
	else:
		obj = entry.scene.instantiate()
	obj.set("_is_pooled", false)
	obj.set_process(true)
	obj.set_physics_process(true)
	entry.active_count += 1
	return obj

func _pool_release(key: String, obj: Node) -> void:
	if not _pools.has(key):
		obj.queue_free()
		return
	if obj.get("_is_pooled") == true:
		return
	obj.reset_for_pool()
	obj.set("_is_pooled", true)
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	obj.set_process(false)
	obj.set_physics_process(false)
	_pools[key].idle_queue.push_back(obj)
	_pools[key].active_count -= 1

func _pool_warmup(key: String, count: int) -> void:
	var entry: PoolEntry = _pools[key]
	for i in count:
		var obj: Node = entry.scene.instantiate()
		obj.set("_is_pooled", true)
		obj.set_process(false)
		obj.set_physics_process(false)
		entry.idle_queue.push_back(obj)

func clear_all_pools() -> void:
	for key in _pools:
		var entry: PoolEntry = _pools[key]
		for obj in entry.idle_queue:
			if is_instance_valid(obj):
				obj.queue_free()
		entry.idle_queue.clear()
		entry.active_count = 0
	_pools.clear()
