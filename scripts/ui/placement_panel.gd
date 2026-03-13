extends Node
## 布置侧栏：塔卡片管理、点击/拖放、放置/移除逻辑

const DRAG_THRESHOLD: float = 5.0

var _main: Node2D = null
var _range_indicator: RangeIndicator = null
var _preview_tower: Node2D = null
var _selected_tower_type: String = ""
var _selected_placed_tower: Node2D = null
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_tower_type: String = ""
var _tower_buttons: Dictionary = {}

func initialize(main: Node2D, range_indicator: RangeIndicator) -> void:
	_main = main
	_range_indicator = range_indicator
	_create_tower_cards()
	_update_buttons()
	_main.coins_changed.connect(_update_buttons)
	EventBus.tower_purchased.connect(_on_tower_purchased)
	EventBus.tower_upgraded.connect(_on_tower_upgraded)

func _on_tower_purchased(_tower_type: String) -> void:
	_create_tower_cards()
	_update_buttons()

func _on_tower_upgraded(_tower_type: String) -> void:
	_create_tower_cards()
	_update_buttons()

func _create_tower_cards() -> void:
	var tower_list: VBoxContainer = get_parent().get_node("PlacementScroll/TowerList")
	for child in tower_list.get_children():
		child.queue_free()
	_tower_buttons.clear()

	for tower_type: String in GameData.owned_towers:
		var td: TowerData = GameConfig.towers[tower_type]
		var level: int = GameData.owned_towers[tower_type]
		var cost: int = SceneFactory.get_tower_cost(tower_type)
		var display: String = "%s Lv%d" % [td.display_name, level]
		var card := _create_card(tower_type, display, cost)
		tower_list.add_child(card)
		_tower_buttons[tower_type] = card

func _create_card(tower_type: String, display_name: String, cost: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(108, 60)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "%d 金" % cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.add_theme_color_override("font_color", Color("#e0c040"))
	vbox.add_child(cost_label)

	card.gui_input.connect(func(event: InputEvent) -> void: _on_card_input(event, tower_type))
	return card

func _on_card_input(event: InputEvent, tower_type: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cost: int = SceneFactory.get_tower_cost(tower_type)
		if GameData.coins < cost:
			return
		_drag_start_pos = event.global_position
		_drag_tower_type = tower_type

	elif event is InputEventMouseMotion and _drag_tower_type != "":
		if not _is_dragging:
			var dist: float = event.global_position.distance_to(_drag_start_pos)
			if dist > DRAG_THRESHOLD:
				_is_dragging = true
				_select_tower(_drag_tower_type)

	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_dragging and _preview_tower:
			_place_tower()
		elif not _is_dragging and _drag_tower_type != "":
			_select_tower(_drag_tower_type)
		_drag_tower_type = ""
		_is_dragging = false

func _select_tower(type: String) -> void:
	_deselect_tower()
	var cost: int = SceneFactory.get_tower_cost(type)
	if GameData.coins < cost:
		return
	_selected_tower_type = type
	_cancel_preview()
	_preview_tower = SceneFactory.create_tower(type)
	if _preview_tower:
		_preview_tower.modulate = Color(1, 1, 1, 0.5)
		_main.add_child(_preview_tower)
		# 预览塔不应参与碰撞检测，从 TOWERS 组中移除以避免阻挡自身放置
		_preview_tower.remove_from_group(Enums.Group.TOWERS)
		var td: TowerData = GameConfig.towers[type]
		var level: int = GameData.owned_towers.get(type, 1)
		var idx: int = clampi(level - 1, 0, td.attack_range_per_level.size() - 1)
		_range_indicator.set_range(td.attack_range_per_level[idx])

func _process(_delta: float) -> void:
	if _preview_tower and _main:
		var grid_pos: Vector2 = _main.get_grid_position(_main.get_global_mouse_position())
		_preview_tower.global_position = grid_pos
		_range_indicator.global_position = grid_pos
		if _main.can_place_at(grid_pos):
			_preview_tower.modulate = Color(1, 1, 1, 0.5)
		else:
			_preview_tower.modulate = Color(1, 0.3, 0.3, 0.5)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var viewport_pos: Vector2 = event.position
		if viewport_pos.x < _main.SIDEBAR_WIDTH:
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _preview_tower:
				_place_tower()
			else:
				var clicked: Node2D = _main.find_tower_at(_main.get_global_mouse_position())
				if clicked:
					_select_placed_tower(clicked)
				else:
					_deselect_tower()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _preview_tower:
				cancel_placement()
			else:
				_remove_tower_at(_main.get_global_mouse_position())

func _place_tower() -> void:
	if not _preview_tower:
		return
	if not _main.can_place_at(_preview_tower.global_position):
		return
	var cost: int = SceneFactory.get_tower_cost(_selected_tower_type)
	GameData.coins -= cost
	_preview_tower.modulate = Color(1, 1, 1, 1)
	_preview_tower.add_to_group(Enums.Group.TOWERS)
	_preview_tower = null
	_selected_tower_type = ""
	_range_indicator.hide_range()
	AudioManager.play("tower_place")
	_main.update_coins_display()

func _remove_tower_at(pos: Vector2) -> void:
	var tower: Node2D = _main.find_tower_at(pos)
	if not tower:
		return
	var cost: int = SceneFactory.get_tower_cost(tower.tower_type)
	GameData.coins += cost
	tower.queue_free()
	_deselect_tower()
	AudioManager.play("tower_remove")
	_main.update_coins_display()

func _select_placed_tower(tower: Node2D) -> void:
	_selected_placed_tower = tower
	var tower_range: float = 0.0
	if "attack_range" in tower:
		tower_range = tower.attack_range
	elif "slow_radius" in tower:
		tower_range = tower.slow_radius
	if tower_range > 0:
		_range_indicator.global_position = tower.global_position
		_range_indicator.set_range(tower_range)
	else:
		_range_indicator.hide_range()

func _deselect_tower() -> void:
	_selected_placed_tower = null
	_range_indicator.hide_range()

func cancel_placement() -> void:
	_cancel_preview()
	_selected_tower_type = ""
	_range_indicator.hide_range()

func has_preview() -> bool:
	return _preview_tower != null

func _cancel_preview() -> void:
	if _preview_tower:
		_preview_tower.queue_free()
		_preview_tower = null

func _update_buttons() -> void:
	for tower_type in _tower_buttons:
		var card: PanelContainer = _tower_buttons[tower_type]
		var cost: int = SceneFactory.get_tower_cost(tower_type)
		var can_afford: bool = GameData.coins >= cost
		card.modulate.a = 1.0 if can_afford else 0.5
