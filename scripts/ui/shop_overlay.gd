extends CanvasLayer
## 底部商店面板覆盖层 — 卡片式 UI

signal start_battle_pressed

const SLIDE_DURATION := 0.3
const CARD_ICON_SIZE := Vector2(32, 32)

var _shop_manager: ShopManager
var _panel: PanelContainer
var _slide_original_y: float = 0.0

# 信息栏
var _coins_label: Label
var _level_label: Label
var _pop_label: Label
var _wave_label: Label

# 操作按钮
var _level_up_button: Button
var _refresh_button: Button
var _start_button: Button

# 卡片
var _card_containers: Array[PanelContainer] = []
var _card_icons: Array[TextureRect] = []
var _card_names: Array[Label] = []
var _card_prices: Array[Label] = []
var _card_buttons: Array[Button] = []

# 回收区
var _recycle_area: PanelContainer

# 放置状态
var _pending_tower_slot_index: int = -1

# 外部注入
var drag_manager: Node = null
var weapon_manager: WeaponManager = null

func _ready() -> void:
	layer = 10
	_shop_manager = ShopManager.new()
	_setup_ui()
	_update_ui()

func _setup_ui() -> void:
	_panel = $ShopPanel
	_slide_original_y = _panel.position.y

	# 信息栏
	_coins_label = $ShopPanel/VBoxContainer/TopRow/CoinsLabel
	_level_label = $ShopPanel/VBoxContainer/TopRow/LevelLabel
	_pop_label = $ShopPanel/VBoxContainer/TopRow/PopLabel
	_wave_label = $ShopPanel/VBoxContainer/TopRow/WaveLabel

	# BottomRow
	var bottom_row: HBoxContainer = $ShopPanel/VBoxContainer/BottomRow

	# 动态创建 4 张卡片
	var card_container := HBoxContainer.new()
	card_container.name = "CardContainer"
	card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_container.add_theme_constant_override("separation", 4)
	bottom_row.add_child(card_container)

	for i in range(4):
		var card := _create_card(i)
		card_container.add_child(card)

	# 按钮容器
	var btn_container := VBoxContainer.new()
	btn_container.name = "ButtonContainer"
	bottom_row.add_child(btn_container)

	_refresh_button = Button.new()
	_refresh_button.text = "刷新 $2"
	_refresh_button.pressed.connect(_on_refresh_pressed)
	btn_container.add_child(_refresh_button)

	_level_up_button = Button.new()
	_level_up_button.text = "Lv↑"
	_level_up_button.pressed.connect(_on_level_up_pressed)
	btn_container.add_child(_level_up_button)

	# 回收区
	_recycle_area = PanelContainer.new()
	_recycle_area.name = "RecycleArea"
	_recycle_area.custom_minimum_size = Vector2(50, 50)
	var recycle_label := Label.new()
	recycle_label.text = "回收"
	recycle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recycle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_recycle_area.add_child(recycle_label)
	bottom_row.add_child(_recycle_area)

	# 开战按钮
	_start_button = Button.new()
	_start_button.text = "开战"
	_start_button.pressed.connect(_on_start_pressed)
	bottom_row.add_child(_start_button)

func _create_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ShopCard%d" % index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(60, 80)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = CARD_ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon)
	_card_icons.append(icon)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(name_label)
	_card_names.append(name_label)

	var price_label := Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(price_label)
	_card_prices.append(price_label)

	# 透明点击按钮覆盖整个卡片
	var btn := Button.new()
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_shop_slot_pressed.bind(index))
	card.add_child(btn)
	_card_buttons.append(btn)

	_card_containers.append(card)
	return card

func refresh_shop(is_first: bool = false) -> void:
	_shop_manager.refresh_shop(is_first)
	_update_ui()

func _update_ui() -> void:
	_update_info_bar()
	_update_cards()
	_update_level_up_button()

