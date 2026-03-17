extends CanvasLayer
## 左侧商店面板覆盖层 — 纵向卡片式 UI

signal start_battle_pressed

const SLIDE_DURATION := 0.3
const CARD_ICON_SIZE := Vector2(16, 16)

var _shop_manager: ShopManager
var _panel: PanelContainer
var _slide_original_x: float = 0.0

# 信息栏
var _coins_label: Label
var _level_label: Label
var _pop_label: Label
var _wave_label: Label

# 操作按钮
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
	# 监听卖出事件刷新 UI（回收区卖出由 DragManager 触发）
	EventBus.item_sold.connect(func(_item: Dictionary, _refund: int): _update_ui())

func _setup_ui() -> void:
	_panel = $ShopPanel
	_slide_original_x = _panel.position.x

	var vbox: VBoxContainer = $ShopPanel/VBoxContainer

	# --- 信息栏（两行紧凑显示）---
	var info_bar := VBoxContainer.new()
	info_bar.name = "InfoBar"
	vbox.add_child(info_bar)

	# 第一行：金币 + 等级
	var line1 := HBoxContainer.new()
	line1.name = "Line1"
	info_bar.add_child(line1)

	_coins_label = Label.new()
	_coins_label.text = "$0"
	_coins_label.add_theme_font_size_override("font_size", 9)
	line1.add_child(_coins_label)

	_level_label = Label.new()
	_level_label.text = "Lv.1"
	_level_label.add_theme_font_size_override("font_size", 9)
	line1.add_child(_level_label)

	# 第二行：人口 + 波次
	var line2 := HBoxContainer.new()
	line2.name = "Line2"
	info_bar.add_child(line2)

	_pop_label = Label.new()
	_pop_label.text = "人口 0/2"
	_pop_label.add_theme_font_size_override("font_size", 9)
	line2.add_child(_pop_label)

	_wave_label = Label.new()
	_wave_label.text = "W0"
	_wave_label.add_theme_font_size_override("font_size", 9)
	line2.add_child(_wave_label)

	# --- 卡片列表（纵向排列）---
	var card_list := VBoxContainer.new()
	card_list.name = "CardList"
	card_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_list.add_theme_constant_override("separation", 2)
	vbox.add_child(card_list)

	for i in range(4):
		var card := _create_card(i)
		card_list.add_child(card)

	# --- 刷新按钮 ---
	_refresh_button = Button.new()
	_refresh_button.text = "刷新 $2"
	_refresh_button.pressed.connect(_on_refresh_pressed)
	vbox.add_child(_refresh_button)

	# --- 回收区 ---
	_recycle_area = PanelContainer.new()
	_recycle_area.name = "RecycleArea"
	_recycle_area.custom_minimum_size = Vector2(0, 40)
	var recycle_label := Label.new()
	recycle_label.text = "回收"
	recycle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recycle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_recycle_area.add_child(recycle_label)
	vbox.add_child(_recycle_area)

	# --- 开战按钮 ---
	_start_button = Button.new()
	_start_button.text = "开战"
	_start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(_start_button)

func _create_card(index: int) -> PanelContainer:
	# 横向小卡片：图标 + 名称 + 价格（等高铺满卡片区域）
	var card := PanelContainer.new()
	card.name = "ShopCard%d" % index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	card.add_child(hbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = CARD_ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	_card_icons.append(icon)

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 9)
	hbox.add_child(name_label)
	_card_names.append(name_label)

	var price_label := Label.new()
	price_label.add_theme_font_size_override("font_size", 9)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	hbox.add_child(price_label)
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

func _update_info_bar() -> void:
	_coins_label.text = "$%d" % InventoryManager.coins
	_level_label.text = "Lv.%d" % PlayerProgression.player_level
	var pop_current: int = InventoryManager.deployed_weapons.size() + InventoryManager.deployed_towers.size()
	var pop_max: int = PlayerProgression.get_population_cap()
	_pop_label.text = "人口 %d/%d" % [pop_current, pop_max]
	_wave_label.text = "W%d" % PlayerState.current_wave

func _update_cards() -> void:
	var is_placing: bool = _pending_tower_slot_index >= 0
	for i in range(4):
		if i < InventoryManager.shop_slots.size() and not InventoryManager.shop_slots[i].is_empty():
			var slot_data: Dictionary = InventoryManager.shop_slots[i]
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
			var can_buy: bool = InventoryManager.coins >= slot_data.cost and InventoryManager.can_buy_item(slot_data.id, 1)
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

func _on_shop_slot_pressed(slot_index: int) -> void:
	var slot: Dictionary = InventoryManager.shop_slots[slot_index]
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
	var slot: Dictionary = InventoryManager.shop_slots[_pending_tower_slot_index]
	var tower_id: String = slot.id if not slot.is_empty() else ""
	var snapshot: Array = InventoryManager.deployed_towers.duplicate(true)
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

func _on_start_pressed() -> void:
	start_battle_pressed.emit()

func slide_out() -> void:
	var tween := create_tween()
	var panel_width: float = _panel.size.x
	tween.tween_property(_panel, "position:x", _slide_original_x - panel_width, SLIDE_DURATION)
	tween.tween_callback(func(): _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func slide_in() -> void:
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.position.x = _slide_original_x - _panel.size.x
	var tween := create_tween()
	tween.tween_property(_panel, "position:x", _slide_original_x, SLIDE_DURATION)
	_update_ui()

func _handle_merge_weapon_cleanup() -> void:
	if weapon_manager:
		weapon_manager.refresh_weapons()

func _handle_merge_tower_cleanup(snapshot: Array) -> void:
	if drag_manager == null:
		return
	var current_ids: Array[int] = []
	var current_map: Dictionary = {}
	for entry in InventoryManager.deployed_towers:
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
	for entry in InventoryManager.deployed_towers:
		for old_entry in snapshot:
			if old_entry.deploy_id == entry.deploy_id and old_entry.level != entry.level:
				drag_manager.upgrade_tower_node(entry.deploy_id, entry.id, entry.level, entry.grid_pos)
				break

func _on_weapon_sold(weapon_index: int) -> void:
	var refund: int = InventoryManager.sell_from_deployed_weapon(weapon_index)
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
