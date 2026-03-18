extends Camera2D

# 摄像机控制 — 缩放、边界、平滑跟随、前瞻、屏幕震动
# 附加到玩家的 Camera2D 节点

# 震动状态
var _trauma: float = 0.0
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_elapsed: float = 0.0

func _ready() -> void:
	var fx: EffectConfigData = GameConfig.effects
	# 缩放（float → Vector2）
	zoom = Vector2(fx.camera_zoom, fx.camera_zoom)
	# 平滑跟随
	position_smoothing_enabled = true
	position_smoothing_speed = fx.camera_smoothing_speed
	# 地图边界限制
	limit_left = -int(GameConfig.MAP_HALF_WIDTH)
	limit_right = int(GameConfig.MAP_HALF_WIDTH)
	limit_top = -int(GameConfig.MAP_HALF_HEIGHT)
	limit_bottom = int(GameConfig.MAP_HALF_HEIGHT)
	# 死区（drag margins）
	drag_horizontal_enabled = true
	drag_vertical_enabled = true
	drag_left_margin = fx.camera_dead_zone_width
	drag_right_margin = fx.camera_dead_zone_width
	drag_top_margin = fx.camera_dead_zone_height
	drag_bottom_margin = fx.camera_dead_zone_height
	# 连接全局 camera shake 请求
	EventBus.camera_shake_requested.connect(shake)

func shake(intensity: float, duration: float) -> void:
	if intensity > _shake_intensity:
		_shake_intensity = intensity
		_shake_duration = duration
		_shake_elapsed = 0.0
	_trauma = maxf(_trauma, intensity)

func _process(delta: float) -> void:
	var shake_offset: Vector2 = Vector2.ZERO

	if _trauma > 0.0:
		_shake_elapsed += delta
		if _shake_elapsed >= _shake_duration:
			_trauma = 0.0
			_shake_intensity = 0.0
		else:
			var progress: float = _shake_elapsed / _shake_duration
			var current_intensity: float = _shake_intensity * (1.0 - progress)
			_trauma = current_intensity
			shake_offset = Vector2(
				randf_range(-current_intensity, current_intensity),
				randf_range(-current_intensity, current_intensity)
			)

	offset = shake_offset
