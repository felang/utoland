extends Node

# 特效管理器 — 统一管理伤害数字、击中火花、死亡爆炸等视觉特效
# 作为 Autoload 单例全局可用

func flash_white(node: Node2D) -> Tween:
	var original_modulate: Color = node.modulate
	node.modulate = Color(2, 2, 2, 1)
	var tween: Tween = create_tween()
	tween.tween_property(node, "modulate", original_modulate, GameConfig.effects.hit_flash_duration)
	return tween

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
		spark.size = Vector2(2, 2)
		spark.position = pos - Vector2(1, 1)
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
		tween.tween_property(spark, "position", target - Vector2(1, 1), fx.hit_spark_lifetime)
		tween.tween_property(spark, "modulate:a", 0.0, fx.hit_spark_lifetime)
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

func spawn_death_effect(pos: Vector2, entity_color: Color) -> void:
	var fx: EffectConfigData = GameConfig.effects
	for i in fx.death_particle_count:
		var particle: ColorRect = ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.position = pos - Vector2(1.5, 1.5)
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
		target.y += fx.death_particle_gravity * fx.death_particle_lifetime * fx.death_particle_lifetime * 0.5

		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target - Vector2(1.5, 1.5), fx.death_particle_lifetime).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, fx.death_particle_lifetime * 0.5).set_delay(fx.death_particle_lifetime * 0.5)
		tween.set_parallel(false)
		tween.tween_callback(particle.queue_free)
