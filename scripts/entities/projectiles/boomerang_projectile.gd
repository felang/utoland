# BoomerangProjectile — 去程穿透 + 回程追踪玩家的投射物
# 去程直线飞行到 outbound_distance，回程追踪 _player 当前位置
class_name BoomerangProjectile
extends Projectile

var speed: float = 175.0
var outbound_distance: float = 100.0
var return_speed_mult: float = 1.3
var max_lifetime: float = 5.0  # 默认值，_on_setup 中从配置覆盖

var _state: Enums.BoomerangState = Enums.BoomerangState.OUTBOUND
var _traveled: float = 0.0
var _elapsed: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _player: Node2D = null
var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []
var _trail_max_points: int = 8
var _rotation_speed: float = 0.0          # 出程旋转速度
var _return_rotation_speed: float = 0.0   # 回程旋转速度（更快）
var _return_dist_threshold: float = 30.0

func _on_setup(direction: Vector2) -> void:
	_direction = direction
	_state = Enums.BoomerangState.OUTBOUND
	_traveled = 0.0
	_elapsed = 0.0
	assert(GameConfig.weapons.has(Enums.WeaponId.BOOMERANG), "缺少 boomerang 武器配置，请检查 resources/weapons/")
	# 从 WeaponData 读取回旋镖配置
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.BOOMERANG]
	speed = w.boomerang_speed
	outbound_distance = w.outbound_distance
	return_speed_mult = w.return_speed_mult
	max_lifetime = w.boomerang_max_lifetime
	# 特效配置缓存
	var fx: EffectConfigData = GameConfig.effects
	_trail_max_points = fx.boomerang_trail_points
	_rotation_speed = deg_to_rad(fx.boomerang_rotation_speed)
	_return_rotation_speed = _rotation_speed * fx.boomerang_return_rotation_mult
	_return_dist_threshold = fx.boomerang_return_distance
	# 创建拖尾
	_trail = Line2D.new()
	_trail.width = fx.boomerang_trail_width
	_trail.default_color = fx.boomerang_trail_color
	_trail.top_level = true
	_trail.z_index = -1
	add_child(_trail)

func set_player(player_node: Node2D) -> void:
	_player = player_node

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= max_lifetime:
		_cleanup_and_free()
		return
	var rot_speed: float = _return_rotation_speed if _state == Enums.BoomerangState.RETURNING else _rotation_speed
	rotation += rot_speed * delta
	_update_trail()
	match _state:
		Enums.BoomerangState.OUTBOUND:  _process_outbound(delta)
		Enums.BoomerangState.RETURNING: _process_returning(delta)

func _process_outbound(delta: float) -> void:
	var dist: float = speed * delta
	global_position += _direction * dist
	_traveled += dist
	if _traveled >= outbound_distance:
		_state = Enums.BoomerangState.RETURNING

func _process_returning(delta: float) -> void:
	if not is_instance_valid(_player):
		_cleanup_and_free()
		return
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length() < _return_dist_threshold:
		_cleanup_and_free()
		return
	global_position += to_player.normalized() * speed * return_speed_mult * delta

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
