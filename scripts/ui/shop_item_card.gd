extends PanelContainer
## 商店物品卡片 — 显示物品名称、描述、价格，支持锁定和购买

signal buy_pressed(index: int)
signal lock_toggled(index: int)

@onready var name_label: Label = $VBoxContainer/HeaderRow/NameLabel
@onready var lock_button: Button = $VBoxContainer/HeaderRow/LockButton
@onready var desc_label: Label = $VBoxContainer/DescLabel
@onready var price_label: Label = $VBoxContainer/FooterRow/PriceLabel
@onready var buy_button: Button = $VBoxContainer/FooterRow/BuyButton

var slot_index: int = -1
var is_locked: bool = false


func _ready() -> void:
	buy_button.pressed.connect(func(): buy_pressed.emit(slot_index))
	lock_button.pressed.connect(_on_lock_pressed)
	_apply_base_style()


func setup(index: int, item: ShopItemData, price: int, locked: bool, can_afford: bool, can_buy: bool) -> void:
	slot_index = index
	is_locked = locked
	name_label.text = item.display_name
	desc_label.text = item.description
	price_label.text = "%d 金" % price
	price_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	lock_button.text = "L" if locked else "U"
	buy_button.disabled = not can_afford or not can_buy
	buy_button.text = "已满" if not can_buy else "购买"
	_apply_rarity_style(item)


func _apply_base_style() -> void:
	name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	desc_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	desc_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	price_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	buy_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)


func _apply_rarity_style(item: ShopItemData) -> void:
	var border_color := UIConstants.get_rarity_color(item.rarity)
	# 亲和色覆盖
	var affinity_tags := _get_affinity_tags()
	for tag in item.tags:
		if tag in affinity_tags:
			match tag:
				Enums.ItemTag.SHOOTER:
					border_color = UIConstants.COLOR_AFFINITY_SHOOTER
				Enums.ItemTag.ENGINEER:
					border_color = UIConstants.COLOR_AFFINITY_ENGINEER
			break
	var style := UIConstants.create_panel_stylebox(
		UIConstants.COLOR_BG_PANEL_ALPHA, UIConstants.CORNER_RADIUS_PANEL,
		border_color, 2
	)
	add_theme_stylebox_override("panel", style)


func _get_affinity_tags() -> PackedStringArray:
	var char_id := GameData.current_character
	if not GameConfig.characters.has(char_id):
		return PackedStringArray()
	return GameConfig.characters[char_id].affinity_tags


func _on_lock_pressed() -> void:
	is_locked = not is_locked
	lock_button.text = "L" if is_locked else "U"
	lock_toggled.emit(slot_index)
