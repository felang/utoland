extends Node
## 商店侧栏：物品生成、购买、刷新

const REFRESH_COSTS: Array = [0, 5, 5, 5, 5, 8, 8, 8, 8, 12, 12]

var _main: Node2D = null
var _generator := ShopItemGenerator.new()
var _effect_applier := ShopEffectApplier.new()
var shop_items: Array[ShopItemData] = []
var shop_prices: Array[int] = []
var _item_nodes: Array = []

func initialize(main: Node2D) -> void:
	_main = main
	_generate_shop()
	_create_item_cards()
	_main.coins_changed.connect(_update_display)

func _generate_shop() -> void:
	var wave := GameData.current_wave + 1
	var affinity_tags := _get_affinity_tags()
	var affinity_discount := _get_affinity_discount()
	var locked: Array[bool] = [false, false, false, false]
	var result := _generator.generate_items(wave, affinity_tags, affinity_discount,
		locked, shop_items, shop_prices)
	shop_items = result["items"]
	shop_prices = result["prices"]

func _create_item_cards() -> void:
	var item_list: VBoxContainer = get_parent().get_node("ShopItemList")
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
	var item: ShopItemData = shop_items[index]
	var price: int = shop_prices[index]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(108, 50)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var rarity_color: Color = UIConstants.get_rarity_color(item.rarity)
	var style := UIConstants.create_panel_stylebox(
		UIConstants.COLOR_BG_PANEL_ALPHA, UIConstants.CORNER_RADIUS_PANEL,
		rarity_color, 2
	)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = item.description
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	var price_label := Label.new()
	price_label.text = "%d 金" % price
	price_label.add_theme_font_size_override("font_size", 9)
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
	var item: ShopItemData = shop_items[index]
	var price: int = shop_prices[index]
	if GameData.coins < price:
		return
	if not _generator.can_buy(item):
		return
	GameData.coins -= price
	GameData.purchased_items[item.id] = GameData.purchased_items.get(item.id, 0) + 1
	GameData.record_item_purchased(item.id)
	_effect_applier.apply_effect(item)
	AudioManager.play("shop_buy")
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
	var item_list: VBoxContainer = get_parent().get_node("ShopItemList")
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
		var can_afford: bool = GameData.coins >= price
		var can_buy: bool = _generator.can_buy(shop_items[i])
		_item_nodes[i].modulate.a = 1.0 if (can_afford and can_buy) else 0.5
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

func _get_affinity_tags() -> PackedStringArray:
	var char_id := GameData.current_character
	if not GameConfig.characters.has(char_id):
		return PackedStringArray()
	return GameConfig.characters[char_id].affinity_tags

func _get_affinity_discount() -> float:
	var char_id := GameData.current_character
	if not GameConfig.characters.has(char_id):
		return 0.0
	return GameConfig.characters[char_id].affinity_discount
