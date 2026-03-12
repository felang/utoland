class_name ShopItemGenerator
extends RefCounted

# 稀有度概率表（按波次）
const RARITY_TABLE: Array = [
	{"from": 1,  "weights": {"common": 100, "rare": 0,  "epic": 0}},
	{"from": 4,  "weights": {"common": 70,  "rare": 30, "epic": 0}},
	{"from": 7,  "weights": {"common": 40,  "rare": 50, "epic": 10}},
	{"from": 10, "weights": {"common": 20,  "rare": 50, "epic": 30}},
]


func get_rarity_weights(wave: int) -> Dictionary:
	var result: Dictionary = {}
	for entry in RARITY_TABLE:
		if wave >= entry["from"]:
			result = entry["weights"]
	return result

func pick_rarity(wave: int) -> String:
	var weights := get_rarity_weights(wave)
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

func calculate_price(item: ShopItemData, affinity_tags: PackedStringArray, affinity_discount: float) -> int:
	var base := randi_range(item.cost_min, item.cost_max)
	for tag in item.tags:
		if tag in affinity_tags:
			return max(1, int(base * (1.0 - affinity_discount)))
	return base

func can_buy(item: ShopItemData) -> bool:
	if item.max_stack == -1:
		return true
	var bought: int = GameData.purchased_items.get(item.id, 0)
	return bought < item.max_stack

func generate_items(wave: int, affinity_tags: PackedStringArray, affinity_discount: float,
		locked_slots: Array[bool], current_items: Array[ShopItemData], current_prices: Array[int]) -> Dictionary:
	var by_rarity: Dictionary = {
		Enums.ItemRarity.COMMON: [],
		Enums.ItemRarity.RARE: [],
		Enums.ItemRarity.EPIC: [],
	}
	for item in GameConfig.items.values():
		if by_rarity.has(item.rarity):
			by_rarity[item.rarity].append(item)

	# 处理天命史诗物品：本局只能出现一次
	var destiny_bought: bool = GameData.purchased_items.get("destiny", 0) > 0

	var items: Array[ShopItemData] = current_items.duplicate()
	var prices: Array[int] = current_prices.duplicate()

	for i in range(4):
		if locked_slots[i] and i < items.size():
			continue
		var rarity := pick_rarity(wave)
		var pool: Array = by_rarity[rarity].filter(func(it: ShopItemData) -> bool:
			if it.id == "destiny" and destiny_bought:
				return false
			return can_buy(it)
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
		if i < items.size():
			items[i] = picked
			prices[i] = calculate_price(picked, affinity_tags, affinity_discount)
		else:
			items.append(picked)
			prices.append(calculate_price(picked, affinity_tags, affinity_discount))

	return {"items": items, "prices": prices}
