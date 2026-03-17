# ProjectileBase — 统一投射物基类
# 直线飞行 + 数据驱动的命中效果（slow/pierce/knockback）
class_name ProjectileBase
extends Node2D

signal hit(position: Vector2, direction: Vector2)

var hitbox: Hitbox = null

var data: ProjectileData = null
var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _lifetime: float = 5.0
var _elapsed: float = 0.0
var _pierce_count: int = 0
var _hit_count: int = 0
var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []
var _trail_max_points: int = 4
var show_trail: bool = true
var _is_pooled: bool = false
var _pending_release: bool = false

## [过渡兼容] 旧代码直接设置 speed/slow_on_hit/slow_duration，后续 Task 11-18 删除
var speed: float = 800.0:
	set(v): _speed = v
	get: return _speed
var slow_on_hit: float = 0.0
var slow_duration: float = 0.0
var lifetime: float = 5.0:
	set(v): _lifetime = v
	get: return _lifetime

## [过渡兼容] 旧 setup 签名：setup(damage, knockback, from, direction)，后续删除
func setup_legacy(damage: float, knockback_force: float, from: Vector2, direction: Vector2) -> void:
	global_position = from
	_direction = direction
	_elapsed = 0.0
	_hit_count = 0
	hitbox = get_node_or_null("Hitbox") as Hitbox
	assert(hitbox != null, "ProjectileBase.setup_legacy: 缺少 Hitbox 子节点")
	hitbox.damage = damage
	hitbox.knockback_force = knockback_force
	if show_trail:
		var fx: EffectConfigData = GameConfig.effects
		_trail_max_points = fx.bullet_trail_max_points
		_trail = Line2D.new()
		_trail.width = fx.bullet_trail_width
		_trail.default_color = fx.bullet_trail_color
		_trail.z_index = -1
		_trail.top_level = true
		add_child(_trail)
	hitbox.area_entered.connect(_on_legacy_hitbox_area_entered)

func _on_legacy_hitbox_area_entered(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	EffectsManager.spawn_hit_sparks(global_position)
	# 减速效果（旧模式通过 slow_on_hit 属性）
	if slow_on_hit > 0.0:
		var enemy: Node2D = area.get_parent() as Node2D
		if enemy and enemy.has_node("SlowHandler"):
			var source_id: String = "projectile_" + str(get_instance_id())
			enemy.slow_handler.apply_timed_slow(slow_on_hit, slow_duration, source_id)
	_hit_count += 1
	if _hit_count > _pierce_count:
		_cleanup_and_free()

func setup(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, extra_pierce: int = 0) -> void:
	data = p_data
	global_position = from
	_direction = direction
	_speed = data.speed
	_lifetime = data.lifetime
	_pierce_count = data.base_pierce_count + extra_pierce
	_hit_count = 0
	_elapsed = 0.0
	hitbox = get_node_or_null("Hitbox") as Hitbox
	assert(hitbox != null, "ProjectileBase.setup: 缺少 Hitbox 子节点")
	hitbox.damage = damage
	hitbox.knockback_force = data.knockback_force
	# 精灵：先清理旧的，再按需创建
	_cleanup_dynamic_sprite()
	if data.sprite_path != "" and ResourceLoader.exists(data.sprite_path):
		var sprite := Sprite2D.new()
		sprite.name = "_PooledSprite"
		sprite.texture = load(data.sprite_path)
		sprite.rotation = direction.angle()
		add_child(sprite)
	# 拖尾：先清理旧的，再按需创建
	_cleanup_trail()
	_trail_positions.clear()
	show_trail = data.trail_enabled
	if show_trail:
		_create_trail()
	# 信号：先断开再连接，防止重复
	if hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.disconnect(_on_hitbox_area_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	global_position += _direction * _speed * delta
	_elapsed += delta
	_update_trail()
	if _elapsed >= _lifetime:
		_cleanup_and_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	EffectsManager.spawn_hit_sparks(global_position)
	# 减速效果
	if data and data.slow_ratio > 0.0:
		var enemy: Node2D = area.get_parent() as Node2D
		if enemy and enemy.has_node("SlowHandler"):
			var source_id: String = "projectile_" + str(get_instance_id())
			enemy.slow_handler.apply_timed_slow(data.slow_ratio, data.slow_duration, source_id)
	# 命中信号
	hit.emit(global_position, _direction)
	# 穿透判断
	_hit_count += 1
	if _hit_count > _pierce_count:
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
	if _is_pooled or _pending_release:
		return
	_pending_release = true
	SceneFactory.release_projectile(self)

func _cleanup_dynamic_sprite() -> void:
	var old_sprite = get_node_or_null("_PooledSprite")
	if old_sprite:
		remove_child(old_sprite)
		old_sprite.queue_free()

func _cleanup_trail() -> void:
	if _trail and is_instance_valid(_trail):
		remove_child(_trail)
		_trail.queue_free()
		_trail = null

func _create_trail() -> void:
	var fx: EffectConfigData = GameConfig.effects
	_trail_max_points = fx.bullet_trail_max_points
	_trail = Line2D.new()
	_trail.width = fx.bullet_trail_width
	_trail.default_color = fx.bullet_trail_color
	_trail.z_index = -1
	_trail.top_level = true
	add_child(_trail)

func reset_for_pool() -> void:
	_cleanup_dynamic_sprite()
	_cleanup_trail()
	_trail_positions.clear()
	if hitbox and hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.disconnect(_on_hitbox_area_entered)
	if hitbox and hitbox.area_entered.is_connected(_on_legacy_hitbox_area_entered):
		hitbox.area_entered.disconnect(_on_legacy_hitbox_area_entered)
	_elapsed = 0.0
	_hit_count = 0
	_pierce_count = 0
	_direction = Vector2.ZERO
	_speed = 0.0
	_pending_release = false
	visible = true
