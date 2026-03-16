# ShurikenProjectile — 手里剑投射物
# 直线飞行 → 命中敌人 → 弹射到附近另一个敌人 → 消失
class_name ShurikenProjectile
extends Projectile

var weapon_data: WeaponData = null

var speed: float = 175.0
var max_lifetime: float = 5.0
var bounce_range: float = 150.0  # 弹射搜索范围

var _elapsed: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []
var _trail_max_points: int = 8
var _rotation_speed: float = 0.0
var _hit_count: int = 0  # 0=未命中, 1=命中第一个, 2=弹射命中
var _bounce_target: Node2D = null  # 弹射目标
var _hit_enemies: Array[Node2D] = []  # 已命中的敌人（避免重复）

func _on_setup(direction: Vector2) -> void:
	_direction = direction
	_elapsed = 0.0
	_hit_count = 0
	_bounce_target = null
	_hit_enemies = []
	assert(weapon_data != null, "ShurikenProjectile: weapon_data 未注入")
	speed = weapon_data.shuriken_speed
	max_lifetime = weapon_data.shuriken_max_lifetime
	# 特效配置
	var fx: EffectConfigData = GameConfig.effects
	_trail_max_points = fx.shuriken_trail_points
	_rotation_speed = deg_to_rad(fx.shuriken_rotation_speed)
	# 拖尾
	_trail = Line2D.new()
	_trail.width = fx.shuriken_trail_width
	_trail.default_color = fx.shuriken_trail_color
	_trail.top_level = true
	_trail.z_index = -1
	add_child(_trail)
	# 连接碰撞检测
	hitbox.area_entered.connect(_on_hitbox_area_entered)

func set_player(_player_node: Node2D) -> void:
	pass  # 保留接口兼容，不再需要 player 引用

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= max_lifetime:
		_cleanup_and_free()
		return
	# 旋转
	rotation += _rotation_speed * delta
	_update_trail()
	# 弹射追踪
	if _bounce_target and is_instance_valid(_bounce_target):
		_direction = global_position.direction_to(_bounce_target.global_position)
	global_position += _direction * speed * delta

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	var enemy: Node2D = area.get_parent()
	if enemy in _hit_enemies:
		return  # 已命中过，跳过
	_hit_enemies.append(enemy)
	_hit_count += 1
	EffectsManager.spawn_hit_sparks(global_position)
	if _hit_count == 1:
		# 第一次命中：寻找弹射目标
		_bounce_target = _find_bounce_target(enemy)
		if _bounce_target == null:
			# 没有弹射目标，直接消失
			_cleanup_and_free()
	elif _hit_count >= 2:
		# 弹射命中，消失
		_cleanup_and_free()

func _find_bounce_target(exclude: Node2D) -> Node2D:
	if not is_inside_tree():
		return null
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var closest: Node2D = null
	var min_dist: float = bounce_range
	for enemy in enemies:
		if enemy == exclude:
			continue
		if enemy is Node2D:
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest

func _update_trail() -> void:
	if _trail == null:
		return
	_trail_positions.insert(0, global_position)
	if _trail_positions.size() > _trail_max_points:
		_trail_positions.resize(_trail_max_points)
	_trail.clear_points()
	for pos in _trail_positions:
		_trail.add_point(pos)

func _cleanup_and_free() -> void:
	if _trail and is_instance_valid(_trail):
		_trail.queue_free()
	queue_free()
