class_name KnockbackHandler
extends Node

# 击退处理组件 — 通过速度衰减实现，走 move_and_slide 物理碰撞

var knockback_velocity: Vector2 = Vector2.ZERO
var _decay_speed: float = 0.0

func apply_knockback(direction: Vector2) -> void:
	var fx: EffectConfigData = GameConfig.effects
	# 将距离/时间转换为初始速度：v = 2 * distance / duration（匀减速到0）
	var initial_speed: float = 2.0 * fx.knockback_distance / fx.knockback_duration
	knockback_velocity = direction.normalized() * initial_speed
	_decay_speed = initial_speed / fx.knockback_duration

## 每物理帧调用，返回当前击退速度并衰减
func tick(delta: float) -> Vector2:
	if knockback_velocity.length_squared() < 1.0:
		knockback_velocity = Vector2.ZERO
		return Vector2.ZERO
	var result: Vector2 = knockback_velocity
	# 线性衰减
	var decay: float = _decay_speed * delta
	if knockback_velocity.length() <= decay:
		knockback_velocity = Vector2.ZERO
	else:
		knockback_velocity -= knockback_velocity.normalized() * decay
	return result

func reset() -> void:
	knockback_velocity = Vector2.ZERO
	_decay_speed = 0.0
