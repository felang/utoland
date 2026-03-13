extends Node
## 塔商店侧栏：3 格 + 刷新

const REFRESH_COSTS: Array = [0, 5, 5, 5, 5, 8, 8, 8, 8, 12, 12]

var _main: Node2D = null
var _generator := TowerShopGenerator.new()
var shop_items: Array[Dictionary] = []  # [{tower_id, target_level, is_new}]
var shop_prices: Array[int] = []
var _item_nodes: Array = []

func initialize(main: Node2D) -> void:
	_main = main
	_generate_shop()
	_create_item_cards()
	_main.coins_changed.connect(_update_display)

func _generate_shop() -> void:
	var result: Dictionary = _generator.generate_options()
	shop_items = result["items"]
	shop_prices = result["prices"]

func _create_item_cards() -> void:
	var item_list: VBoxContainer = get_parent().get_node("ShopScroll/ShopItemList")
	for child in item_list.get_children():
		child.queue_free()
	_item_nodes.clear()

	for i in range(shop_items.size()):
		var card := _create_item_card(i)
		item_list.add_child(card)
		_item_nodes.append(card)

	var refresh_btn: Button = get_parent().get_node("RefreshButton")
	if not refresh_btn.pressed.is_connected(_on_refresh_pressed):
		refresh_btn.pressed.connect(_on_refresh_pressed)
	_update_refresh_button(refresh_btn)

func _create_item_card(index: int) -> PanelContainer:
	var item: Dictionary = shop_items[index]
	var price: int = shop_prices[index]
	var tower_id: String = item["tower_id"]
	var target_level: int = item["target_level"]
	var is_new: bool = item["is_new"]
	var td: TowerData = GameConfig.towers[tower_id]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(108, 60)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var name_label := Label.new()
	if is_new:
		name_label.text = "%s (新!)" % td.display_name
	else:
		name_label.text = "%s Lv%d" % [td.display_name, target_level]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(name_label)

	var price_label := Label.new()
	price_label.text = "%d 金" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 10)
	price_label.add_theme_color_override("font_color", Color("#e0c040"))
	vbox.add_child(price_label)

	card.gui_input.connect(func(event: InputEvent) -> void: _on_item_clicked(event, index))
	return card

func _on_item_clicked(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_buy_item(index)

func _buy_item(index: int) -> void:
	if index >= shop_items.size():
		return
	var price: int = shop_prices[index]
	if GameData.coins < price:
		return
	var item: Dictionary = shop_items[index]
	GameData.coins -= price
	GameData.upgrade_tower(item["tower_id"])
	AudioManager.play("shop_buy")
	shop_items.remove_at(index)
	shop_prices.remove_at(index)
	_recreate_item_cards()
	if _main:
		_main.update_coins_display()

func _on_refresh_pressed() -> void:
	var cost := _get_refresh_cost()
	if GameData.coins < cost:
		return
	GameData.coins -= cost
	_generate_shop()
	_recreate_item_cards()
	if _main:
		_main.update_coins_display()

func _recreate_item_cards() -> void:
	if not is_inside_tree():
		return
	var item_list: VBoxContainer = get_parent().get_node("ShopScroll/ShopItemList")
	for child in item_list.get_children():
		child.queue_free()
	_item_nodes.clear()
	for i in range(shop_items.size()):
		var card := _create_item_card(i)
		item_list.add_child(card)
		_item_nodes.append(card)

func _update_display() -> void:
	for i in range(min(shop_items.size(), _item_nodes.size())):
		var price: int = shop_prices[i]
		_item_nodes[i].modulate.a = 1.0 if GameData.coins >= price else 0.5
	var refresh_btn: Button = get_parent().get_node("RefreshButton")
	_update_refresh_button(refresh_btn)

func _update_refresh_button(btn: Button) -> void:
	var cost := _get_refresh_cost()
	btn.text = "刷新 (%d)" % cost
	btn.disabled = GameData.coins < cost

func _get_refresh_cost() -> int:
	var wave := GameData.current_wave + 1
	if wave >= REFRESH_COSTS.size():
		return REFRESH_COSTS[-1]
	return REFRESH_COSTS[wave]
