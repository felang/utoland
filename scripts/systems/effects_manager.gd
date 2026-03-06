extends Node

# 特效管理器 — 统一管理伤害数字、击中火花、死亡爆炸等视觉特效
# 作为 Autoload 单例全局可用

func flash_white(node: Node2D) -> Tween:
	var original_modulate: Color = node.modulate
	node.modulate = Color(2, 2, 2, 1)
	var tween: Tween = create_tween()
	tween.tween_property(node, "modulate", original_modulate, GameConfig.EFFECTS["hit_flash"]["duration"])
	return tween

func spawn_damage_number(pos: Vector2, damage: float) -> void:
	var config: Dictionary = GameConfig.EFFECTS["damage_number"]
	var label: Label = Label.new()
	label.text = str(int(damage))
	label.add_to_group("damage_numbers")
	label.global_position = pos
	label.z_index = 100
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 大伤害特殊样式
	var is_big: bool = damage >= config["big_damage_threshold"]
	if is_big:
		label.modulate = config["big_color"]
		label.scale = Vector2(config["big_damage_scale"], config["big_damage_scale"])
	else:
		label.modulate = config["normal_color"]

	# 添加到场景树
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(label)
	else:
		add_child(label)

	# 动画：上浮 + 随机横向偏移 + 淡出
	var offset_x: float = randf_range(-config["random_offset_x"], config["random_offset_x"])
	var target_pos: Vector2 = pos + Vector2(offset_x, -config["float_distance"])
	var duration: float = config["duration"]

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", target_pos, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func spawn_hit_sparks(pos: Vector2, color: Color = Color.YELLOW) -> void:
	var config: Dictionary = GameConfig.EFFECTS["hit_sparks"]
	for i in config["count"]:
		var spark: ColorRect = ColorRect.new()
		spark.size = Vector2(2, 2)
		spark.position = pos - Vector2(1, 1)
		spark.color = color
		spark.z_index = 50

		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(spark)
		else:
			add_child(spark)

		var angle: float = randf() * TAU
		var spread_dir: Vector2 = Vector2.from_angle(angle)
		var target: Vector2 = pos + spread_dir * config["spread_speed"] * config["lifetime"]

		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", target - Vector2(1, 1), config["lifetime"])
		tween.tween_property(spark, "modulate:a", 0.0, config["lifetime"])
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

func spawn_death_effect(pos: Vector2, entity_color: Color) -> void:
	var config: Dictionary = GameConfig.EFFECTS["death_particles"]
	for i in config["count"]:
		var particle: ColorRect = ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.position = pos - Vector2(1.5, 1.5)
		particle.color = entity_color
		particle.z_index = 50

		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(particle)
		else:
			add_child(particle)

		var angle: float = randf() * TAU
		var speed: float = randf_range(50.0, 120.0)
		var spread_dir: Vector2 = Vector2.from_angle(angle)
		var target: Vector2 = pos + spread_dir * speed * config["lifetime"]
		target.y += config["gravity"] * config["lifetime"] * config["lifetime"] * 0.5

		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target - Vector2(1.5, 1.5), config["lifetime"]).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, config["lifetime"] * 0.5).set_delay(config["lifetime"] * 0.5)
		tween.set_parallel(false)
		tween.tween_callback(particle.queue_free)