func _update_info_bar() -> void:
	_coins_label.text = "$%d" % GameData.coins
	_level_label.text = "Lv.%d" % GameData.player_level
	var pop_current: int = GameData.deployed_weapons.size() + GameData.deployed_towers.size()
	var pop_max: int = GameConfig.shop_config.population_per_level[GameData.player_level - 1]
	_pop_label.text = "人口 %d/%d" % [pop_current, pop_max]
	_wave_label.text = "Wave %d" % GameData.current_wave

func _update_cards() -> void:
	var is_placing: bool = _pending_tower_slot_index >= 0
	for i in range(4):
		if i < GameData.shop_slots.size() and not GameData.shop_slots[i].is_empty():
			var slot_data: Dictionary = GameData.shop_slots[i]
			var item_data: Resource = _get_item_data(slot_data.id)

			# 图标
			if item_data and item_data.icon_path != "" and ResourceLoader.exists(item_data.icon_path):
				_card_icons[i].texture = load(item_data.icon_path)
			else:
				_card_icons[i].texture = null

			# 名称
			_card_names[i].text = item_data.display_name if item_data else slot_data.id

			# 价格
			_card_prices[i].text = "$%d" % slot_data.cost

			# 禁用判断
			var can_buy: bool = GameData.coins >= slot_data.cost and GameData.can_buy_item(slot_data.id, 1)
			_card_buttons[i].disabled = not can_buy or is_placing

			# 放置中状态
			if is_placing and i == _pending_tower_slot_index:
				_card_names[i].text = "放置中"
				_card_buttons[i].disabled = true

			# 卡片视觉
			_card_containers[i].modulate = Color.WHITE if (can_buy and not is_placing) else Color(0.5, 0.5, 0.5)
		else:
			_card_icons[i].texture = null
			_card_names[i].text = "已售出"
			_card_prices[i].text = ""
			_card_buttons[i].disabled = true
			_card_containers[i].modulate = Color(0.5, 0.5, 0.5)

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
		var success: bool = _shop_manager.buy_weapon(slot_index)
		if success:
			_handle_merge_weapon_cleanup()
			_update_ui()
	elif slot.type == "tower":
		var tower_slot: Dictionary = _shop_manager.get_tower_slot(slot_index)
		if not tower_slot.is_empty():
			_pending_tower_slot_index = slot_index
			_update_cards()
			_start_button.disabled = true
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
	_start_button.disabled = false
	_update_ui()

func _on_tower_placement_cancelled() -> void:
	_pending_tower_slot_index = -1
	_start_button.disabled = false
	_update_ui()

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
	if weapon_manager:
		weapon_manager.refresh_weapons()

func _handle_merge_tower_cleanup(snapshot: Array) -> void:
	if drag_manager == null:
		return
	var current_ids: Array[int] = []
	var current_map: Dictionary = {}
	for entry in GameData.deployed_towers:
		current_ids.append(entry.deploy_id)
		current_map[entry.deploy_id] = entry

	# 移除被合成消耗的塔节点
	var consumed_ids: Array[int] = []
	for entry in snapshot:
		if entry.deploy_id not in current_ids:
			consumed_ids.append(entry.deploy_id)
	if consumed_ids.size() > 0:
		drag_manager.remove_tower_nodes(consumed_ids)

	# 升级存活塔的视觉
	for entry in GameData.deployed_towers:
		for old_entry in snapshot:
			if old_entry.deploy_id == entry.deploy_id and old_entry.level != entry.level:
				drag_manager.upgrade_tower_node(entry.deploy_id, entry.id, entry.level, entry.grid_pos)
				break

func _on_weapon_sold(weapon_index: int) -> void:
	var refund: int = GameData.sell_from_deployed_weapon(weapon_index)
	if refund > 0 and weapon_manager:
		weapon_manager.remove_weapon(weapon_index)
	_update_ui()

func get_recycle_area() -> Control:
	return _recycle_area

func _get_item_data(item_id: String) -> Resource:
	if GameConfig.weapons.has(item_id):
		return GameConfig.weapons[item_id]
	if GameConfig.towers.has(item_id):
		return GameConfig.towers[item_id]
	return null
