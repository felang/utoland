extends CanvasLayer
## 底部商店面板覆盖层

signal start_battle_pressed
signal bag_item_drag_started(bag_index: int, item: Dictionary)

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
var _bag_container: HBoxContainer
var _bag_slots: Array[Button] = []

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
	_bag_container = $ShopPanel/VBoxContainer/BagRow

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
	_update_bag_display()
	_update_level_up_button()

func _update_info_bar() -> void:
	_coins_label.text = "$%d" % GameData.coins
	_level_label.text = "Lv.%d" % GameData.player_level
	var pop_current: int = GameData.deployed_weapons.size() + GameData.deployed_towers.size()
	var pop_max: int = GameConfig.shop_config.population_per_level[GameData.player_level - 1]
	_pop_label.text = "人口 %d/%d" % [pop_current, pop_max]
	_wave_label.text = "Wave %d" % GameData.current_wave

func _update_shop_slots_display() -> void:
	for i in range(4):
		if i < GameData.shop_slots.size() and not GameData.shop_slots[i].is_empty():
			var slot_data: Dictionary = GameData.shop_slots[i]
			var item_data: Resource = _get_item_data(slot_data.id)
			var name_text: String = item_data.display_name if item_data else slot_data.id
			_shop_slots[i].text = "%s $%d" % [name_text, slot_data.cost]
			_shop_slots[i].disabled = false
		else:
			_shop_slots[i].text = "已售出"
			_shop_slots[i].disabled = true

func _update_bag_display() -> void:
	for child in _bag_container.get_children():
		_bag_container.remove_child(child)
		child.queue_free()
	_bag_slots.clear()

	var bag_capacity: int = GameConfig.shop_config.bag_capacity
	for i in range(bag_capacity):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(50, 50)
		if i < GameData.bag.size():
			var item: Dictionary = GameData.bag[i]
			var stars := "★".repeat(item.level)
			btn.text = "%s%s" % [item.id, stars]
			btn.gui_input.connect(_on_bag_slot_input.bind(i))
		else:
			btn.text = ""
			btn.disabled = true
		_bag_container.add_child(btn)
		_bag_slots.append(btn)

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
	var snapshot: Array = GameData.deployed_towers.duplicate(true)
	var success: bool = _shop_manager.buy_item(slot_index)
	if success:
		_handle_merge_tower_cleanup(snapshot)
		_update_ui()

func _on_refresh_pressed() -> void:
	_shop_manager.manual_refresh()
	_update_ui()

func _on_level_up_pressed() -> void:
	GameData.buy_level_up()
	_update_ui()

func _on_start_pressed() -> void:
	start_battle_pressed.emit()

func _on_bag_slot_input(event: InputEvent, bag_index: int) -> void:
	if bag_index >= GameData.bag.size():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			GameData.sell_from_bag(bag_index)
			_update_ui()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var item: Dictionary = GameData.bag[bag_index]
			bag_item_drag_started.emit(bag_index, item)

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
