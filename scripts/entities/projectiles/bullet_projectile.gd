# BulletProjectile — 直线飞行投射物
# 通过 Hitbox 碰到 enemy_hurtbox 触发伤害，碰后 queue_free
class_name BulletProjectile
extends Projectile

const SPLIT_SPEED_MULT: float = 0.8           # 分裂弹速度倍率
const SPLIT_LIFETIME: float = 1.5             # 分裂弹存活时间（秒）
const SPLIT_KNOCKBACK_MULT: float = 0.5       # 分裂弹击退倍率
const SPLIT_SPREAD_ANGLE: float = PI / 2      # 分裂弹扩散角度（弧度，±90°）

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

func _spawn_split_bullets() -> void:
	var scene_parent: Node = get_parent()
	if not scene_parent:
		return
	var split_damage: float = hitbox.damage * GameData.split_damage_mult
	for i in GameData.split_count:
		var angle: float = randf_range(-SPLIT_SPREAD_ANGLE, SPLIT_SPREAD_ANGLE)
		var split_dir: Vector2 = _direction.rotated(angle)
		var split_bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
		split_bullet.speed = speed * SPLIT_SPEED_MULT
		split_bullet.lifetime = SPLIT_LIFETIME
		split_bullet.set_meta("is_split", true)
		scene_parent.add_child(split_bullet)
		split_bullet.setup(split_damage, hitbox.knockback_force * SPLIT_KNOCKBACK_MULT, global_position, split_dir)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		EffectsManager.spawn_hit_sparks(global_position)
		# 弹道分裂：命中后生成小弹（仅主弹分裂，防止无限递归）
		if GameData.split_count > 0 and not get_meta("is_split", false):
			_spawn_split_bullets()
		# 穿甲弹：记录穿透次数，未超出时不销毁
		_hit_count += 1
		if _hit_count > GameData.pierce_count:
			_cleanup_and_free()
