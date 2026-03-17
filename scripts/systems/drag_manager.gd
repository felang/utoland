extends Node
## 统一拖拽管理器 — 管理塔放置、移动、回收和武器卖出

enum DragSource { NONE, PLACE_TOWER, MAP_TOWER, WEAPON }

var _tower_container: Node2D
var _player: Node2D

var _is_dragging := false
var _drag_source: DragSource = DragSource.NONE
var _drag_data: Dictionary = {}
var _tower_nodes: Dictionary = {}  # deploy_id → Node2D

var _preview_node: Node2D = null
var _range_circle: Node2D = null

var _drag_original_grid_pos: Vector2i
var _drag_original_deploy_id: int = -1

var _on_placed_callback: Callable
var _on_cancelled_callback: Callable

var _recycle_area: Control = null
var _drag_weapon_index: int = -1
var _on_weapon_sold_callback: Callable
var _recycle_hint_label: Label = null
var _grid_overlay: Node2D = null

func initialize(tower_container: Node2D, player: Node2D) -> void:
	_tower_container = tower_container
	_player = player

func start_tower_placement(tower_id: String, on_placed: Callable, on_cancelled: Callable) -> void:
	if _is_dragging:
		return
	_on_placed_callback = on_placed
	_on_cancelled_callback = on_cancelled
	_drag_data = {tower_id = tower_id}
	_start_drag(DragSource.PLACE_TOWER)

func start_map_tower_drag(deploy_id: int) -> void:
	if _is_dragging:
		return
	if deploy_id not in _tower_nodes:
		return
	for entry in InventoryManager.deployed_towers:
		if entry.deploy_id == deploy_id:
			_drag_data = {deploy_id = deploy_id, item = entry}
			_drag_original_deploy_id = deploy_id
			_drag_original_grid_pos = entry.grid_pos
			_start_drag(DragSource.MAP_TOWER)
			break

func set_recycle_area(area: Control) -> void:
	_recycle_area = area

func is_over_recycle_area(global_pos: Vector2) -> bool:
	if _recycle_area == null:
		return false
	var rect := Rect2(_recycle_area.global_position, _recycle_area.size)
	return rect.has_point(global_pos)

func start_weapon_drag(weapon_index: int, on_sold: Callable) -> void:
	if _is_dragging:
		return
	_drag_weapon_index = weapon_index
	_on_weapon_sold_callback = on_sold
	_drag_data = {weapon_index = weapon_index}
	_start_drag(DragSource.WEAPON)

func _start_drag(source: DragSource) -> void:
	_is_dragging = true
	_drag_source = source
	_create_preview()
	if source in [DragSource.PLACE_TOWER, DragSource.MAP_TOWER]:
		_show_grid_overlay()
	if _player and _player.has_method("set_input_enabled"):
		_player.set_input_enabled(false)

func _viewport_to_world(viewport_pos: Vector2) -> Vector2:
	var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
	return canvas_xform.affine_inverse() * viewport_pos

func _input(event: InputEvent) -> void:
	if not _is_dragging:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_check_tower_click(_viewport_to_world(event.global_position))
		return

	if event is InputEventMouseMotion:
		_update_preview(_viewport_to_world(event.global_position), event.global_position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag(_viewport_to_world(event.global_position), event.global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_drag()

func _check_tower_click(global_pos: Vector2) -> void:
	for deploy_id in _tower_nodes:
		var tower_node: Node2D = _tower_nodes[deploy_id]
		if tower_node.global_position.distance_to(global_pos) < GameConfig.GRID_SIZE:
			start_map_tower_drag(deploy_id)
			break

func _end_drag(world_pos: Vector2, viewport_pos: Vector2 = Vector2.ZERO) -> void:
	match _drag_source:
		DragSource.PLACE_TOWER:
			_try_place_new_tower(world_pos)
		DragSource.MAP_TOWER:
			_try_move_tower(world_pos, viewport_pos)
		DragSource.WEAPON:
			_try_sell_weapon(viewport_pos)
	_cleanup_drag()

func _try_place_new_tower(global_pos: Vector2) -> void:
	var grid_pos := _world_to_grid(global_pos)
	if _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos):
		if _on_placed_callback.is_valid():
			_on_placed_callback.call(grid_pos)
		return
	if _on_cancelled_callback.is_valid():
		_on_cancelled_callback.call()

func _try_move_tower(world_pos: Vector2, viewport_pos: Vector2 = Vector2.ZERO) -> void:
	var deploy_id: int = _drag_data.deploy_id
	# 回收区检测（用视口坐标，因为回收区在 CanvasLayer 中）
	if is_over_recycle_area(viewport_pos):
		var refund: int = InventoryManager.sell_from_deployed_tower(deploy_id)
		if refund > 0:
			_remove_tower_node(deploy_id)
			return
	var grid_pos := _world_to_grid(world_pos)
	if _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos):
		if InventoryManager.move_tower(deploy_id, grid_pos):
			_tower_nodes[deploy_id].position = _grid_to_world(grid_pos)
			_tower_nodes[deploy_id].modulate.a = 1.0
			return
	# 放置失败，恢复到原始位置
	if deploy_id in _tower_nodes:
		_tower_nodes[deploy_id].position = _grid_to_world(_drag_original_grid_pos)
		_tower_nodes[deploy_id].modulate.a = 1.0

