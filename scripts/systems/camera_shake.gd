extends Camera2D

# 屏幕震动 — 附加到玩家的 Camera2D 节点
# trauma 模型：震动强度随时间衰减，多次震动取最大值

var _trauma: float = 0.0
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_elapsed: float = 0.0

func shake(intensity: float, duration: float) -> void:
	if intensity > _shake_intensity:
		_shake_intensity = intensity
		_shake_duration = duration
		_shake_elapsed = 0.0
	_trauma = maxf(_trauma, intensity)

func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return

	_shake_elapsed += delta
	if _shake_elapsed >= _shake_duration:
		_trauma = 0.0
		_shake_intensity = 0.0
		offset = Vector2.ZERO
		return

	# trauma 线性衰减
	var progress: float = _shake_elapsed / _shake_duration
	var current_intensity: float = _shake_intensity * (1.0 - progress)
	_trauma = current_intensity

	# 随机偏移
	offset = Vector2(
		randf_range(-current_intensity, current_intensity),
		randf_range(-current_intensity, current_intensity)
	)
