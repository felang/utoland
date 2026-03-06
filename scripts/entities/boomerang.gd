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

func _ready() -> void:
	var config: Dictionary = GameConfig.WEAPONS["boomerang"]
	speed = config["speed"]
	outbound_distance = config["outbound_distance"]
	return_speed_mult = config["return_speed_mult"]
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()
		return
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
	match _state:
		"OUTBOUND":
			if body not in _hit_outbound:
				_hit_outbound.append(body)
				body.take_damage(damage)
		"RETURNING":
			if body not in _hit_returning:
				_hit_returning.append(body)
				body.take_damage(damage)
