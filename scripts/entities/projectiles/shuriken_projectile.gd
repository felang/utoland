# ShurikenProjectile — 手里剑投射物（二段弹跳）
class_name ShurikenProjectile
extends ProjectileBase

@export var bounce_range: float = 150.0
@export var outbound_distance: float = 100.0
@export var return_speed_mult: float = 1.3

var _rotation_speed: float = 0.0
var _bounce_target: Node2D = null
var _hit_enemies: Array[Node2D] = []
var _shuriken_hit_count: int = 0

func setup(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, extra_pierce: int = 0) -> void:
	super.setup(p_data, damage, from, direction, extra_pierce)
	_shuriken_hit_count = 0
	_bounce_target = null
	_hit_enemies = []
	# 手里剑特效配置
	var fx: EffectConfigData = GameConfig.effects
	_rotation_speed = deg_to_rad(fx.shuriken_rotation_speed)
	# 覆盖拖尾为手里剑专用
	if _trail:
		_trail.width = fx.shuriken_trail_width
		_trail.default_color = fx.shuriken_trail_color
		_trail_max_points = fx.shuriken_trail_points
	# 断开基类碰撞信号，用自己的
	if hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.disconnect(_on_hitbox_area_entered)
	hitbox.area_entered.connect(_on_shuriken_hit)

func set_player(_player_node: Node2D) -> void:
	pass  # 保留接口兼容

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		_cleanup_and_free()
		return
	rotation += _rotation_speed * delta
	_update_trail()
	if _bounce_target and is_instance_valid(_bounce_target):
		_direction = global_position.direction_to(_bounce_target.global_position)
	global_position += _direction * _speed * delta

func _on_shuriken_hit(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	var enemy: Node2D = area.get_parent()
	if enemy in _hit_enemies:
		return
	_hit_enemies.append(enemy)
	_shuriken_hit_count += 1
	EffectsManager.spawn_hit_sparks(global_position)
	hit.emit(global_position, _direction)
	if _shuriken_hit_count == 1:
		_bounce_target = _find_bounce_target(enemy)
		if _bounce_target == null:
			_cleanup_and_free()
	elif _shuriken_hit_count >= 2:
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
