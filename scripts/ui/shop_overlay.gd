extends CanvasLayer
## 底部商店面板 — 横条双行 UI

signal start_battle_pressed

const SLIDE_DURATION := 0.3
const CARD_ICON_SIZE := Vector2(24, 24)
const WEAPON_ICON_SIZE := Vector2(28, 28)

var _shop_manager: ShopManager
var _panel: PanelContainer
var _slide_original_y: float = 0.0

# 信息栏
var _coins_label: Label
var _pop_label: Label
var _wave_label: Label

# 操作按钮
var _refresh_button: Button
var _start_button: Button

# 商店卡片
var _card_containers: Array[PanelContainer] = []
var _card_icons: Array[TextureRect] = []
var _card_names: Array[Label] = []
var _card_prices: Array[Label] = []
var _card_buttons: Array[Button] = []

# 武器装备栏
var _weapon_grid: GridContainer
var _weapon_menu: PopupMenu
var _menu_weapon_index: int = -1

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
	EventBus.item_sold.connect(func(_item: Dictionary, _refund: int): _update_ui())
	EventBus.item_merged.connect(func(_id: String, _level: int): _update_ui())

func _setup_ui() -> void:
	_panel = $ShopPanel
	_slide_original_y = _panel.position.y

	var vbox: VBoxContainer = $ShopPanel/VBoxContainer

	# === 整体用 HBoxContainer 左右分栏 ===
	var main_hbox := HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(main_hbox)

	# ——— 左列：武器区（标签 + 可滚动3列网格）———
	var weapon_col := VBoxContainer.new()
	weapon_col.name = "WeaponCol"
	weapon_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_col.add_theme_constant_override("separation", 2)
	main_hbox.add_child(weapon_col)

	var weapon_label := Label.new()
	weapon_label.text = "武器"
	weapon_label.add_theme_font_size_override("font_size", 18)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_col.add_child(weapon_label)

	var weapon_scroll := ScrollContainer.new()
	weapon_scroll.name = "WeaponScroll"
	weapon_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	weapon_col.add_child(weapon_scroll)

	_weapon_grid = GridContainer.new()
	_weapon_grid.columns = 3
	_weapon_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_grid.add_theme_constant_override("h_separation", 3)
	_weapon_grid.add_theme_constant_override("v_separation", 3)
	weapon_scroll.add_child(_weapon_grid)

	# 分隔线
	var sep1 := VSeparator.new()
	main_hbox.add_child(sep1)

	# ——— 中列：信息栏 + 商店卡片 ———
	var mid_col := VBoxContainer.new()
	mid_col.name = "MidCol"
	mid_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_col.add_theme_constant_override("separation", 2)
	main_hbox.add_child(mid_col)

	# 信息栏上行（左：金币/人口/波数，右：升级/刷新）
	var info_bar := HBoxContainer.new()
	info_bar.name = "InfoBar"
	info_bar.add_theme_constant_override("separation", 8)
	info_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_col.add_child(info_bar)

	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 18)
	info_bar.add_child(_coins_label)

	_pop_label = Label.new()
	_pop_label.add_theme_font_size_override("font_size", 18)
	info_bar.add_child(_pop_label)

	_wave_label = Label.new()
	_wave_label.add_theme_font_size_override("font_size", 18)
	info_bar.add_child(_wave_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_bar.add_child(spacer)

	_refresh_button = Button.new()
	_refresh_button.text = "刷新 $2"
	_refresh_button.add_theme_font_size_override("font_size", 14)
	_refresh_button.custom_minimum_size = Vector2(72, 28)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	info_bar.add_child(_refresh_button)

	# 商店卡片行
	var shop_row := HBoxContainer.new()
	shop_row.name = "ShopRow"
	shop_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_row.add_theme_constant_override("separation", 4)
	mid_col.add_child(shop_row)

	for i in range(4):
		var card := _create_card(i)
		shop_row.add_child(card)

	# 分隔线
	var sep2 := VSeparator.new()
	main_hbox.add_child(sep2)

	# ——— 右列：开战按钮（填满区域，垂直排字）———
	_start_button = Button.new()
	_start_button.text = "开\n战"
	_start_button.add_theme_font_size_override("font_size", 24)
	_start_button.custom_minimum_size = Vector2(48, 0)
	_start_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_start_button.pressed.connect(_on_start_pressed)
	main_hbox.add_child(_start_button)

	# 武器菜单
	_weapon_menu = PopupMenu.new()
	_weapon_menu.name = "WeaponMenu"
	_weapon_menu.id_pressed.connect(_on_weapon_menu_pressed)
	add_child(_weapon_menu)

func _create_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ShopCard%d" % index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = CARD_ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	price_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(price_label)
	_card_prices.append(price_label)

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
	_update_weapon_grid()
	_update_action_buttons()

func _update_info_bar() -> void:
	_coins_label.text = "$%d" % InventoryManager.coins
	var pop_current: int = InventoryManager.get_population_used()
	var pop_max: int = PlayerProgression.get_population_cap()
	_pop_label.text = "人口 %d/%d" % [pop_current, pop_max]
	_wave_label.text = "第%d波" % PlayerState.current_wave

func _update_cards() -> void:
	var is_placing: bool = _pending_tower_slot_index >= 0
	for i in range(4):
		if i < InventoryManager.shop_slots.size() and not InventoryManager.shop_slots[i].is_empty():
			var slot_data: Dictionary = InventoryManager.shop_slots[i]
			var item_data: Resource = _get_item_data(slot_data.id)

			if item_data and item_data.icon_path != "" and ResourceLoader.exists(item_data.icon_path):
				_card_icons[i].texture = load(item_data.icon_path)
			else:
				_card_icons[i].texture = null

			_card_names[i].text = item_data.display_name if item_data else slot_data.id
			_card_prices[i].text = "$%d" % slot_data.cost

			var can_buy: bool = InventoryManager.coins >= slot_data.cost and InventoryManager.can_buy_item(slot_data.id, 1)
			_card_buttons[i].disabled = not can_buy or is_placing

			if is_placing and i == _pending_tower_slot_index:
				_card_names[i].text = "放置中"
				_card_buttons[i].disabled = true

			_card_containers[i].modulate = Color.WHITE if (can_buy and not is_placing) else Color(0.5, 0.5, 0.5)
		else:
			_card_icons[i].texture = null
			_card_names[i].text = "已售出"
			_card_prices[i].text = ""
			_card_buttons[i].disabled = true
			_card_containers[i].modulate = Color(0.5, 0.5, 0.5)

func _update_weapon_grid() -> void:
	# 清除旧图标
	for child in _weapon_grid.get_children():
		child.queue_free()
	# 创建已装备武器图标
	for i in range(InventoryManager.deployed_weapons.size()):
		var entry: Dictionary = InventoryManager.deployed_weapons[i]
		var btn := Button.new()
		btn.custom_minimum_size = WEAPON_ICON_SIZE
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var weapon_data: WeaponData = GameConfig.weapons.get(entry.id)
		if weapon_data and not weapon_data.icon_path.is_empty() and ResourceLoader.exists(weapon_data.icon_path):
			var icon := TextureRect.new()
			icon.texture = load(weapon_data.icon_path)
			icon.custom_minimum_size = WEAPON_ICON_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(icon)
		btn.pressed.connect(_show_weapon_menu.bind(i))
		_weapon_grid.add_child(btn)
	# 空槽（填到 9 个，3x3 撑满高度）
	var total: int = max(9, InventoryManager.deployed_weapons.size())
	if total % 3 != 0:
		total = (total / 3 + 1) * 3
	var empty_count: int = total - InventoryManager.deployed_weapons.size()
	for i in range(empty_count):
		var empty := Panel.new()
		empty.custom_minimum_size = WEAPON_ICON_SIZE
		empty.modulate = Color(0.3, 0.3, 0.3)
		_weapon_grid.add_child(empty)

func _update_action_buttons() -> void:
	_refresh_button.text = "刷新 $%d" % GameConfig.shop_config.refresh_cost
	_refresh_button.disabled = InventoryManager.coins < GameConfig.shop_config.refresh_cost

func _show_weapon_menu(weapon_index: int) -> void:
	_menu_weapon_index = weapon_index
	_weapon_menu.clear()

	var entry: Dictionary = InventoryManager.deployed_weapons[weapon_index]

	# 合成选项
	var has_pair: bool = false
	for i in range(InventoryManager.deployed_weapons.size()):
		if i != weapon_index and InventoryManager.deployed_weapons[i].id == entry.id and InventoryManager.deployed_weapons[i].level == entry.level and entry.level < 3:
			has_pair = true
			break
	if has_pair:
		_weapon_menu.add_item("合成", 0)

	# 卖出选项
	var weapon_data: WeaponData = GameConfig.weapons.get(entry.id)
	var refund: int = weapon_data.sell_price_per_level[entry.level - 1] if weapon_data else 0
	_weapon_menu.add_item("卖出 $%d" % refund, 1)

	# 显示菜单
	var btn: Button = _weapon_grid.get_child(weapon_index)
	var global_pos: Vector2 = btn.global_position
	_weapon_menu.position = Vector2i(int(global_pos.x), int(global_pos.y) - 50)
	_weapon_menu.popup()

func _on_weapon_menu_pressed(id: int) -> void:
	match id:
		0:  # 合成
			if InventoryManager.merge_weapon(_menu_weapon_index):
				if weapon_manager:
					weapon_manager.refresh_weapons()
				_update_ui()
		1:  # 卖出
			var refund: int = InventoryManager.sell_from_deployed_weapon(_menu_weapon_index)
			if refund > 0 and weapon_manager:
				weapon_manager.remove_weapon(_menu_weapon_index)
			_update_ui()
	_menu_weapon_index = -1

func _on_shop_slot_pressed(slot_index: int) -> void:
	var slot: Dictionary = InventoryManager.shop_slots[slot_index]
	if slot.is_empty():
		return
	if slot.type == "weapon":
		var success: bool = _shop_manager.buy_weapon(slot_index)
		if success:
			if weapon_manager:
				weapon_manager.refresh_weapons()
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
	var deploy_id: int = _shop_manager.confirm_tower_purchase(_pending_tower_slot_index, grid_pos)
	if deploy_id > 0:
		drag_manager.spawn_tower_node(deploy_id, tower_id, 1, grid_pos)
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
	var panel_height: float = _panel.size.y
	tween.tween_property(_panel, "position:y", _slide_original_y + panel_height, SLIDE_DURATION)
	tween.tween_callback(func(): _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func slide_in() -> void:
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.position.y = _slide_original_y + _panel.size.y
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", _slide_original_y, SLIDE_DURATION)
	_update_ui()

func _get_item_data(item_id: String) -> Resource:
	if GameConfig.weapons.has(item_id):
		return GameConfig.weapons[item_id]
	if GameConfig.towers.has(item_id):
		return GameConfig.towers[item_id]
	return null
