extends Node

# 特效管理器 — 统一管理伤害数字、击中火花、死亡爆炸等视觉特效
# 作为 Autoload 单例全局可用

const FLASH_WHITE_COLOR := Color(2, 2, 2, 1)         # 闪白叠加颜色
const FLASH_HIT_COLOR := Color(1, 0.3, 0.3, 1)      # 受击红色叠加颜色
const HIT_SPARK_SIZE := Vector2(2, 2)                  # 击中火花粒子尺寸
const DEATH_PARTICLE_SIZE := Vector2(3, 3)             # 死亡粒子尺寸
const GRAVITY_FACTOR: float = 0.5                      # 重力位移公式的 1/2 系数

func flash_white(node: Node2D) -> Tween:
	var original_modulate: Color = node.modulate
	node.modulate = FLASH_WHITE_COLOR
	var tween: Tween = create_tween()
	tween.tween_property(node, "modulate", original_modulate, GameConfig.effects.hit_flash_duration)
	return tween

func flash_hit(node: Node2D) -> Tween:
	var original_modulate: Color = node.modulate
	node.modulate = FLASH_HIT_COLOR
	var tween: Tween = create_tween()
	tween.tween_property(node, "modulate", original_modulate, GameConfig.effects.hit_flash_duration)
	return tween

func sprite_shake(node: Node2D, amount: float = 2.0) -> void:
	if not is_instance_valid(node):
		return
	var sprite: Node2D = null
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			sprite = child
			break
	if not sprite:
		return
	var prop: String = "offset"
	var base: Vector2 = sprite.get(prop)
	var tween: Tween = node.create_tween()
	tween.tween_property(sprite, prop, base + Vector2(amount, 0), 0.02)
	tween.tween_property(sprite, prop, base + Vector2(-amount, 0), 0.02)
	tween.tween_property(sprite, prop, base, 0.02)

func spawn_damage_number(pos: Vector2, damage: float) -> void:
	var fx: EffectConfigData = GameConfig.effects
	var label: Label = Label.new()
	label.text = str(int(damage))
	label.add_to_group(Enums.Group.DAMAGE_NUMBERS)
	label.global_position = pos
	label.z_index = fx.damage_number_z_index
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 大伤害特殊样式
	var is_big: bool = damage >= fx.damage_number_big_threshold
	if is_big:
		label.modulate = fx.damage_number_big_color
		label.scale = Vector2(fx.damage_number_big_scale, fx.damage_number_big_scale)
	else:
		label.modulate = fx.damage_number_normal_color

	# 添加到场景树
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(label)
	else:
		add_child(label)

	# 动画：上浮 + 随机横向偏移 + 淡出
	var offset_x: float = randf_range(-fx.damage_number_random_offset_x, fx.damage_number_random_offset_x)
	var target_pos: Vector2 = pos + Vector2(offset_x, -fx.damage_number_float_distance)
	var duration: float = fx.damage_number_duration

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", target_pos, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func spawn_hit_sparks(pos: Vector2, color: Color = Color.YELLOW) -> void:
	var fx: EffectConfigData = GameConfig.effects
	for i in fx.hit_spark_count:
		var spark: ColorRect = ColorRect.new()
		spark.size = HIT_SPARK_SIZE
		spark.position = pos - HIT_SPARK_SIZE / 2
		spark.color = color
		spark.z_index = fx.hit_spark_z_index
		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(spark)
		else:
			add_child(spark)

		var angle: float = randf() * TAU
		var spread_dir: Vector2 = Vector2.from_angle(angle)
		var target: Vector2 = pos + spread_dir * fx.hit_spark_spread_speed * fx.hit_spark_lifetime

		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", target - HIT_SPARK_SIZE / 2, fx.hit_spark_lifetime)
		tween.tween_property(spark, "modulate:a", 0.0, fx.hit_spark_lifetime)
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

func spawn_death_effect(pos: Vector2, entity_color: Color) -> void:
	var fx: EffectConfigData = GameConfig.effects
	for i in fx.death_particle_count:
		var particle: ColorRect = ColorRect.new()
		particle.size = DEATH_PARTICLE_SIZE
		particle.position = pos - DEATH_PARTICLE_SIZE / 2
		particle.color = entity_color
		particle.z_index = fx.death_particle_z_index

		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(particle)
		else:
			add_child(particle)

		var angle: float = randf() * TAU
		var speed: float = randf_range(fx.death_particle_speed_min, fx.death_particle_speed_max)
		var spread_dir: Vector2 = Vector2.from_angle(angle)
		var target: Vector2 = pos + spread_dir * speed * fx.death_particle_lifetime
		target.y += fx.death_particle_gravity * fx.death_particle_lifetime * fx.death_particle_lifetime * GRAVITY_FACTOR

		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target - DEATH_PARTICLE_SIZE / 2, fx.death_particle_lifetime).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, fx.death_particle_lifetime * 0.5).set_delay(fx.death_particle_lifetime * 0.5)
		tween.set_parallel(false)
		tween.tween_callback(particle.queue_free)

func spawn_enhanced_death(pos: Vector2, _entity_color: Color) -> void:
	# 白闪缩放弹跳效果（独立 ColorRect 节点）
	# 注意：不调用 spawn_death_effect()，因为 HealthComponent.die() 已调用过
	var flash_rect: ColorRect = ColorRect.new()
	flash_rect.size = Vector2(12, 12)
	flash_rect.position = pos - flash_rect.size / 2
	flash_rect.color = Color.WHITE
	flash_rect.z_index = 50
	flash_rect.pivot_offset = flash_rect.size / 2
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(flash_rect)
	else:
		add_child(flash_rect)

	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(flash_rect, "scale", Vector2(1.3, 1.3), 0.05)
	flash_tween.tween_property(flash_rect, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
	flash_tween.tween_callback(flash_rect.queue_free)

func hitstop(time_scale: float = 0.05, duration: float = 0.1) -> void:
	Engine.time_scale = time_scale
	# ignore_time_scale=true (4th param) 确保计时器按真实时间走
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
