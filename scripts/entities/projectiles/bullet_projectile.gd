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
var _trail_max_points: int = 4
## 穿甲弹：当前已穿透的敌人数
var _hit_count: int = 0

func _on_setup(direction: Vector2) -> void:
	_direction = direction
	_elapsed = 0.0
	var fx: EffectConfigData = GameConfig.effects
	_trail_max_points = fx.bullet_trail_max_points
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
		_cleanup_and_free()

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

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		EffectsManager.spawn_hit_sparks(global_position)
		# 吸血：对敌人造成伤害后回复玩家HP
		if GameData.lifesteal_ratio > 0.0:
			var player_node: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
			if player_node and player_node.has_method("heal_hp"):
				player_node.heal_hp(hitbox.damage * GameData.lifesteal_ratio)
		# 穿甲弹：记录穿透次数，未超出时不销毁
		_hit_count += 1
		if _hit_count > GameData.pierce_count:
			_cleanup_and_free()
