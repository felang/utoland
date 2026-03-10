extends Control

# 刷新费用（index = 波次数）
const REFRESH_COSTS: Array = [0, 5, 5, 5, 5, 8, 8, 8, 8, 12, 12]

var shop_items: Array[ShopItemData] = []
var shop_prices: Array[int] = []
var locked_slots: Array[bool] = [false, false, false, false]

const SHOP_CARD_SCENE = preload("res://scenes/ui/shop_item_card.tscn")
var _card_nodes: Array = []

var _generator := ShopItemGenerator.new()
var _effect_applier := ShopEffectApplier.new()

@onready var coin_label: Label = $MainPanel/VBoxContainer/HeaderRow/CoinLabel
@onready var wave_label: Label = $MainPanel/VBoxContainer/HeaderRow/WaveLabel
@onready var title_label: Label = $MainPanel/VBoxContainer/HeaderRow/TitleLabel
@onready var card_grid: GridContainer = $MainPanel/VBoxContainer/CardGrid
@onready var stats_grid: GridContainer = $MainPanel/VBoxContainer/StatsPanel/StatsGrid
@onready var stats_panel: PanelContainer = $MainPanel/VBoxContainer/StatsPanel
@onready var refresh_button: Button = $MainPanel/VBoxContainer/ButtonRow/RefreshButton
@onready var confirm_button: Button = $MainPanel/VBoxContainer/ButtonRow/ConfirmButton

func _ready() -> void:
	# Guard: 测试环境中 script-only 实例化时无场景树
	if not card_grid:
		return
	refresh_button.pressed.connect(_on_refresh_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	_generate_shop()
	_create_card_nodes()
	_update_ui()
	_style_ui()

# ===== 亲和信息 =====

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

# ===== 商店生成 =====

func _generate_shop() -> void:
	var wave := GameData.current_wave + 1
	var affinity_tags := _get_affinity_tags()
	var affinity_discount := _get_affinity_discount()
	var result := _generator.generate_items(wave, affinity_tags, affinity_discount,
		locked_slots, shop_items, shop_prices)
	shop_items = result["items"]
	shop_prices = result["prices"]

# ===== 购买逻辑 =====

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
	_update_ui()

# ===== UI =====

func _create_card_nodes() -> void:
	for child in card_grid.get_children():
		child.queue_free()
	_card_nodes.clear()
	for i in range(4):
		var card = SHOP_CARD_SCENE.instantiate()
		card.buy_pressed.connect(_buy_item)
		card.lock_toggled.connect(_on_lock_toggled)
		card_grid.add_child(card)
		_card_nodes.append(card)

func _on_lock_toggled(index: int) -> void:
	locked_slots[index] = not locked_slots[index]

func _update_ui() -> void:
	if not coin_label:
		return
	coin_label.text = "金币: %d" % GameData.coins
	wave_label.text = "Wave %d/%d" % [GameData.current_wave + 1, GameConfig.waves.size()]
	var refresh_cost := _get_refresh_cost()
	refresh_button.disabled = GameData.coins < refresh_cost
	refresh_button.text = "刷新 (%d)" % refresh_cost
	_display_items()
	_update_stats_panel()

func _display_items() -> void:
	for i in range(min(shop_items.size(), _card_nodes.size())):
		var item := shop_items[i]
		var price := shop_prices[i]
		var card = _card_nodes[i]
		card.setup(i, item, price, locked_slots[i],
			GameData.coins >= price, _generator.can_buy(item))

func _update_stats_panel() -> void:
	for child in stats_grid.get_children():
		child.queue_free()
	var stats: Array[String] = [
		"HP %d" % int(GameData.player_stats[Enums.Stat.MAX_HP] * GameData.player_stats[Enums.Stat.HP_MULT]),
		"攻击 x%.1f" % GameData.player_stats[Enums.Stat.DAMAGE_MULT],
		"速度 x%.1f" % GameData.player_stats[Enums.Stat.MOVE_SPEED_MULT],
		"暴击 %d%%" % int(GameData.crit_chance * 100),
		"穿甲 x%d" % GameData.pierce_count,
		"吸血 %d%%" % int(GameData.lifesteal_ratio * 100),
		"减伤 %d%%" % int(GameData.damage_reduction * 100),
		"闪避 %d%%" % int(GameData.dodge_chance * 100),
	]
	for stat_text in stats:
		var label := Label.new()
		label.text = stat_text
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TINY)
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
		stats_grid.add_child(label)

func _style_ui() -> void:
	# 背景
	$Background.color = UIConstants.COLOR_BG_PRIMARY
	# 标题
	title_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	title_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	# 金币
	coin_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	coin_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	# 波次
	wave_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TINY)
	wave_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	# 属性面板
	stats_panel.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox())
	# 按钮
	confirm_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TINY)
	refresh_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TINY)

func _get_refresh_cost() -> int:
	var wave := GameData.current_wave + 1
	if wave >= REFRESH_COSTS.size():
		return REFRESH_COSTS[-1]
	return REFRESH_COSTS[wave]

func _on_refresh_pressed() -> void:
	var cost := _get_refresh_cost()
	if GameData.coins < cost:
		return
	GameData.coins -= cost
	_generate_shop()
	_update_ui()

func _on_confirm_pressed() -> void:
	SceneManager.go_to(Enums.Scene.MAIN)
