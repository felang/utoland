# SwordWeapon — 突刺近战武器（类似土豆兄弟小刀）
# 向前突刺再收回，过程中碰撞到敌人造成伤害
class_name SwordWeapon
extends Weapon

const THRUST_DURATION: float = 0.1   # 突刺时间
const RETRACT_DURATION: float = 0.1  # 收回时间

var _thrust_hitbox: Area2D = null
var _hit_enemies: Array[Node2D] = []
var _is_thrusting: bool = false
var _base_damage: float = 0.0
var _thrust_direction: Vector2 = Vector2.RIGHT

func fire(target: Node2D) -> void:
	if not owner_node or not sprite or not is_instance_valid(sprite):
		return
	if _is_thrusting:
		return
	_base_damage = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	_thrust_direction = owner_node.global_position.direction_to(target.global_position)
	_hit_enemies.clear()
	_is_thrusting = true
	# 创建突刺 hitbox 挂在精灵上
	_create_thrust_hitbox()
	# 突刺动画：精灵从当前位置向前突出 weapon_range，再收回
	var thrust_offset: Vector2 = _thrust_direction * get_weapon_range()
	var original_pos: Vector2 = sprite.position
	var thrust_pos: Vector2 = original_pos + thrust_offset
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "position", thrust_pos, THRUST_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "position", original_pos, RETRACT_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_on_thrust_finished)
	AudioManager.play("shoot")

func _create_thrust_hitbox() -> void:
	_thrust_hitbox = Area2D.new()
	_thrust_hitbox.collision_layer = 4   # 与 bullet hitbox 同层
	_thrust_hitbox.collision_mask = 128  # 检测 enemy hurtbox
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	_thrust_hitbox.add_child(shape)
	_thrust_hitbox.area_entered.connect(_on_thrust_hit)
	sprite.add_child(_thrust_hitbox)

func _on_thrust_hit(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	var enemy: Node2D = area.get_parent()
	if enemy in _hit_enemies:
		return
	_hit_enemies.append(enemy)
	area.hit_taken.emit(_base_damage, _thrust_direction * weapon_data.knockback_force)
	EffectsManager.spawn_hit_sparks(enemy.global_position)

func _on_thrust_finished() -> void:
	_is_thrusting = false
	if _thrust_hitbox and is_instance_valid(_thrust_hitbox):
		_thrust_hitbox.queue_free()
		_thrust_hitbox = null
