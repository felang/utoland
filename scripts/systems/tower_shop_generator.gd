class_name TowerShopGenerator
extends RefCounted

## 生成塔商店选项
## 返回: {items: Array[Dictionary], prices: Array[int]}
## 每项 item = {tower_id: String, target_level: int, is_new: bool}
func generate_options() -> Dictionary:
	var pool: Array[Dictionary] = _build_pool()
	pool.shuffle()
	var selected: Array[Dictionary] = pool.slice(0, mini(3, pool.size()))
	var prices: Array[int] = []
	for item: Dictionary in selected:
		var td: TowerData = GameConfig.towers[item["tower_id"]]
		prices.append(td.shop_price_per_level[item["target_level"] - 1])
	return {"items": selected, "prices": prices}

func _build_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for tower_id: String in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		var current_level: int = GameData.owned_towers.get(tower_id, 0)
		if current_level == 0:
			pool.append({
				"tower_id": tower_id,
				"target_level": 1,
				"is_new": true,
			})
		elif current_level < td.max_level:
			pool.append({
				"tower_id": tower_id,
				"target_level": current_level + 1,
				"is_new": false,
			})
	return pool
