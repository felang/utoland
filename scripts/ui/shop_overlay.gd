extends CanvasLayer
## 底部商店面板覆盖层

signal start_battle_pressed

const SLIDE_DURATION := 0.3

var _shop_manager: ShopManager
var _panel: PanelContainer
var _slide_original_y: float = 0.0

var _coins_label: Label
var _level_label: Label
var _pop_label: Label
var _wave_label: Label
var _level_up_button: Button
var _refresh_button: Button
var _start_button: Button
var _shop_slots: Array[Button] = []

var _pending_tower_slot_index: int = -1

# 由 main.gd 注入
var drag_manager: Node = null

func _ready() -> void:
	layer = 10
	_shop_manager = ShopManager.new()
	_setup_ui()
	_update_ui()

func _setup_ui() -> void:
	_panel = $ShopPanel
	_slide_original_y = _panel.position.y
	_coins_label = $ShopPanel/VBoxContainer/TopRow/CoinsLabel
	_level_label = $ShopPanel/VBoxContainer/TopRow/LevelLabel
	_pop_label = $ShopPanel/VBoxContainer/TopRow/PopLabel
	_wave_label = $ShopPanel/VBoxContainer/TopRow/WaveLabel
	_level_up_button = $ShopPanel/VBoxContainer/TopRow/LevelUpButton
	_refresh_button = $ShopPanel/VBoxContainer/TopRow/RefreshButton
	_start_button = $ShopPanel/VBoxContainer/TopRow/StartButton

	_level_up_button.pressed.connect(_on_level_up_pressed)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_start_button.pressed.connect(_on_start_pressed)

	for i in range(4):
		var slot: Button = $ShopPanel/VBoxContainer/ShopRow.get_child(i)
		slot.pressed.connect(_on_shop_slot_pressed.bind(i))
		_shop_slots.append(slot)

func refresh_shop(is_first: bool = false) -> void:
	_shop_manager.refresh_shop(is_first)
	_update_ui()

func _update_ui() -> void:
	_update_info_bar()
	_update_shop_slots_display()
	_update_level_up_button()

func _update_info_bar() -> void:
	_coins_label.text = "$%d" % GameData.coins
	_level_label.text = "Lv.%d" % GameData.player_level
	var pop_current: int = GameData.deployed_weapons.size() + GameData.deployed_towers.size()
	var pop_max: int = GameConfig.shop_config.population_per_level[GameData.player_level - 1]
	_pop_label.text = "人口 %d/%d" % [pop_current, pop_max]
	_wave_label.text = "Wave %d" % GameData.current_wave

func _update_shop_slots_display() -> void:
	var pop_full: bool = not GameData.can_deploy()
	for i in range(4):
		if i < GameData.shop_slots.size() and not GameData.shop_slots[i].is_empty():
			var slot_data: Dictionary = GameData.shop_slots[i]
			var item_data: Resource = _get_item_data(slot_data.id)
			var name_text: String = item_data.display_name if item_data else slot_data.id
			_shop_slots[i].text = "%s $%d" % [name_text, slot_data.cost]
			_shop_slots[i].disabled = GameData.coins < slot_data.cost or pop_full
		else:
			_shop_slots[i].text = "已售出"
			_shop_slots[i].disabled = true

func _update_level_up_button() -> void:
	var max_level: int = GameConfig.shop_config.level_up_costs.size() + 1
	if GameData.player_level >= max_level:
		_level_up_button.text = "满级"
		_level_up_button.disabled = true
	else:
		var cost: int = GameConfig.shop_config.level_up_costs[GameData.player_level - 1]
		_level_up_button.text = "Lv↑ $%d" % cost
		_level_up_button.disabled = GameData.coins < cost

func _on_shop_slot_pressed(slot_index: int) -> void:
	var slot: Dictionary = GameData.shop_slots[slot_index]
	if slot.is_empty():
		return
	if slot.type == "weapon":
		var snapshot: Array = GameData.deployed_weapons.duplicate(true)
		var success: bool = _shop_manager.buy_weapon(slot_index)
		if success:
			_handle_merge_weapon_cleanup()
			_update_ui()
	elif slot.type == "tower":
		var tower_slot: Dictionary = _shop_manager.get_tower_slot(slot_index)
		if not tower_slot.is_empty():
			_pending_tower_slot_index = slot_index
			drag_manager.start_tower_placement(
				tower_slot.id,
				_on_tower_placed,
				_on_tower_placement_cancelled
			)

func _on_tower_placed(grid_pos: Vector2i) -> void:
	if _pending_tower_slot_index < 0:
		return
	var slot: Dictionary = GameData.shop_slots[_pending_tower_slot_index]
	var tower_id: String = slot.id if not slot.is_empty() else ""
	var snapshot: Array = GameData.deployed_towers.duplicate(true)
	var deploy_id: int = _shop_manager.confirm_tower_purchase(_pending_tower_slot_index, grid_pos)
	if deploy_id > 0:
		drag_manager.spawn_tower_node(deploy_id, tower_id, 1, grid_pos)
		_handle_merge_tower_cleanup(snapshot)
	_pending_tower_slot_index = -1
	_update_ui()

func _on_tower_placement_cancelled() -> void:
	_pending_tower_slot_index = -1

func _on_refresh_pressed() -> void:
	_shop_manager.manual_refresh()
	_update_ui()

func _on_level_up_pressed() -> void:
	GameData.buy_level_up()
	_update_ui()

func _on_start_pressed() -> void:
	start_battle_pressed.emit()

func slide_out() -> void:
	var tween := create_tween()
	var panel_height: float = _panel.size.y
	tween.tween_property(_panel, "position:y", _slide_original_y + panel_height, SLIDE_DURATION)
	tween.tween_callback(func(): _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func slide_in() -> void:
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.position.y = _slide_original_y + _panel.size.y
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", _slide_original_y, SLIDE_DURATION)
	_update_ui()

func _handle_merge_weapon_cleanup() -> void:
	pass  # 武器合成后下次战斗开始时重新初始化

func _handle_merge_tower_cleanup(snapshot: Array) -> void:
	if drag_manager == null:
		return
	var current_ids: Array[int] = []
	for entry in GameData.deployed_towers:
		current_ids.append(entry.deploy_id)
	var consumed_ids: Array[int] = []
	for entry in snapshot:
		if entry.deploy_id not in current_ids:
			consumed_ids.append(entry.deploy_id)
	if consumed_ids.size() > 0:
		drag_manager.remove_tower_nodes(consumed_ids)

func _get_item_data(item_id: String) -> Resource:
	if GameConfig.weapons.has(item_id):
		return GameConfig.weapons[item_id]
	if GameConfig.towers.has(item_id):
		return GameConfig.towers[item_id]
	return null
