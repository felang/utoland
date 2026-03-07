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
	var fx: EffectConfigData = GameConfig.effects
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(beam_range, fx.laser_beam_hitbox_height)
	shape_node.shape = rect
	# position 在 Hitbox(Area2D) 局部空间中设置：将碰撞框中心移至激光路径中点
	# rotation 使 RectangleShape2D 沿发射方向旋转，覆盖完整光束路径
	shape_node.position = direction * beam_range * 0.5
	shape_node.rotation = direction.angle()
	# 视觉 Line2D
	_line = Line2D.new()
	_line.width = fx.laser_beam_width
	_line.default_color = fx.laser_beam_color
	_line.add_point(Vector2.ZERO)
	_line.add_point(direction * beam_range)
	add_child(_line)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= beam_duration:
		queue_free()
