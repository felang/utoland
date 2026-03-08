class_name SpriteLoader
extends RefCounted

# 精灵加载工具类 — 从 sprite sheet 创建 SpriteFrames 资源
# 方向约定：Walk sprite sheet 4行 = 下(0)、上(1)、左(2)、右(3)

# 从玩家配置创建带 idle/walk 动画的 SpriteFrames
# idle: 1行4帧(64×16)，walk: 4行4帧(64×64)
static func create_player_sprite_frames(config: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var frame_size: Vector2 = config["frame_size"]
	var fps: float = config["fps"]

	# 加载纹理
	var idle_tex: Texture2D = load(config["idle"])
	var walk_tex: Texture2D = load(config["walk"])

	# idle 动画（单行，4帧）
	frames.add_animation(Enums.Anim.IDLE)
	frames.set_animation_speed(Enums.Anim.IDLE, fps)
	frames.set_animation_loop(Enums.Anim.IDLE, true)
	for i in config["idle_frames"]:
		var atlas := AtlasTexture.new()
		atlas.atlas = idle_tex
		atlas.region = Rect2(i * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame(Enums.Anim.IDLE, atlas)

	# walk 动画（4方向，每方向4帧）
	var dir_names: Array[String] = [Enums.Anim.WALK_DOWN, Enums.Anim.WALK_UP, Enums.Anim.WALK_LEFT, Enums.Anim.WALK_RIGHT]
	for dir_idx in config["walk_directions"]:
		var anim_name: String = dir_names[dir_idx]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, true)
		for frame_idx in config["walk_frames"]:
			var atlas := AtlasTexture.new()
			atlas.atlas = walk_tex
			atlas.region = Rect2(frame_idx * frame_size.x, dir_idx * frame_size.y, frame_size.x, frame_size.y)
			frames.add_frame(anim_name, atlas)

	# 删除默认的 "default" 动画
	if frames.has_animation(Enums.Anim.DEFAULT):
		frames.remove_animation(Enums.Anim.DEFAULT)

	return frames


# 从敌人配置创建带方向 walk 动画的 SpriteFrames
# spritesheet: 4行4帧(64×64)
static func create_enemy_sprite_frames(config: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var frame_size: Vector2 = config["frame_size"]
	var fps: float = config["fps"]

	var spritesheet: Texture2D = load(config["spritesheet"])

	# 4方向 walk 动画
	var dir_names: Array[String] = [Enums.Anim.WALK_DOWN, Enums.Anim.WALK_UP, Enums.Anim.WALK_LEFT, Enums.Anim.WALK_RIGHT]
	for dir_idx in config["walk_directions"]:
		var anim_name: String = dir_names[dir_idx]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, true)
		for frame_idx in config["walk_frames"]:
			var atlas := AtlasTexture.new()
			atlas.atlas = spritesheet
			atlas.region = Rect2(frame_idx * frame_size.x, dir_idx * frame_size.y, frame_size.x, frame_size.y)
			frames.add_frame(anim_name, atlas)

	# 删除默认的 "default" 动画
	if frames.has_animation(Enums.Anim.DEFAULT):
		frames.remove_animation(Enums.Anim.DEFAULT)

	return frames


# 根据移动方向获取动画名称
# current_anim 用于方向滞后：对角移动时保持当前方向，避免快速切换
static func get_walk_animation(velocity: Vector2, current_anim: String = "", hysteresis_keep: float = 0.7, hysteresis_switch: float = 1.4) -> String:
	if velocity.length_squared() < 1.0:
		return Enums.Anim.IDLE

	var abs_x: float = abs(velocity.x)
	var abs_y: float = abs(velocity.y)

	# 滞后阈值：当前方向轴需要比另一轴小 30% 以上才切换
	var is_current_horizontal: bool = current_anim in [Enums.Anim.WALK_LEFT, Enums.Anim.WALK_RIGHT]
	var is_current_vertical: bool = current_anim in [Enums.Anim.WALK_UP, Enums.Anim.WALK_DOWN]

	var use_horizontal: bool
	if is_current_horizontal:
		# 当前是水平方向，垂直轴需要明显更大才切换
		use_horizontal = abs_x >= abs_y * hysteresis_keep
	elif is_current_vertical:
		# 当前是垂直方向，水平轴需要明显更大才切换
		use_horizontal = abs_x > abs_y * hysteresis_switch
	else:
		# 无当前方向（idle），正常判断
		use_horizontal = abs_x > abs_y

	if use_horizontal:
		return Enums.Anim.WALK_RIGHT if velocity.x > 0 else Enums.Anim.WALK_LEFT
	else:
		return Enums.Anim.WALK_DOWN if velocity.y > 0 else Enums.Anim.WALK_UP