func _try_sell_weapon(viewport_pos: Vector2) -> void:
	if is_over_recycle_area(viewport_pos) and _drag_weapon_index >= 0:
		if _on_weapon_sold_callback.is_valid():
			_on_weapon_sold_callback.call(_drag_weapon_index)
	_drag_weapon_index = -1
	_on_weapon_sold_callback = Callable()

func _cancel_drag() -> void:
	if _drag_source == DragSource.MAP_TOWER and _drag_original_deploy_id >= 0:
		if _drag_original_deploy_id in _tower_nodes:
			# 恢复到原始位置
			_tower_nodes[_drag_original_deploy_id].position = _grid_to_world(_drag_original_grid_pos)
			_tower_nodes[_drag_original_deploy_id].modulate.a = 1.0
	elif _drag_source == DragSource.PLACE_TOWER:
		if _on_cancelled_callback.is_valid():
			_on_cancelled_callback.call()
	_cleanup_drag()

func _cleanup_drag() -> void:
	_is_dragging = false
	_drag_source = DragSource.NONE
	_drag_data = {}
	_drag_original_deploy_id = -1
	_on_placed_callback = Callable()
	_on_cancelled_callback = Callable()
	if _preview_node:
		_preview_node.queue_free()
		_preview_node = null
	_range_circle = null  # _range_circle 是 _preview_node 的子节点，随父节点释放
	_hide_grid_overlay()
	if _recycle_area:
		_recycle_area.modulate = Color.WHITE
	_hide_recycle_hint()
	_drag_weapon_index = -1
	_on_weapon_sold_callback = Callable()
	if _player and _player.has_method("set_input_enabled"):
		_player.set_input_enabled(true)

func spawn_tower_node(deploy_id: int, tower_id: String, level: int, grid_pos: Vector2i) -> void:
	var tower: Node2D = SceneFactory.create_tower(tower_id, level)
	tower.position = _grid_to_world(grid_pos)
	_tower_container.add_child(tower)
	_tower_nodes[deploy_id] = tower

func upgrade_tower_node(deploy_id: int, tower_id: String, new_level: int, grid_pos: Vector2i) -> void:
	_remove_tower_node(deploy_id)
	spawn_tower_node(deploy_id, tower_id, new_level, grid_pos)

func _remove_tower_node(deploy_id: int) -> void:
	if deploy_id in _tower_nodes:
		_tower_nodes[deploy_id].queue_free()
		_tower_nodes.erase(deploy_id)

func remove_tower_nodes(consumed_deploy_ids: Array) -> void:
	for deploy_id in consumed_deploy_ids:
		_remove_tower_node(deploy_id)

func _create_preview() -> void:
	_preview_node = Node2D.new()
	if _drag_source == DragSource.PLACE_TOWER:
		var tower_id: String = _drag_data.tower_id
		# 用实际塔场景作为半透明预览
		var tower_preview: Node2D = SceneFactory.create_tower(tower_id, 1)
		tower_preview.modulate = Color(1, 1, 1, 0.5)
		tower_preview.set_process(false)
		tower_preview.set_physics_process(false)
		_preview_node.add_child(tower_preview)
		# 攻击范围指示圆
		var tower_data: TowerData = GameConfig.towers.get(tower_id)
		if tower_data and tower_data.attack_range_per_level.size() > 0:
			_range_circle = RangeIndicator.new()
			_range_circle.set_range(tower_data.attack_range_per_level[0])
			_preview_node.add_child(_range_circle)
	elif _drag_source == DragSource.MAP_TOWER:
		# 移动已有塔：直接拖拽实际塔节点，只显示范围圆
		var deploy_id: int = _drag_data.get("deploy_id", -1)
		for entry in InventoryManager.deployed_towers:
			if entry.deploy_id == deploy_id:
				var tower_data: TowerData = GameConfig.towers.get(entry.id)
				if tower_data and tower_data.attack_range_per_level.size() >= entry.level:
					_range_circle = RangeIndicator.new()
					_range_circle.set_range(tower_data.attack_range_per_level[entry.level - 1])
					_preview_node.add_child(_range_circle)
				break
	# 初始隐藏，等第一次 _update_preview 设置正确位置后才可见，避免闪烁
	_preview_node.visible = false
	_tower_container.get_parent().add_child(_preview_node)

