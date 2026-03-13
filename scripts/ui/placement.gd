extends Node2D

const GRID_SIZE = GameConfig.GRID_SIZE
const CAMERA_PAN_SPEED = 300.0
const ZOOM_STEP = 1.15
const ZOOM_MIN = Vector2(0.25, 0.25)
const ZOOM_MAX = Vector2(2.0, 2.0)
const PLACEMENT_ZOOM_INIT = Vector2(0.75, 0.75)
const SIDEBAR_WIDTH = 120.0

signal coins_changed

@onready var _placement_content: VBoxContainer = $UI/SidePanel/PlacementContent
@onready var _coins_label: Label = $UI/SidePanel/CoinsLabel
@onready var _start_button: Button = $UI/SidePanel/StartBattleButton
@onready var background_sprite: Sprite2D = $Background/BackgroundSprite

var _placement_camera: Camera2D = null
var _grid_overlay: Node2D = null
var _range_indicator: RangeIndicator = null
var _placement_panel: Node = null

func _ready() -> void:
	_load_map_background()

	# 网格覆层
	_grid_overlay = preload("res://scripts/ui/grid_overlay.gd").new()
	_grid_overlay.z_index = -50
	add_child(_grid_overlay)

	# 范围指示器
	_range_indicator = RangeIndicator.new()
	_range_indicator.z_index = -40
	add_child(_range_indicator)

	# 恢复之前布置的塔
	for tower_data in GameData.tower_inventory:
		var tower_type: String = tower_data["type"]
		var tower_pos: Vector2 = tower_data["position"]
		var tower: Node2D = SceneFactory.create_tower(tower_type)
		if tower:
			tower.global_position = tower_pos
			tower.add_to_group(Enums.Group.TOWERS)
			add_child(tower)

	# 初始化布置面板
	_placement_panel = preload("res://scripts/ui/placement_panel.gd").new()
	_placement_content.add_child(_placement_panel)
	_placement_panel.initialize(self, _range_indicator)

	# 开始战斗按钮
	_start_button.pressed.connect(_start_battle)

	# 冻结玩家
	$Player.set_physics_process(false)

	# 布置相机
	_placement_camera = Camera2D.new()
	_placement_camera.zoom = PLACEMENT_ZOOM_INIT
	_placement_camera.position_smoothing_enabled = false
	_placement_camera.limit_left = -int(GameConfig.MAP_HALF_WIDTH)
	_placement_camera.limit_right = int(GameConfig.MAP_HALF_WIDTH)
	_placement_camera.limit_top = -int(GameConfig.MAP_HALF_HEIGHT)
	_placement_camera.limit_bottom = int(GameConfig.MAP_HALF_HEIGHT)
	add_child(_placement_camera)
	_placement_camera.make_current()

	update_coins_display()

func _process(delta: float) -> void:
	if _placement_camera:
		var pan := Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		)
		_placement_camera.position += pan * CAMERA_PAN_SPEED * delta

func _input(event: InputEvent) -> void:
	# 侧栏区域不处理地图交互
	if event is InputEventMouse:
		var viewport_pos: Vector2 = event.position
		if viewport_pos.x < SIDEBAR_WIDTH:
			return

	# 滚轮缩放
	if event is InputEventMouseButton and event.pressed and _placement_camera:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_placement_camera.zoom = (_placement_camera.zoom * ZOOM_STEP).clamp(ZOOM_MIN, ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_placement_camera.zoom = (_placement_camera.zoom / ZOOM_STEP).clamp(ZOOM_MIN, ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return

	# ESC 处理
	if event.is_action_pressed("ui_cancel"):
		if _placement_panel and _placement_panel.has_preview():
			_placement_panel.cancel_placement()
		else:
			get_tree().paused = not get_tree().paused
		get_viewport().set_input_as_handled()
		return

func update_coins_display() -> void:
	_coins_label.text = "金币: %d" % GameData.coins
	coins_changed.emit()

func get_grid_position(pos: Vector2) -> Vector2:
	return Vector2(
		floor(pos.x / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2.0,
		floor(pos.y / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2.0
	)

func can_place_at(pos: Vector2) -> bool:
	if abs(pos.x) > GameConfig.MAP_HALF_WIDTH or abs(pos.y) > GameConfig.MAP_HALF_HEIGHT:
		return false
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	for tower in towers:
		if tower.global_position.distance_to(pos) < GRID_SIZE:
			return false
	var player = $Player
	if player.global_position.distance_to(pos) < GRID_SIZE:
		return false
	return true

func find_tower_at(pos: Vector2) -> Node2D:
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	var closest: Node2D = null
	var min_dist: float = GRID_SIZE / 2.0
	for tower in towers:
		var dist: float = tower.global_position.distance_to(pos)
		if dist < min_dist:
			min_dist = dist
			closest = tower
	return closest

func _start_battle() -> void:
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	var current_towers: Array[Dictionary] = []
	for tower in towers:
		var tower_type: String = ""
		if "tower_type" in tower:
			tower_type = tower.tower_type
		if tower_type != "":
			current_towers.append({
				"type": tower_type,
				"position": tower.global_position
			})
	GameData.tower_inventory = current_towers
	SceneManager.go_to(Enums.Scene.MAIN)

func _load_map_background() -> void:
	var map_id: String = GameData.selected_map
	if not GameConfig.maps.has(map_id):
		push_warning("未知地图: " + map_id + ", 使用默认地图")
		map_id = Enums.Map.FOREST
		GameData.selected_map = map_id
	var md: MapData = GameConfig.maps[map_id]
	var bg_path: String = md.background
	if ResourceLoader.exists(bg_path):
		var bg_texture: Resource = load(bg_path)
		if bg_texture and background_sprite:
			background_sprite.texture = bg_texture
		else:
			_use_fallback_background(map_id)
	else:
		_use_fallback_background(map_id)

func _use_fallback_background(map_id: String) -> void:
	if background_sprite:
		background_sprite.queue_free()
	var map_size: Vector2 = Vector2(GameConfig.MAP_PIXEL_WIDTH, GameConfig.MAP_PIXEL_HEIGHT)
	var color_rect: ColorRect = ColorRect.new()
	color_rect.size = map_size
	color_rect.position = -map_size / 2
	var md: MapData = GameConfig.maps[map_id]
	color_rect.color = Color(md.fallback_color)
	$Background.add_child(color_rect)
