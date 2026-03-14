extends Control

var _shop_manager: ShopManager = ShopManager.new()

@onready var _coins_label: Label = %CoinsLabel
@onready var _level_label: Label = %LevelLabel
@onready var _pop_label: Label = %PopLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _level_up_button: Button = %LevelUpButton
@onready var _start_button: Button = %StartButton
@onready var _refresh_button: Button = %RefreshButton
@onready var _shop_panel: HBoxContainer = %ShopBar
@onready var _bag_panel: HBoxContainer = %BagBar
@onready var _equip_panel: VBoxContainer = %EquipPanel
@onready var _map_area: Control = %MapArea

# 商店栏位按钮
var _shop_buttons: Array[Button] = []
# 背包栏位按钮
var _bag_buttons: Array[Button] = []
# 装备武器按钮（含 Label header，用 Control 基类）
var _equip_widgets: Array[Control] = []
# 塔布置模式：当前正在布置的背包索引，-1 表示未激活
var _placing_tower_index: int = -1
# 地图上已显示的塔节点
var _tower_nodes: Array[Node2D] = []

func _ready() -> void:
	_shop_manager.refresh_shop(GameData.is_first_shop_visit)
	GameData.is_first_shop_visit = false

	_start_button.pressed.connect(_on_start_pressed)
	_level_up_button.pressed.connect(_on_level_up_pressed)
	_refresh_button.pressed.connect(_on_refresh_pressed)

	# 获取场景中的商店栏位按钮
	_shop_buttons = [%ShopSlot0, %ShopSlot1, %ShopSlot2, %ShopSlot3]
	for i in _shop_buttons.size():
		var idx: int = i
		_shop_buttons[i].pressed.connect(func(): _on_shop_slot_pressed(idx))

	_update_ui()

func _update_ui() -> void:
	# 顶栏
	_coins_label.text = "💰%d" % GameData.coins
	_level_label.text = "Lv%d" % GameData.player_level
	_pop_label.text = "%d/%d" % [GameData.get_population_used(), GameData.get_population_cap()]
	_wave_label.text = "波%d" % (GameData.current_wave + 1)
	_update_level_up_button()
	_update_shop_slots()
	_update_bag()
	_update_equip()
	_update_map_towers()

func _update_level_up_button() -> void:
	var config: ShopConfig = GameConfig.shop_config
	if GameData.player_level >= config.population_per_level.size():
		_level_up_button.text = "满级"
		_level_up_button.disabled = true
	else:
		var cost: int = config.level_up_costs[GameData.player_level - 1]
		_level_up_button.text = "升本%d💰" % cost
		_level_up_button.disabled = GameData.coins < cost

func _update_shop_slots() -> void:
	for i in _shop_buttons.size():
		var btn: Button = _shop_buttons[i]
		if i >= GameData.shop_slots.size() or GameData.shop_slots[i].is_empty():
			btn.text = "已购买"
			btn.disabled = true
		else:
			var slot: Dictionary = GameData.shop_slots[i]
			var data: Resource = _get_item_data(slot.id)
			btn.text = "%s\n%d💰" % [data.display_name, slot.cost]
			btn.disabled = GameData.coins < slot.cost or not GameData.can_buy()

func _update_bag() -> void:
	# 清理旧按钮
	for btn in _bag_buttons:
		btn.queue_free()
	_bag_buttons.clear()

	var config: ShopConfig = GameConfig.shop_config
	for i in config.bag_capacity:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(50, 50)
		if i < GameData.bag.size():
			var item: Dictionary = GameData.bag[i]
			var data: Resource = _get_item_data(item.id)
			var stars: String = "★".repeat(item.level)
			btn.text = "%s\n%s" % [data.display_name, stars]
			var idx: int = i
			btn.pressed.connect(func(): _on_bag_item_pressed(idx))
			btn.gui_input.connect(func(event: InputEvent): _on_bag_item_input(event, idx))
		else:
			btn.text = ""
			btn.disabled = true
		_bag_buttons.append(btn)
		_bag_panel.add_child(btn)

func _update_equip() -> void:
	for widget in _equip_widgets:
		widget.queue_free()
	_equip_widgets.clear()

	# 角色装备标题
	var header: Label = Label.new()
	header.text = "角色装备"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equip_panel.add_child(header)
	_equip_widgets.append(header)

	for i in GameData.deployed_weapons.size():
		var entry: Dictionary = GameData.deployed_weapons[i]
		var wd: WeaponData = GameConfig.weapons[entry.id]
		var stars: String = "★".repeat(entry.level)
		var btn: Button = Button.new()
		btn.text = "%s %s" % [wd.display_name, stars]
		btn.custom_minimum_size = Vector2(100, 36)
		var idx: int = i
		# 左键卸下
		btn.pressed.connect(func(): _on_weapon_unequip(idx))
		# 右键卖出
		btn.gui_input.connect(func(event: InputEvent): _on_weapon_sell_input(event, idx))
		_equip_widgets.append(btn)
		_equip_panel.add_child(btn)

func _update_map_towers() -> void:
	for node in _tower_nodes:
		node.queue_free()
	_tower_nodes.clear()

	for i in GameData.deployed_towers.size():
		var entry: Dictionary = GameData.deployed_towers[i]
		var label: Label = Label.new()
		var td: TowerData = GameConfig.towers[entry.id]
		label.text = "%s★%d" % [td.display_name, entry.level]
		label.position = Vector2(entry.grid_pos.x * 64, entry.grid_pos.y * 64)
		_map_area.add_child(label)
		_tower_nodes.append(label)

# === 事件处理 ===

func _on_start_pressed() -> void:
	SceneManager.go_to("main")

func _on_level_up_pressed() -> void:
	if GameData.buy_level_up():
		_update_ui()

func _on_refresh_pressed() -> void:
	if _shop_manager.manual_refresh():
		_update_ui()

func _on_shop_slot_pressed(slot_index: int) -> void:
	if _shop_manager.buy_item(slot_index):
		_update_ui()

func _on_bag_item_pressed(bag_index: int) -> void:
	if bag_index >= GameData.bag.size():
		return
	var item: Dictionary = GameData.bag[bag_index]
	if item.type == "weapon":
		if GameData.deploy_weapon(bag_index):
			_update_ui()
	elif item.type == "tower":
		_placing_tower_index = bag_index
		# 提示进入放塔模式（TODO: 后续可改为拖拽交互）

func _on_bag_item_input(event: InputEvent, bag_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if bag_index < GameData.bag.size():
			GameData.sell_from_bag(bag_index)
			_update_ui()

func _on_weapon_unequip(deploy_index: int) -> void:
	GameData.undeploy_weapon(deploy_index)
	_update_ui()

func _on_weapon_sell_input(event: InputEvent, deploy_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		GameData.sell_from_deployed_weapon(deploy_index)
		_update_ui()

func _input(event: InputEvent) -> void:
	# 地图点击放塔
	if _placing_tower_index >= 0 and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos: Vector2 = _map_area.get_local_mouse_position()
			if _map_area.get_rect().has_point(local_pos):
				var grid_pos: Vector2i = Vector2i(int(local_pos.x / 64), int(local_pos.y / 64))
				if GameData.deploy_tower(_placing_tower_index, grid_pos):
					_placing_tower_index = -1
					_update_ui()
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_placing_tower_index = -1  # 取消放塔

func _get_item_data(item_id: String) -> Resource:
	if GameConfig.weapons.has(item_id):
		return GameConfig.weapons[item_id]
	return GameConfig.towers[item_id]
