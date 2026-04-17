class_name ArrowRainEffect
extends Node2D
## 箭雨效果场景 — 独立存活 duration 秒，定期对范围内敌人造成伤害
##
## 由 ArrowRainSkillComponent._spawn_rain() 实例化并调用 setup()。
## 使用 Area2D + CircleShape2D 检测范围内的敌人 CharacterBody2D，
## 每 tick_interval 秒对其 HealthComponent 造成 damage_per_tick 伤害。
## 第一 tick 可选触发击退（has_knockback）。
## duration 结束后自动 queue_free()。

@onready var _area: Area2D = $Area2D
@onready var _shape: CollisionShape2D = $Area2D/CollisionShape2D

var _data: ArrowRainData = null
var _radius: float = 96.0
var _has_knockback: bool = false
var _has_dot_field: bool = false

var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _first_tick: bool = true

func setup(data: ArrowRainData, radius: float, knockback: bool, dot_field: bool) -> void:
	_data = data
	_radius = radius
	_has_knockback = knockback
	_has_dot_field = dot_field

func _ready() -> void:
	# 设置碰撞形状半径
	var circle := CircleShape2D.new()
	circle.radius = _radius
	_shape.shape = circle
	# 首次 tick 立刻触发
	_tick_timer = 0.0

func _physics_process(delta: float) -> void:
	if _data == null:
		return
	_elapsed += delta
	if _elapsed >= _data.duration:
		queue_free()
		return
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_do_tick()
		_tick_timer = _data.tick_interval

func _do_tick() -> void:
	for body in _area.get_overlapping_bodies():
		if not (body is Node2D):
			continue
		if not body.is_in_group(Enums.Group.ENEMIES):
			continue
		var hp: HealthComponent = body.get_node_or_null("HealthComponent")
		if hp:
			hp.take_damage(_data.damage_per_tick)
		# 首 tick 击退（若有 knockback perk 且实体支持）
		if _first_tick and _has_knockback:
			var kh: Node = body.get_node_or_null("KnockbackHandler")
			if kh and kh.has_method("apply_knockback"):
				var dir: Vector2 = (body.global_position - global_position).normalized()
				kh.apply_knockback(dir, 200.0)
	_first_tick = false
