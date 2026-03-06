extends Area2D

# 回旋镖弹道 — 去程穿透 + 回程追踪玩家
# 配置从 GameConfig.WEAPONS["boomerang"] 读取

var speed: float = 350.0
var direction: Vector2 = Vector2.RIGHT
var damage: float = 0.0  # 由 player 射击时设置
var outbound_distance: float = 200.0
var return_speed_mult: float = 1.3
var max_lifetime: float = 5.0
var player: Node2D = null  # 回程追踪目标

var _state: String = "OUTBOUND"
var _traveled: float = 0.0
var _elapsed: float = 0.0
var _hit_outbound: Array = []
var _hit_returning: Array = []
var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []

func _ready() -> void:
	var config: Dictionary = GameConfig.WEAPONS["boomerang"]
	speed = config["speed"]
	outbound_distance = config["outbound_distance"]
	return_speed_mult = config["return_speed_mult"]
	body_entered.connect(_on_body_entered)
	# 创建拖尾
	var fx_config: Dictionary = GameConfig.EFFECTS["boomerang"]
	_trail = Line2D.new()
	_trail.width = fx_config["trail_width"]
	_trail.default_color = fx_config["trail_color"]
	_trail.top_level = true
	_trail.z_index = -1
	add_child(_trail)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()
		return
	# 旋转
	var fx_config: Dictionary = GameConfig.EFFECTS["boomerang"]
	var rot_speed: float = deg_to_rad(fx_config["rotation_speed"])
	if _state == "RETURNING":
		rot_speed *= fx_config["return_rotation_mult"]
	rotation += rot_speed * delta
	# 拖尾更新
	_trail_positions.insert(0, global_position)
	if _trail_positions.size() > fx_config["trail_points"]:
		_trail_positions.resize(fx_config["trail_points"])
	_trail.clear_points()
	for pos in _trail_positions:
		_trail.add_point(pos)
	match _state:
		"OUTBOUND":
			_process_outbound(delta)
		"RETURNING":
			_process_returning(delta)

func _process_outbound(delta: float) -> void:
	var move_distance: float = speed * delta
	global_position += direction * move_distance
	_traveled += move_distance
	if _traveled >= outbound_distance:
		_state = "RETURNING"

func _process_returning(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	var return_speed: float = speed * return_speed_mult
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	if distance < 15.0:
		queue_free()
		return
	var move_dir: Vector2 = to_player.normalized()
	global_position += move_dir * return_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return
	var knockback_dir: Vector2 = global_position.direction_to(body.global_position)
	match _state:
		"OUTBOUND":
			if body not in _hit_outbound:
				_hit_outbound.append(body)
				body.take_damage(damage)
				if body.has_method("apply_knockback"):
					body.apply_knockback(knockback_dir)
		"RETURNING":
			if body not in _hit_returning:
				_hit_returning.append(body)
				body.take_damage(damage)
				if body.has_method("apply_knockback"):
					body.apply_knockback(knockback_dir)
