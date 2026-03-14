extends Node
## 统一拖拽管理器 — 管理背包物品部署和地图上塔的移动

enum DragSource { NONE, BAG_TOWER, BAG_WEAPON, MAP_TOWER }

const WEAPON_EQUIP_RADIUS := 48.0

var _tower_container: Node2D
var _player: Node2D
var _shop_overlay: CanvasLayer

var _is_dragging := false
var _drag_source: DragSource = DragSource.NONE
var _drag_data: Dictionary = {}
var _tower_nodes: Dictionary = {}  # deploy_id → Node2D

var _preview_node: Node2D = null
var _range_circle: Node2D = null

var _drag_original_grid_pos: Vector2i
var _drag_original_deploy_id: int = -1

func initialize(tower_container: Node2D, player: Node2D, shop_overlay: CanvasLayer) -> void:
	_tower_container = tower_container
	_player = player
	_shop_overlay = shop_overlay
	shop_overlay.bag_item_drag_started.connect(_on_bag_item_drag_started)

func _on_bag_item_drag_started(bag_index: int, item: Dictionary) -> void:
	if _is_dragging:
		return
	_drag_data = {bag_index = bag_index, item = item}
	if item.type == "tower":
		_start_drag(DragSource.BAG_TOWER)
	elif item.type == "weapon":
		_start_drag(DragSource.BAG_WEAPON)

func start_map_tower_drag(deploy_id: int) -> void:
	if _is_dragging:
		return
	if deploy_id not in _tower_nodes:
		return
	for entry in GameData.deployed_towers:
		if entry.deploy_id == deploy_id:
			_drag_data = {deploy_id = deploy_id, item = entry}
			_drag_original_deploy_id = deploy_id
			_drag_original_grid_pos = entry.grid_pos
			_start_drag(DragSource.MAP_TOWER)
			_tower_nodes[deploy_id].modulate.a = 0.3
			break

func _start_drag(source: DragSource) -> void:
	_is_dragging = true
	_drag_source = source
	_create_preview()
	if _player and _player.has_method("set_input_enabled"):
		_player.set_input_enabled(false)

