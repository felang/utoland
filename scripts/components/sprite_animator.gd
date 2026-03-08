class_name SpriteAnimator
extends Node

# 精灵动画组件 — 管理 AnimatedSprite2D 创建和方向动画切换

var _sprite: AnimatedSprite2D = null
var _current_anim: String = ""

func setup_player_sprite(sprite_config: Dictionary, target_size: float) -> void:
	# 创建玩家 AnimatedSprite2D（idle + walk 4方向）
	if sprite_config.is_empty():
		return
	_create_sprite()
	_sprite.sprite_frames = SpriteLoader.create_player_sprite_frames(sprite_config)
	_apply_scale(sprite_config["frame_size"].x, target_size)
	_sprite.play("idle_down")
	_current_anim = "idle_down"

func setup_enemy_sprite(sprite_config: Dictionary, target_size: float) -> void:
	# 创建敌人 AnimatedSprite2D（walk 4方向）
	if sprite_config.is_empty():
		return
	_create_sprite()
	_sprite.sprite_frames = SpriteLoader.create_enemy_sprite_frames(sprite_config)
	_apply_scale(sprite_config["frame_size"].x, target_size)
	_sprite.play("walk_down")
	_current_anim = "walk_down"

func update_animation(velocity: Vector2) -> void:
	if not _sprite:
		return
	var anim: String = SpriteLoader.get_walk_animation(velocity, _current_anim)
	if anim != _current_anim and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
		_current_anim = anim

func update_animation_no_idle(velocity: Vector2) -> void:
	# 敌人版本：忽略 idle 动画（敌人始终在移动）
	if not _sprite:
		return
	var anim: String = SpriteLoader.get_walk_animation(velocity, _current_anim)
	if anim.begins_with("idle"):
		return
	if anim != _current_anim and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
		_current_anim = anim

func get_death_color_from_visual() -> Color:
	# 从旧 ColorRect Visual 获取颜色作为死亡特效颜色
	var parent: Node = get_parent()
	if parent:
		var old_visual: Node = parent.get_node_or_null("Visual")
		if old_visual is ColorRect:
			return old_visual.color
	return Color.RED

func _create_sprite() -> void:
	var parent: Node = get_parent()
	if not parent:
		return

	# 移除旧的 ColorRect Visual
	var old_visual: Node = parent.get_node_or_null("Visual")
	if old_visual:
		parent.remove_child(old_visual)
		old_visual.queue_free()

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Visual"
	parent.add_child(_sprite)
	parent.move_child(_sprite, 0)

func _apply_scale(sprite_size: float, target_size: float) -> void:
	if _sprite and sprite_size > 0:
		_sprite.scale = Vector2.ONE * (target_size / sprite_size)
