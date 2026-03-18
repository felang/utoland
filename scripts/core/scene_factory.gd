extends Node

# 分层容器引用（由 main.gd 在 _ready() 中注入）
var _entity_layer: Node2D
var _projectile_layer: Node2D
var _pickup_layer: Node2D

func init_containers(entity_layer: Node2D, projectile_layer: Node2D, pickup_layer: Node2D) -> void:
	_entity_layer = entity_layer
	_projectile_layer = projectile_layer
	_pickup_layer = pickup_layer

func get_entity_layer() -> Node:
	if _entity_layer:
		return _entity_layer
	# 测试环境未初始化容器时，回退到场景树根节点
	if get_tree():
		if get_tree().current_scene:
			return get_tree().current_scene
		return get_tree().root
	return null

func get_projectile_layer() -> Node:
	if _projectile_layer:
		return _projectile_layer
	if get_tree():
		if get_tree().current_scene:
			return get_tree().current_scene
		return get_tree().root
	return null

func get_pickup_layer() -> Node:
	if _pickup_layer:
		return _pickup_layer
	if get_tree():
		if get_tree().current_scene:
			return get_tree().current_scene
		return get_tree().root
	return null

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

func _ready() -> void:
	_register_pool("coin", _coin_scene)
	_register_pool("exp_orb", _exp_orb_scene)
	for enemy_type in [Enums.Enemy.NORMAL, Enums.Enemy.FAST, Enums.Enemy.TANK]:
		_register_pool("enemy_" + enemy_type, _enemy_scenes[enemy_type])

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

# Enemy creation — 注入 EnemyData Resource，poolable 类型走对象池
func create_enemy(type: String) -> CharacterBody2D:
	if not _enemy_scenes.has(type):
		push_error("Unknown enemy type: " + type)
		return null

	var key: String = "enemy_" + type
	var enemy: CharacterBody2D
	if _pools.has(key):
		enemy = _pool_acquire(key) as CharacterBody2D
	else:
		enemy = _enemy_scenes[type].instantiate()

	enemy.enemy_type = type
	if GameConfig.enemies.has(type):
		enemy.data = GameConfig.enemies[type]
	# 对象池复用时重新初始化数值（@onready 节点已存在）
	# 新实例在 _ready() 中初始化，此处跳过以避免 @onready 未就绪
	if _pools.has(key) and enemy.health != null and enemy.data:
		enemy.health.initialize(enemy.data.hp)
		enemy.speed = enemy.data.speed
		enemy._hitbox.damage = enemy.data.damage
		enemy.slow_handler.initialize(enemy.data.speed)
	# 重新获取 player 引用（仅复用时需要，新实例在 _ready 中获取）
	if enemy.health != null:
		enemy.player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	return enemy

func release_enemy(enemy: CharacterBody2D) -> void:
	var key: String = "enemy_" + str(enemy.get("enemy_type"))
	# 使用延迟回收，避免在物理回调中直接操作场景树
	_deferred_pool_release.call_deferred(key, enemy)

# Coin creation
func create_coin() -> Area2D:
	if not _pools.has("coin"):
		_register_pool("coin", _coin_scene)
	return _pool_acquire("coin") as Area2D

func release_coin(coin: Area2D) -> void:
	_pool_release("coin", coin)

# 经验球创建
func create_exp_orb() -> Area2D:
	if not _pools.has("exp_orb"):
		_register_pool("exp_orb", _exp_orb_scene)
	return _pool_acquire("exp_orb") as Area2D

func release_exp_orb(orb: Area2D) -> void:
	_pool_release("exp_orb", orb)

# 统一投射物创建 — 从对象池获取并初始化
func create_projectile(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2) -> Node2D:
	assert(p_data != null, "SceneFactory.create_projectile: data 不能为 null")
	assert(p_data.projectile_scene != null, "SceneFactory.create_projectile: projectile_scene 未配置")
	var key: String = _get_projectile_pool_key(p_data)
	if not _pools.has(key):
		_register_pool(key, p_data.projectile_scene)
	var proj: Node2D = _pool_acquire(key) as Node2D
	proj.setup(p_data, damage, from, direction)
	return proj

func release_projectile(proj: Node2D) -> void:
	if proj.data and proj.data.projectile_scene:
		var key: String = _get_projectile_pool_key(proj.data)
		if _pools.has(key):
			_deferred_pool_release.call_deferred(key, proj)
		else:
			proj.queue_free()
	else:
		proj.queue_free()

func _deferred_pool_release(key: String, obj) -> void:
	if not is_instance_valid(obj):
		return
	_pool_release(key, obj as Node)

func _get_projectile_pool_key(p_data: ProjectileData) -> String:
	return "projectile_" + p_data.projectile_scene.resource_path.get_file().get_basename()

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
	# 从队列中弹出有效节点，跳过已被外部释放的节点
	while entry.idle_queue.size() > 0:
		var candidate = entry.idle_queue.pop_back()  # 不使用类型，避免对已释放节点的赋值报错
		if is_instance_valid(candidate):
			obj = candidate as Node
			break
	if obj == null:
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

func warmup_initial() -> void:
	# 投射物预热：遍历所有武器的 projectile_data
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if wd.projectile_data and wd.projectile_data.projectile_scene:
			var key: String = _get_projectile_pool_key(wd.projectile_data)
			if not _pools.has(key):
				_register_pool(key, wd.projectile_data.projectile_scene)
			_pool_warmup(key, 20)
	# 敌人预热
	if _pools.has("enemy_normal"):
		_pool_warmup("enemy_normal", 10)
	if _pools.has("enemy_fast"):
		_pool_warmup("enemy_fast", 5)
	if _pools.has("enemy_tank"):
		_pool_warmup("enemy_tank", 3)
	# 掉落物预热
	if _pools.has("coin"):
		_pool_warmup("coin", 15)
	if _pools.has("exp_orb"):
		_pool_warmup("exp_orb", 15)

func warmup_for_wave(wave_data: WaveData) -> void:
	var max_enemies: int = wave_data.max_alive_enemies
	# 按 enemy_weights 比例补充敌人
	var total_weight: float = 0.0
	for w in wave_data.enemy_weights.values():
		total_weight += w
	if total_weight > 0:
		for enemy_type in wave_data.enemy_weights:
			var key: String = "enemy_" + enemy_type
			if not _pools.has(key):
				continue
			var ratio: float = wave_data.enemy_weights[enemy_type] / total_weight
			var target: int = int(ceil(max_enemies * ratio))
			var current: int = _pools[key].idle_queue.size()
			if target > current:
				_pool_warmup(key, target - current)
	# 投射物补充
	for proj_key in _pools:
		if proj_key.begins_with("projectile_"):
			var target: int = max_enemies * 2
			var current: int = _pools[proj_key].idle_queue.size()
			if target > current:
				_pool_warmup(proj_key, target - current)
	# 掉落物补充
	for drop_key in ["coin", "exp_orb"]:
		if _pools.has(drop_key):
			var target: int = max_enemies
			var current: int = _pools[drop_key].idle_queue.size()
			if target > current:
				_pool_warmup(drop_key, target - current)
