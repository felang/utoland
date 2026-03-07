extends Area2D

var speed: float = 600.0
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var lifetime: float = 5.0
var elapsed: float = 0.0

var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []
var _trail_max_points: int = 4

func _ready():
	# 从配置读取拖尾最大点数
	if GameConfig.effects:
		_trail_max_points = GameConfig.effects.bullet_trail_max_points
	body_entered.connect(_on_body_entered)
	# 创建拖尾 Line2D
	var config: Dictionary = GameConfig.EFFECTS["bullet_trail"]
	_trail = Line2D.new()
	_trail.width = config["width"]
	_trail.default_color = config["color"]
	_trail.z_index = -1
	_trail.top_level = true
	add_child(_trail)

func _physics_process(delta):
	global_position += direction * speed * delta
	elapsed += delta
	_update_trail()
	if elapsed >= lifetime:
		queue_free()

func _update_trail() -> void:
	_trail_positions.insert(0, global_position)
	if _trail_positions.size() > _trail_max_points:
		_trail_positions.resize(_trail_max_points)
	_trail.clear_points()
	for pos in _trail_positions:
		_trail.add_point(pos)

func _on_body_entered(body):
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction)
		EffectsManager.spawn_hit_sparks(global_position)
		queue_free()
