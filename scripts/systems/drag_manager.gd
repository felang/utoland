extends Node
## 统一拖拽管理器 — 管理塔放置和移动

enum DragSource { NONE, PLACE_TOWER, MOVE_TOWER }

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

var _grid_overlay: Node2D = null
var _is_shop_mode: bool = false

var _tower_menu: PopupMenu = null
var _menu_deploy_id: int = -1

func initialize(_entity_layer: Node2D, player: Node2D) -> void:
	_player = player

func set_shop_mode(enabled: bool) -> void:
	_is_shop_mode = enabled

func start_tower_placement(tower_id: String, on_placed: Callable, on_cancelled: Callable) -> void:
	if _is_dragging:
		return
	_on_placed_callback = on_placed
	_on_cancelled_callback = on_cancelled
	_drag_data = {tower_id = tower_id}
	_start_drag(DragSource.PLACE_TOWER)

func start_move_tower(deploy_id: int) -> void:
	if _is_dragging:
		return
	if deploy_id not in _tower_nodes:
		return
	for entry in InventoryManager.deployed_towers:
		if entry.deploy_id == deploy_id:
			_drag_data = {deploy_id = deploy_id, item = entry}
			_drag_original_deploy_id = deploy_id
			_drag_original_grid_pos = entry.grid_pos
			_start_drag(DragSource.MOVE_TOWER)
			break

func _start_drag(source: DragSource) -> void:
	_is_dragging = true
	_drag_source = source
	_create_preview()
	if source in [DragSource.PLACE_TOWER, DragSource.MOVE_TOWER]:
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
	if not _is_shop_mode:
		return
	for deploy_id in _tower_nodes:
		var tower_node: Node2D = _tower_nodes[deploy_id]
		if tower_node.global_position.distance_to(global_pos) < GameConfig.GRID_SIZE:
			_show_tower_menu(deploy_id)
			break

func _show_tower_menu(deploy_id: int) -> void:
	_menu_deploy_id = deploy_id
	if _tower_menu == null:
		_tower_menu = PopupMenu.new()
		_tower_menu.name = "TowerMenu"
		_tower_menu.id_pressed.connect(_on_tower_menu_pressed)
		add_child(_tower_menu)
	_tower_menu.clear()
	var entry: Dictionary = {}
	for t in InventoryManager.deployed_towers:
		if t.deploy_id == deploy_id:
			entry = t
			break
	if entry.is_empty():
		return
	# 合成选项
	var has_pair: bool = false
	for t in InventoryManager.deployed_towers:
		if t.deploy_id != deploy_id and t.id == entry.id and t.level == entry.level and entry.level < 3:
			has_pair = true
			break
	if has_pair:
		_tower_menu.add_item("合成", 0)
	# 卖出选项
	var tower_data: TowerData = GameConfig.towers.get(entry.id)
	var refund: int = tower_data.sell_price_per_level[entry.level - 1] if tower_data else 0
	_tower_menu.add_item("卖出 $%d" % refund, 1)
	# 移动选项
	_tower_menu.add_item("移动", 2)
	var tower_node: Node2D = _tower_nodes[deploy_id]
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * tower_node.global_position
	_tower_menu.position = Vector2i(int(screen_pos.x), int(screen_pos.y) - 60)
	_tower_menu.popup()

func _on_tower_menu_pressed(id: int) -> void:
	var deploy_id: int = _menu_deploy_id
	match id:
		0:  # 合成
			var old_towers: Array = InventoryManager.deployed_towers.duplicate(true)
			if InventoryManager.merge_tower(deploy_id):
				_handle_tower_merge_visual(deploy_id, old_towers)
		1:  # 卖出
			var refund: int = InventoryManager.sell_from_deployed_tower(deploy_id)
			if refund > 0:
				_remove_tower_node(deploy_id)
		2:  # 移动
			start_move_tower(deploy_id)
	_menu_deploy_id = -1

