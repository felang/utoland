extends Control

# 稀有度概率表（按波次）
const RARITY_TABLE: Array = [
	{"from": 1,  "weights": {"common": 100, "rare": 0,  "epic": 0}},
	{"from": 4,  "weights": {"common": 70,  "rare": 30, "epic": 0}},
	{"from": 7,  "weights": {"common": 40,  "rare": 50, "epic": 10}},
	{"from": 10, "weights": {"common": 20,  "rare": 50, "epic": 30}},
]
# 刷新费用（index = 波次数）
const REFRESH_COSTS: Array = [0, 5, 5, 5, 5, 8, 8, 8, 8, 12, 12]
# 塔相关 effect_type 黑名单（幸存者模式下过滤）
const TOWER_EFFECT_TYPES: Array = [
	Enums.ItemEffect.TOWER_STAT,
	Enums.ItemEffect.TOWER_LINK,
	Enums.ItemEffect.WAVE_HEAL_TOWERS,
	Enums.ItemEffect.TOWER_REGEN,
	Enums.ItemEffect.SYMBIOSIS,
	Enums.ItemEffect.WAR_MACHINE,
]

var shop_items: Array[ShopItemData] = []
var shop_prices: Array[int] = []
var locked_slots: Array[bool] = [false, false, false, false]

@onready var coin_label = $VBoxContainer/CoinLabel
@onready var refresh_button = $VBoxContainer/ButtonsContainer/RefreshButton
@onready var confirm_button = $VBoxContainer/ButtonsContainer/ConfirmButton
@onready var item_containers: Array = [
	$VBoxContainer/ItemsContainer/Item1,
	$VBoxContainer/ItemsContainer/Item2,
	$VBoxContainer/ItemsContainer/Item3,
	$VBoxContainer/ItemsContainer/Item4,
]