func _update_preview(world_pos: Vector2, viewport_pos: Vector2 = Vector2.ZERO) -> void:
	if _preview_node == null:
		return
	if _drag_source == DragSource.PLACE_TOWER:
		var grid_pos := _world_to_grid(world_pos)
		_preview_node.global_position = _grid_to_world(grid_pos)
		_preview_node.visible = true
		var is_valid := _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos)
		if _range_circle:
			_range_circle.modulate = Color(0.3, 1.0, 0.3, 1.0) if is_valid else Color(1.0, 0.3, 0.3, 1.0)
	elif _drag_source == DragSource.MAP_TOWER:
		# 直接移动实际塔节点
		var grid_pos := _world_to_grid(world_pos)
		var snapped_pos := _grid_to_world(grid_pos)
		var deploy_id: int = _drag_data.deploy_id
		if deploy_id in _tower_nodes:
			_tower_nodes[deploy_id].position = snapped_pos
			_tower_nodes[deploy_id].modulate.a = 1.0
		# 范围圆跟随
		_preview_node.global_position = snapped_pos
		_preview_node.visible = true
		var is_valid := _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos)
		if _range_circle:
			_range_circle.modulate = Color(0.3, 1.0, 0.3, 1.0) if is_valid else Color(1.0, 0.3, 0.3, 1.0)
	else:
		_preview_node.global_position = world_pos
		_preview_node.visible = true
	# 回收区反馈（用视口坐标，回收区在 CanvasLayer 中）
	if _recycle_area and _drag_source in [DragSource.MAP_TOWER, DragSource.WEAPON]:
		if is_over_recycle_area(viewport_pos):
			_recycle_area.modulate = Color(1, 0.3, 0.3)
			_update_recycle_hint(viewport_pos)
		else:
			_recycle_area.modulate = Color.WHITE
			_hide_recycle_hint()

func _update_recycle_hint(_global_pos: Vector2) -> void:
	var refund: int = _get_drag_refund()
	if refund <= 0:
		return
	if _recycle_hint_label == null:
		_recycle_hint_label = Label.new()
		_recycle_hint_label.add_theme_font_size_override("font_size", 12)
		_recycle_area.add_child(_recycle_hint_label)
	_recycle_hint_label.text = "$%d" % refund
	_recycle_hint_label.visible = true

func _hide_recycle_hint() -> void:
	if _recycle_hint_label:
		_recycle_hint_label.visible = false

func _get_drag_refund() -> int:
	match _drag_source:
		DragSource.MAP_TOWER:
			var deploy_id: int = _drag_data.get("deploy_id", -1)
			for entry in InventoryManager.deployed_towers:
				if entry.deploy_id == deploy_id:
					var data: Resource = GameConfig.towers.get(entry.id)
					if data:
						return data.sell_price_per_level[entry.level - 1]
			return 0
		DragSource.WEAPON:
			var weapon_index: int = _drag_data.get("weapon_index", -1)
			if weapon_index >= 0 and weapon_index < InventoryManager.deployed_weapons.size():
				var entry: Dictionary = InventoryManager.deployed_weapons[weapon_index]
				var data: Resource = GameConfig.weapons.get(entry.id)
				if data:
					return data.sell_price_per_level[entry.level - 1]
			return 0
		_:
			return 0

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2.0 - GameConfig.MAP_HALF_WIDTH,
		(grid_pos.y + 1) * GameConfig.GRID_SIZE - GameConfig.MAP_HALF_HEIGHT
	)

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int((world_pos.x + GameConfig.MAP_HALF_WIDTH) / GameConfig.GRID_SIZE),
		int((world_pos.y + GameConfig.MAP_HALF_HEIGHT) / GameConfig.GRID_SIZE)
	)

func _is_valid_grid_pos(grid_pos: Vector2i) -> bool:
	return (grid_pos.x >= 0 and grid_pos.x < GameConfig.MAP_GRID_WIDTH
		and grid_pos.y >= 0 and grid_pos.y < GameConfig.MAP_GRID_HEIGHT)

func _is_grid_available(grid_pos: Vector2i) -> bool:
	for entry in InventoryManager.deployed_towers:
		if entry.grid_pos == grid_pos:
			if _drag_source == DragSource.MAP_TOWER and entry.deploy_id == _drag_original_deploy_id:
				continue
			return false
	return true

func _show_grid_overlay() -> void:
	if _grid_overlay == null:
		_grid_overlay = GridOverlay.new()
		_grid_overlay.z_index = 1
		_tower_container.get_parent().add_child(_grid_overlay)
	_grid_overlay.visible = true

func _hide_grid_overlay() -> void:
	if _grid_overlay:
		_grid_overlay.visible = false