func _handle_tower_merge_visual(kept_deploy_id: int, old_towers: Array) -> void:
	var current_ids: Array[int] = []
	for entry in InventoryManager.deployed_towers:
		current_ids.append(entry.deploy_id)
	for entry in old_towers:
		if entry.deploy_id not in current_ids:
			_remove_tower_node(entry.deploy_id)
	for entry in InventoryManager.deployed_towers:
		if entry.deploy_id == kept_deploy_id:
			upgrade_tower_node(entry.deploy_id, entry.id, entry.level, entry.grid_pos)
			break

func _end_drag(world_pos: Vector2, _viewport_pos: Vector2 = Vector2.ZERO) -> void:
	match _drag_source:
		DragSource.PLACE_TOWER:
			_try_place_new_tower(world_pos)
		DragSource.MOVE_TOWER:
			_try_move_tower(world_pos)
	_cleanup_drag()

func _try_place_new_tower(global_pos: Vector2) -> void:
	var grid_pos := _world_to_grid(global_pos)
	if _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos):
		if _on_placed_callback.is_valid():
			_on_placed_callback.call(grid_pos)
		return
	if _on_cancelled_callback.is_valid():
		_on_cancelled_callback.call()

func _try_move_tower(world_pos: Vector2) -> void:
	var deploy_id: int = _drag_data.deploy_id
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

func _cancel_drag() -> void:
	if _drag_source == DragSource.MOVE_TOWER and _drag_original_deploy_id >= 0:
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
	if _player and _player.has_method("set_input_enabled"):
		_player.set_input_enabled(true)

func spawn_tower_node(deploy_id: int, tower_id: String, level: int, grid_pos: Vector2i) -> void:
	var tower: Node2D = SceneFactory.create_tower(tower_id, level)
	tower.position = _grid_to_world(grid_pos)
	SceneFactory.get_entity_layer().add_child(tower)
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
		if tower_data and tower_data.attack_config != null and tower_data.attack_config.attack_range_per_level.size() > 0:
			_range_circle = RangeIndicator.new()
			_range_circle.set_range(tower_data.attack_config.attack_range_per_level[0])
			_preview_node.add_child(_range_circle)
	elif _drag_source == DragSource.MOVE_TOWER:
		# 移动已有塔：直接拖拽实际塔节点，只显示范围圆
		var deploy_id: int = _drag_data.get("deploy_id", -1)
		for entry in InventoryManager.deployed_towers:
			if entry.deploy_id == deploy_id:
				var tower_data: TowerData = GameConfig.towers.get(entry.id)
				if tower_data and tower_data.attack_config != null and tower_data.attack_config.attack_range_per_level.size() >= entry.level:
					_range_circle = RangeIndicator.new()
					_range_circle.set_range(tower_data.attack_config.attack_range_per_level[entry.level - 1])
					_preview_node.add_child(_range_circle)
				break
	# 初始隐藏，等第一次 _update_preview 设置正确位置后才可见，避免闪烁
	_preview_node.visible = false
	SceneFactory.get_entity_layer().add_child(_preview_node)

func _update_preview(world_pos: Vector2, _viewport_pos: Vector2 = Vector2.ZERO) -> void:
	if _preview_node == null:
		return
	if _drag_source == DragSource.PLACE_TOWER:
		var grid_pos := _world_to_grid(world_pos)
		_preview_node.global_position = _grid_to_world(grid_pos)
		_preview_node.visible = true
		var is_valid := _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos)
		if _range_circle:
			_range_circle.modulate = Color(0.3, 1.0, 0.3, 1.0) if is_valid else Color(1.0, 0.3, 0.3, 1.0)
	elif _drag_source == DragSource.MOVE_TOWER:
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
			if _drag_source == DragSource.MOVE_TOWER and entry.deploy_id == _drag_original_deploy_id:
				continue
			return false
	return true

func _show_grid_overlay() -> void:
	if _grid_overlay == null:
		_grid_overlay = GridOverlay.new()
		_grid_overlay.z_index = 1
		SceneFactory.get_entity_layer().get_parent().add_child(_grid_overlay)
	_grid_overlay.visible = true

func _hide_grid_overlay() -> void:
	if _grid_overlay:
		_grid_overlay.visible = false
