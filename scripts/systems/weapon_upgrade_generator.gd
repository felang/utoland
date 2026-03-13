class_name WeaponUpgradeGenerator
extends RefCounted

## 生成武器选择弹窗的选项列表
## 返回: Array[Dictionary]，每项 = {weapon_id: String, target_level: int, is_new: bool}
func generate_options() -> Array[Dictionary]:
	var pool: Array[Dictionary] = _build_pool()
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size()))

func _build_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for weapon_id: String in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		var current_level: int = GameData.owned_weapons.get(weapon_id, 0)
		if current_level == 0:
			pool.append({
				"weapon_id": weapon_id,
				"target_level": 1,
				"is_new": true,
			})
		elif current_level < wd.max_level:
			pool.append({
				"weapon_id": weapon_id,
				"target_level": current_level + 1,
				"is_new": false,
			})
	return pool