func _input(event: InputEvent) -> void:
	if not _is_dragging:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_check_tower_click(event.global_position)
		return

	if event is InputEventMouseMotion:
		_update_preview(event.global_position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag(event.global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_drag()

func _check_tower_click(global_pos: Vector2) -> void:
	for deploy_id in _tower_nodes:
		var tower_node: Node2D = _tower_nodes[deploy_id]
		if tower_node.global_position.distance_to(global_pos) < GameConfig.GRID_SIZE:
			start_map_tower_drag(deploy_id)
			break

func _end_drag(global_pos: Vector2) -> void:
	match _drag_source:
		DragSource.BAG_TOWER:
			_try_deploy_tower(global_pos)
		DragSource.BAG_WEAPON:
			_try_equip_weapon(global_pos)
		DragSource.MAP_TOWER:
			_try_move_or_undeploy_tower(global_pos)
	_cleanup_drag()

func _cancel_drag() -> void:
	if _drag_source == DragSource.MAP_TOWER and _drag_original_deploy_id >= 0:
		if _drag_original_deploy_id in _tower_nodes:
			_tower_nodes[_drag_original_deploy_id].modulate.a = 1.0
	_cleanup_drag()

func _cleanup_drag() -> void:
	_is_dragging = false
	_drag_source = DragSource.NONE
	_drag_data = {}
	_drag_original_deploy_id = -1
	if _preview_node:
		_preview_node.queue_free()
		_preview_node = null
	if _range_circle:
		_range_circle.queue_free()
		_range_circle = null
	if _player and _player.has_method("set_input_enabled"):
		_player.set_input_enabled(true)

func _try_deploy_tower(global_pos: Vector2) -> void:
	var grid_pos := _world_to_grid(global_pos)
	if not _is_valid_grid_pos(grid_pos) or not _is_grid_available(grid_pos):
		return
	var bag_index: int = _drag_data.bag_index
	var item: Dictionary = _drag_data.item
	var deploy_id: int = GameData.deploy_tower(bag_index, grid_pos)
	if deploy_id > 0:
		_spawn_tower_node(deploy_id, item.id, item.level, grid_pos)
		_shop_overlay._update_ui()

func _try_equip_weapon(global_pos: Vector2) -> void:
	if _player == null:
		return
	var distance := global_pos.distance_to(_player.global_position)
	if distance <= WEAPON_EQUIP_RADIUS:
		var bag_index: int = _drag_data.bag_index
		GameData.deploy_weapon(bag_index)
		_shop_overlay._update_ui()

func _try_move_or_undeploy_tower(global_pos: Vector2) -> void:
	var deploy_id: int = _drag_data.deploy_id
	if _is_over_panel(global_pos):
		if GameData.undeploy_tower(deploy_id):
			_remove_tower_node(deploy_id)
			_shop_overlay._update_ui()
			return
	var grid_pos := _world_to_grid(global_pos)
	if _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos):
		if GameData.move_tower(deploy_id, grid_pos):
			_tower_nodes[deploy_id].position = _grid_to_world(grid_pos)
			_tower_nodes[deploy_id].modulate.a = 1.0
			return
	if deploy_id in _tower_nodes:
		_tower_nodes[deploy_id].modulate.a = 1.0

func _spawn_tower_node(deploy_id: int, tower_id: String, level: int, grid_pos: Vector2i) -> void:
	var tower: Node2D = SceneFactory.create_tower(tower_id, level)
	tower.position = _grid_to_world(grid_pos)
	_tower_container.add_child(tower)
	_tower_nodes[deploy_id] = tower

func _remove_tower_node(deploy_id: int) -> void:
	if deploy_id in _tower_nodes:
		_tower_nodes[deploy_id].queue_free()
		_tower_nodes.erase(deploy_id)

func remove_tower_nodes(consumed_deploy_ids: Array) -> void:
	for deploy_id in consumed_deploy_ids:
		_remove_tower_node(deploy_id)

func _create_preview() -> void:
	_preview_node = Node2D.new()
	var sprite := Sprite2D.new()
	sprite.modulate = Color(1, 1, 1, 0.5)
	_preview_node.add_child(sprite)
	if _drag_source in [DragSource.BAG_TOWER, DragSource.MAP_TOWER]:
		_range_circle = Node2D.new()
		_preview_node.add_child(_range_circle)
	_tower_container.get_parent().add_child(_preview_node)

func _update_preview(global_pos: Vector2) -> void:
	if _preview_node == null:
		return
	if _drag_source in [DragSource.BAG_TOWER, DragSource.MAP_TOWER]:
		var grid_pos := _world_to_grid(global_pos)
		_preview_node.global_position = _grid_to_world(grid_pos)
		var is_valid := _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos)
		if _range_circle:
			_range_circle.modulate = Color.GREEN if is_valid else Color.RED
	else:
		_preview_node.global_position = global_pos

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2.0,
		grid_pos.y * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2.0
	)

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / GameConfig.GRID_SIZE),
		int(world_pos.y / GameConfig.GRID_SIZE)
	)

func _is_valid_grid_pos(grid_pos: Vector2i) -> bool:
	return (grid_pos.x >= 0 and grid_pos.x < GameConfig.MAP_GRID_WIDTH
		and grid_pos.y >= 0 and grid_pos.y < GameConfig.MAP_GRID_HEIGHT)

func _is_grid_available(grid_pos: Vector2i) -> bool:
	for entry in GameData.deployed_towers:
		if entry.grid_pos == grid_pos:
			if _drag_source == DragSource.MAP_TOWER and entry.deploy_id == _drag_original_deploy_id:
				continue
			return false
	return true

func _is_over_panel(global_pos: Vector2) -> bool:
	var panel: PanelContainer = _shop_overlay._panel
	var panel_rect: Rect2 = panel.get_global_rect()
	return panel_rect.has_point(global_pos)
