extends Node2D

var _upgrade_popup_scene: PackedScene = preload("res://scenes/ui/upgrade_popup.tscn")

func _ready() -> void:
	_load_map()
	_restore_towers()
	# 暂停覆盖层
	var pause_overlay = load("res://scripts/ui/pause_overlay.gd").new()
	add_child(pause_overlay)
	# 调试面板
	var debug_panel = load("res://scripts/ui/debug_panel.gd").new()
	add_child(debug_panel)
	# 波次结束后升级弹窗
	EventBus.wave_transition_ready.connect(_on_wave_transition_ready)

func _load_map() -> void:
	var map_data: MapData = GameConfig.maps.get(GameData.selected_map)
	if map_data == null or map_data.map_scene.is_empty():
		push_warning("地图场景未配置，跳过加载: " + GameData.selected_map)
		return
	if not ResourceLoader.exists(map_data.map_scene):
		push_warning("地图场景文件不存在: " + map_data.map_scene)
		return
	var map_instance = load(map_data.map_scene).instantiate()
	add_child(map_instance)
	move_child(map_instance, 0)  # 确保地图在最底层

func _restore_towers() -> void:
	for tower_entry in GameData.tower_inventory:
		var tower_type: String = tower_entry["type"]
		var tower_pos: Vector2 = tower_entry["position"]
		var tower: Node2D = SceneFactory.create_tower(tower_type)
		if tower:
			tower.global_position = tower_pos
			tower.add_to_group(Enums.Group.TOWERS)
			add_child(tower)

func _on_wave_transition_ready() -> void:
	await get_tree().process_frame
	_show_upgrade_popup()

func _show_upgrade_popup() -> void:
	var count: int = GameData.pending_upgrades
	if count <= 0:
		SceneManager.go_to(Enums.Scene.PLACEMENT)
		return
	var popup: CanvasLayer = _upgrade_popup_scene.instantiate()
	add_child(popup)
	popup.all_upgrades_completed.connect(_on_upgrades_completed)
	popup.skipped.connect(_on_upgrades_skipped)
	popup.show_upgrades(count)

func _on_upgrades_completed() -> void:
	SceneManager.go_to(Enums.Scene.PLACEMENT)

func _on_upgrades_skipped() -> void:
	SceneManager.go_to(Enums.Scene.PLACEMENT)
