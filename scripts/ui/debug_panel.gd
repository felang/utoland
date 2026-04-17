# scripts/ui/debug_panel.gd
extends CanvasLayer

## 调试面板 — Ctrl+D 显隐，Ctrl+1 跳波，Ctrl+2 加钱，Ctrl+3 无敌，Ctrl+4/5 调 zoom

const ZOOM_STEP: float = 0.05
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 1.0

var _label: Label
var _godmode: bool = false

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_skip_wave"):
		_skip_wave()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_add_coins"):
		InventoryManager.coins += 100
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_godmode"):
		_toggle_godmode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_zoom_out"):
		_adjust_zoom(-ZOOM_STEP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_zoom_in"):
		_adjust_zoom(ZOOM_STEP)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_info()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(4, 4)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color.GREEN)
	panel.add_child(_label)
	add_child(panel)

func _update_info() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var wave_managers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.WAVE_MANAGER)
	var wave_info: String = "N/A"
	var total_info: String = "N/A"
	if wave_managers.size() > 0:
		var wm: Node = wave_managers[0]
		wave_info = str(wm.current_wave)
		total_info = str(wm.total_waves)

	var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	var hp_text: String = "N/A"
	var dmg_text: String = "N/A"
	if player and player.has_node("HealthComponent"):
		hp_text = "%d/%d" % [int(player.health.current_hp), int(player.health.max_hp)]
	dmg_text = "-"

	# 摄像机 zoom 信息
	var zoom_text: String = "N/A"
	var camera: Camera2D = _get_player_camera()
	if camera:
		zoom_text = "%.2f" % camera.zoom.x
		var visible_w: float = GameConfig.BASE_VIEWPORT_WIDTH / camera.zoom.x
		var visible_h: float = GameConfig.BASE_VIEWPORT_HEIGHT / camera.zoom.y
		zoom_text += " (%dx%d)" % [int(visible_w), int(visible_h)]

	var godmode_text: String = " [GOD]" if _godmode else ""
	_label.text = "Wave: %s/%s | Enemies: %d\nHP: %s | DMG: %s\nCoins: %d | FPS: %d%s\nZoom: %s | Map: %dx%d" % [
		wave_info, total_info, enemies.size(),
		hp_text, dmg_text,
		InventoryManager.coins, Engine.get_frames_per_second(),
		godmode_text,
		zoom_text, int(GameConfig.MAP_PIXEL_WIDTH), int(GameConfig.MAP_PIXEL_HEIGHT)
	]

func _skip_wave() -> void:
	var wave_managers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.WAVE_MANAGER)
	if wave_managers.size() > 0:
		wave_managers[0].complete_wave()

func _toggle_godmode() -> void:
	_godmode = not _godmode
	var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player and player.has_node("HealthComponent"):
		player.health.invincible = _godmode

func _adjust_zoom(delta: float) -> void:
	var camera: Camera2D = _get_player_camera()
	if not camera:
		return
	var new_zoom: float = clampf(camera.zoom.x + delta, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(new_zoom, new_zoom)

func _get_player_camera() -> Camera2D:
	var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player:
		for child in player.get_children():
			if child is Camera2D:
				return child
	return null
