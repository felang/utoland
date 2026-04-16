extends CanvasLayer
## 战斗 HUD 主组件 — 替代旧 ShopOverlay
##
## 包含:
##   - 左侧: 武器装备栏(3x3,合成 / 卖出 菜单)
##   - 底部中央: Roll 按钮 + 待建造栏(实例化 PendingQueuePanel.tscn)
##   - 顶部右侧: 人口 / 波次 简要信息(金币 / 等级 / 经验 由现有 HUD 显示)
##
## 外部依赖:drag_manager / weapon_manager,由 main.gd 注入。
## 自身实例化 PendingQueuePanel,内部把 drag_manager 透传给它。

const WEAPON_ICON_SIZE := Vector2(28, 28)
const ROLL_BTN_SIZE := Vector2(120, 36)
const PENDING_PANEL_SCENE := preload("res://scenes/ui/pending_queue_panel.tscn")

var drag_manager: Node = null
var weapon_manager: WeaponManager = null

var _weapon_grid: GridContainer
var _weapon_menu: PopupMenu
var _menu_weapon_index: int = -1

var _roll_button: Button
var _pop_label: Label
var _pending_panel: Control

func _ready() -> void:
	layer = 10
	_build_ui()
	_refresh()
	EventBus.coins_changed.connect(func(_d: int, _t: int) -> void: _refresh_roll_button())
	EventBus.item_purchased.connect(func(_i: Dictionary) -> void: _refresh())
	EventBus.item_sold.connect(func(_i: Dictionary, _r: int) -> void: _refresh())
	EventBus.item_merged.connect(func(_id: String, _lvl: int) -> void: _refresh())
	EventBus.tower_added_to_queue.connect(func(_t: String) -> void: _refresh_roll_button())
	EventBus.tower_consumed_from_queue.connect(func(_i: int) -> void: _refresh_roll_button())
	EventBus.tower_roll_canceled.connect(func() -> void: _refresh_roll_button())

func _build_ui() -> void:
	# 左侧武器栏
	var left := PanelContainer.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.position = Vector2(8, 80)
	left.custom_minimum_size = Vector2(110, 0)
	add_child(left)

	var weapon_vbox := VBoxContainer.new()
	left.add_child(weapon_vbox)

	var weapon_label := Label.new()
	weapon_label.text = "武器"
	weapon_label.add_theme_font_size_override("font_size", 14)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_vbox.add_child(weapon_label)

	_weapon_grid = GridContainer.new()
	_weapon_grid.columns = 3
	_weapon_grid.add_theme_constant_override("h_separation", 3)
	_weapon_grid.add_theme_constant_override("v_separation", 3)
	weapon_vbox.add_child(_weapon_grid)

	# 武器菜单
	_weapon_menu = PopupMenu.new()
	_weapon_menu.id_pressed.connect(_on_weapon_menu_pressed)
	add_child(_weapon_menu)

	# 底部:Roll 按钮 + 待建造栏
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	bottom.position.y = -100
	add_child(bottom)

	_roll_button = Button.new()
	_roll_button.custom_minimum_size = ROLL_BTN_SIZE
	_roll_button.pressed.connect(_on_roll_pressed)
	bottom.add_child(_roll_button)

	_pending_panel = PENDING_PANEL_SCENE.instantiate()
	bottom.add_child(_pending_panel)

	# 右上:人口 / 波次(精简,现有 HUD 已显示金币/等级/经验)
	var top_right := VBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-150, 8)
	add_child(top_right)

	_pop_label = Label.new()
	_pop_label.add_theme_font_size_override("font_size", 14)
	_pop_label.add_theme_color_override("font_color", Color.WHITE)
	top_right.add_child(_pop_label)

func _refresh() -> void:
	_refresh_weapon_grid()
	_refresh_roll_button()
	_refresh_pop_label()

func _refresh_weapon_grid() -> void:
	for child in _weapon_grid.get_children():
		child.queue_free()
	for i in InventoryManager.deployed_weapons.size():
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
	# 填充空槽至 9
	var total: int = max(9, InventoryManager.deployed_weapons.size())
	if total % 3 != 0:
		total = (total / 3 + 1) * 3
	for i in (total - InventoryManager.deployed_weapons.size()):
		var empty := Panel.new()
		empty.custom_minimum_size = WEAPON_ICON_SIZE
		empty.modulate = Color(0.3, 0.3, 0.3)
		_weapon_grid.add_child(empty)

func _show_weapon_menu(weapon_index: int) -> void:
	_menu_weapon_index = weapon_index
	_weapon_menu.clear()
	var entry: Dictionary = InventoryManager.deployed_weapons[weapon_index]
	var has_pair: bool = false
	for i in InventoryManager.deployed_weapons.size():
		if i != weapon_index and InventoryManager.deployed_weapons[i].id == entry.id and InventoryManager.deployed_weapons[i].level == entry.level and entry.level < 3:
			has_pair = true
			break
	if has_pair:
		_weapon_menu.add_item("合成", 0)
	var weapon_data: WeaponData = GameConfig.weapons.get(entry.id)
	var base_value: int = weapon_data.sell_price_per_level[entry.level - 1] if weapon_data else 0
	var refund: int = int(round(base_value * GameConfig.shop_config.sell_return_ratio))
	_weapon_menu.add_item("卖出 $%d" % refund, 1)
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
				_refresh()
		1:  # 卖出
			var refund: int = InventoryManager.sell_from_deployed_weapon(_menu_weapon_index)
			if refund > 0 and weapon_manager:
				weapon_manager.remove_weapon(_menu_weapon_index)
			_refresh()
	_menu_weapon_index = -1

func _refresh_roll_button() -> void:
	var cost: int = GameConfig.shop_config.roll_cost
	_roll_button.text = "Roll $%d" % cost
	_roll_button.disabled = not InventoryManager.can_roll()

func _refresh_pop_label() -> void:
	var cur: int = InventoryManager.get_population_used()
	var maxv: int = PlayerProgression.get_population_cap()
	_pop_label.text = "人口 %d/%d" % [cur, maxv]

func _on_roll_pressed() -> void:
	InventoryManager.roll_tower()
	_refresh_roll_button()

func set_drag_manager(dm: Node) -> void:
	drag_manager = dm
	if _pending_panel:
		_pending_panel.drag_manager = dm
