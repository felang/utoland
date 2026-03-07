# LaserProjectile — 瞬发贯穿激光投射物
# setup() 时拉伸 Hitbox 覆盖激光路径，存活 beam_duration 秒后销毁
class_name LaserProjectile
extends Projectile

var beam_duration: float = 0.08
var beam_range: float = 400.0
var _elapsed: float = 0.0
var _line: Line2D = null

@onready var _hitbox_shape: CollisionShape2D = $Hitbox/HitboxShape

func _on_setup(direction: Vector2) -> void:
	_elapsed = 0.0
	# 动态获取作为备选，防止 @onready 时序问题
	var shape_node: CollisionShape2D = _hitbox_shape if _hitbox_shape else get_node("Hitbox/HitboxShape")
	# 拉伸 Hitbox 覆盖激光路径
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(beam_range, 8.0)
	shape_node.shape = rect
	shape_node.position = direction * beam_range * 0.5
	shape_node.rotation = direction.angle()
	# 视觉 Line2D
	_line = Line2D.new()
	_line.width = 3.0
	_line.default_color = Color(1, 0.2, 0.2, 0.9)
	_line.add_point(Vector2.ZERO)
	_line.add_point(direction * beam_range)
	add_child(_line)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= beam_duration:
		queue_free()
