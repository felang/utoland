# BulletProjectile — 直线飞行投射物
# 通过 Hitbox 碰到 enemy_hurtbox 触发伤害，碰后 queue_free
class_name BulletProjectile
extends Projectile

var speed: float = 600.0
var lifetime: float = 5.0
var _elapsed: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []

func _on_setup(direction: Vector2) -> void:
	_direction = direction
	_elapsed = 0.0
	var fx: EffectConfigData = GameConfig.effects
	_trail = Line2D.new()
	_trail.width = fx.bullet_trail_width
	_trail.default_color = fx.bullet_trail_color
	_trail.z_index = -1
	_trail.top_level = true
	add_child(_trail)
	hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	_elapsed += delta
	_update_trail()
	if _elapsed >= lifetime:
		queue_free()

func _update_trail() -> void:
	if _trail == null:
		return
	_trail_positions.insert(0, global_position)
	var max_pts: int = GameConfig.effects.bullet_trail_max_points
	if _trail_positions.size() > max_pts:
		_trail_positions.resize(max_pts)
	_trail.clear_points()
	for pos in _trail_positions:
		_trail.add_point(pos)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		EffectsManager.spawn_hit_sparks(global_position)
		queue_free()