func _ready() -> void:
	refresh_button.pressed.connect(_on_refresh_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	for i in range(4):
		_connect_slot_buy_button(i)
		_connect_slot_lock_button(i)
	_generate_shop()
	_update_ui()

# ===== 公共逻辑方法（供测试调用）=====

func _get_rarity_weights(wave: int) -> Dictionary:
	var result: Dictionary = {}
	for entry in RARITY_TABLE:
		if wave >= entry["from"]:
			result = entry["weights"]
	return result

func _pick_rarity(wave: int) -> String:
	var weights := _get_rarity_weights(wave)
	var total: int = 0
	for w in weights.values():
		total += w
	if total == 0:
		return Enums.ItemRarity.COMMON
	var roll := randi_range(0, total - 1)
	var cumulative := 0
	for rarity in weights:
		cumulative += weights[rarity]
		if roll < cumulative:
			return rarity
	return Enums.ItemRarity.COMMON

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

func _calculate_price(item: ShopItemData) -> int:
	var base := randi_range(item.cost_min, item.cost_max)
	var affinity_tags := _get_affinity_tags()
	for tag in item.tags:
		if tag in affinity_tags:
			var discount := _get_affinity_discount()
			return max(1, int(base * (1.0 - discount)))
	return base

func _can_buy(item: ShopItemData) -> bool:
	if item.max_stack == -1:
		return true
	var bought: int = GameData.purchased_items.get(item.id, 0)
	return bought < item.max_stack

# ===== 商店生成 =====

func _generate_shop() -> void:
	var wave := GameData.current_wave + 1
	var affinity_tags := _get_affinity_tags()

	var by_rarity: Dictionary = {
		Enums.ItemRarity.COMMON: [],
		Enums.ItemRarity.RARE: [],
		Enums.ItemRarity.EPIC: [],
	}
	for item in GameConfig.items.values():
		if item.effect_type in TOWER_EFFECT_TYPES:
			continue
		if by_rarity.has(item.rarity):
			by_rarity[item.rarity].append(item)

	# 处理天命史诗物品：本局只能出现一次
	var destiny_bought: bool = GameData.purchased_items.get("destiny", 0) > 0

	for i in range(4):
		if locked_slots[i] and i < shop_items.size():
			continue
		var rarity := _pick_rarity(wave)
		var pool: Array = by_rarity[rarity].filter(func(it: ShopItemData) -> bool:
			if it.id == "destiny" and destiny_bought:
				return false
			return _can_buy(it)
		)
		# 亲和标签物品权重加倍（放两份到加权池）
		var weighted_pool: Array = []
		for item in pool:
			weighted_pool.append(item)
			for tag in item.tags:
				if tag in affinity_tags:
					weighted_pool.append(item)
					break
		if weighted_pool.is_empty():
			weighted_pool = by_rarity[Enums.ItemRarity.COMMON]
		if weighted_pool.is_empty():
			continue

		var picked: ShopItemData = weighted_pool.pick_random()
		if i < shop_items.size():
			shop_items[i] = picked
			shop_prices[i] = _calculate_price(picked)
		else:
			shop_items.append(picked)
			shop_prices.append(_calculate_price(picked))

# ===== 购买逻辑 =====

func _buy_item(index: int) -> void:
	if index >= shop_items.size():
		return
	var item: ShopItemData = shop_items[index]
	var price: int = shop_prices[index]
	if GameData.coins < price:
		return
	if not _can_buy(item):
		return

	GameData.coins -= price
	GameData.purchased_items[item.id] = GameData.purchased_items.get(item.id, 0) + 1
	_apply_item_effect(item)
	_update_ui()

func _apply_item_effect(item: ShopItemData) -> void:
	var p := item.effect_params
	match item.effect_type:
		Enums.ItemEffect.STAT_BOOST:
			if p.has("stat"):
				GameData.player_stats[p["stat"]] += p["value"]
			elif p.has("stats"):
				for entry in p["stats"]:
					GameData.player_stats[entry["stat"]] += entry["value"]
		Enums.ItemEffect.TOWER_STAT:
			_apply_tower_stat(p)
		Enums.ItemEffect.CONSUMABLE:
			if p.get("effect") == "heal":
				GameData.pending_heal += p["value"]
		Enums.ItemEffect.PIERCE:
			GameData.pierce_count += p.get("pierce_count", 1)
		Enums.ItemEffect.MULTISHOT:
			GameData.multishot_active = true
			GameData.multishot_damage_mult = p.get("damage_mult", 1.0)
		Enums.ItemEffect.LIFESTEAL:
			GameData.lifesteal_ratio += p.get("ratio", 0.05)
		Enums.ItemEffect.KILL_STACK:
			GameData.kill_stack_max = max(GameData.kill_stack_max, p.get("max_stacks", 3))
			GameData.kill_stack_damage_per_stack += p.get("damage_per_stack", 0.2)
		Enums.ItemEffect.TOWER_LINK:
			GameData.tower_link_damage_per_tower += p.get("damage_per_tower", 0.04)
		Enums.ItemEffect.WAVE_GOLD:
			GameData.wave_gold_bonus += p.get("gold", 15)
		Enums.ItemEffect.WAVE_HEAL_TOWERS:
			GameData.wave_tower_heal_ratio += p.get("ratio", 0.20)
		Enums.ItemEffect.TOWER_REGEN:
			GameData.tower_regen_active = true
			GameData.tower_regen_hp += p.get("hp_per_interval", 5)
			GameData.tower_regen_interval = p.get("interval", 5.0)
		Enums.ItemEffect.SYMBIOSIS:
			GameData.symbiosis_hp_threshold = max(GameData.symbiosis_hp_threshold, p.get("hp_threshold", 0.30))
			GameData.symbiosis_tower_bonus += p.get("tower_damage_bonus", 0.60)
		Enums.ItemEffect.WAR_MACHINE:
			GameData.player_stats[Enums.Stat.DAMAGE_MULT] += p.get("damage_mult", 0.20)
			GameData.player_stats[Enums.Stat.TOWER_MULT] += p.get("tower_mult", 0.20)
			GameData.war_machine_active = true
			GameData.war_machine_wave_hp_cost += p.get("wave_hp_cost", 8)
		Enums.ItemEffect.BULLET_SPEED:
			GameData.bullet_speed_mult += p.get("mult", 0.2)
		Enums.ItemEffect.WEAPON_RANGE:
			GameData.weapon_range_mult += p.get("mult", 0.15)
		Enums.ItemEffect.CRIT:
			GameData.crit_chance += p.get("chance", 0.10)
		Enums.ItemEffect.SPLIT:
			GameData.split_count += p.get("count", 2)
		Enums.ItemEffect.WAVE_SHIELD:
			GameData.wave_shield_count += p.get("count", 1)
		Enums.ItemEffect.WAVE_HEAL_PLAYER:
			GameData.wave_heal_ratio += p.get("ratio", 0.10)
		Enums.ItemEffect.DAMAGE_REDUCTION:
			GameData.damage_reduction += p.get("ratio", 0.10)
		Enums.ItemEffect.DODGE:
			GameData.dodge_chance += p.get("chance", 0.15)
		Enums.ItemEffect.MAGNET:
			GameData.coin_magnet_mult += p.get("mult", 0.50)
		Enums.ItemEffect.SLOW_AURA:
			GameData.slow_aura_active = true
			GameData.slow_aura_ratio += p.get("ratio", 0.15)
			GameData.slow_aura_range = max(GameData.slow_aura_range, p.get("range", 100.0))
		Enums.ItemEffect.AUTO_DASH:
			GameData.auto_dash_active = true
			GameData.auto_dash_interval = min(GameData.auto_dash_interval, p.get("interval", 10.0))
			GameData.auto_dash_distance = max(GameData.auto_dash_distance, p.get("distance", 80.0))
		Enums.ItemEffect.DESTINY:
			pass  # 天命效果在 _generate_shop 时处理（购买后重新刷新出额外稀有物品）

func _apply_tower_stat(p: Dictionary) -> void:
	if p.has("stat"):
		_set_tower_stat(p["stat"], p["value"])
	elif p.has("stats"):
		for entry in p["stats"]:
			_set_tower_stat(entry["stat"], entry["value"])

func _set_tower_stat(stat: String, value: float) -> void:
	match stat:
		"tower_hp_mult":
			GameData.tower_hp_mult += value
		"tower_range_mult":
			GameData.tower_range_mult += value
		"tower_attack_speed_mult":
			GameData.tower_attack_speed_mult += value
		"tower_cost_mult":
			GameData.tower_cost_mult += value
		"tower_mult":
			GameData.player_stats[Enums.Stat.TOWER_MULT] += value
		"hp_mult":
			GameData.player_stats[Enums.Stat.HP_MULT] += value

# ===== UI =====

func _connect_slot_buy_button(i: int) -> void:
	var container: Node = item_containers[i]
	var buy_btn: Button
	# Item1 节点命名为 BuyButton，Item2/3/4 节点命名为 BuyButton2
	if i == 0:
		buy_btn = container.get_node("BuyButton")
	else:
		buy_btn = container.get_node("BuyButton2")
	if buy_btn:
		buy_btn.pressed.connect(_buy_item.bind(i))

func _connect_slot_lock_button(i: int) -> void:
	var container: Node = item_containers[i]
	var lock_btn_name := "LockButton" if i == 0 else "LockButton" + str(i + 1)
	if container.has_node(lock_btn_name):
		container.get_node(lock_btn_name).pressed.connect(_toggle_lock.bind(i))

func _toggle_lock(index: int) -> void:
	locked_slots[index] = not locked_slots[index]
	_update_ui()

func _update_ui() -> void:
	coin_label.text = "金币: %d" % GameData.coins
	var refresh_cost := _get_refresh_cost()
	refresh_button.disabled = GameData.coins < refresh_cost
	refresh_button.text = "刷新 (%d)" % refresh_cost
	_display_items()

func _display_items() -> void:
	for i in range(min(shop_items.size(), 4)):
		var item := shop_items[i]
		var price := shop_prices[i]
		var container: Node = item_containers[i]
		var name_label: Label
		var price_label: Label
		var buy_btn: Button
		# Item1 节点命名为 NameLabel/PriceLabel/BuyButton，Item2/3/4 命名为 NameLabel2/PriceLabel2/BuyButton2
		if i == 0:
			name_label = container.get_node("NameLabel")
			price_label = container.get_node("PriceLabel")
			buy_btn = container.get_node("BuyButton")
		else:
			name_label = container.get_node("NameLabel2")
			price_label = container.get_node("PriceLabel2")
			buy_btn = container.get_node("BuyButton2")
		if name_label:
			name_label.text = item.display_name
		if price_label:
			price_label.text = "价格: %d" % price
		if buy_btn:
			buy_btn.disabled = GameData.coins < price or not _can_buy(item)
		# 锁定按钮状态
		var lock_btn_name := "LockButton" if i == 0 else "LockButton" + str(i + 1)
		if container.has_node(lock_btn_name):
			container.get_node(lock_btn_name).text = "🔒" if locked_slots[i] else "🔓"
		# 稀有度/亲和边框色（通过 Panel 背景）
		_update_slot_color(container, item)

func _update_slot_color(container: Node, item: ShopItemData) -> void:
	if not container is PanelContainer:
		return
	var color := _get_slot_color(item)
	var style: StyleBox = container.get_theme_stylebox("panel")
	if style == null:
		return
	var new_style: StyleBox = style.duplicate()
	if new_style is StyleBoxFlat:
		var flat_style := new_style as StyleBoxFlat
		flat_style.border_color = color
		flat_style.border_width_left = 3
		flat_style.border_width_right = 3
		flat_style.border_width_top = 3
		flat_style.border_width_bottom = 3
		container.add_theme_stylebox_override("panel", flat_style)

func _get_slot_color(item: ShopItemData) -> Color:
	# 亲和色优先
	var affinity_tags := _get_affinity_tags()
	for tag in item.tags:
		if tag in affinity_tags:
			match tag:
				Enums.ItemTag.SHOOTER:  return Color(0.2, 0.5, 1.0)
				Enums.ItemTag.ENGINEER: return Color(0.2, 0.8, 0.3)
	# 稀有度色
	match item.rarity:
		Enums.ItemRarity.RARE: return Color(0.3, 0.6, 1.0)
		Enums.ItemRarity.EPIC: return Color(0.7, 0.3, 1.0)
		_: return Color(0.5, 0.5, 0.5)

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
