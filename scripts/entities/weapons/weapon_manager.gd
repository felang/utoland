# WeaponManager — 统一管理玩家所有武器
# 每帧查找一次最近敌人，分发给所有武器的 tick()
class_name WeaponManager
extends Node

var _weapons: Array[Weapon] = []

func initialize(weapon_entries: Array[Dictionary]) -> void:
	for entry in weapon_entries:
		if not GameConfig.weapons.has(entry.id):
			push_error("WeaponManager: 未知武器 id: " + entry.id)
			continue
		var weapon: Weapon = _add_weapon(GameConfig.weapons[entry.id])
		if weapon:
			weapon.set_level(entry.level)

func _add_weapon(data: WeaponData) -> Weapon:
	var weapon: Weapon = _create_weapon(data.weapon_type)
	if not weapon:
		return null
	weapon.initialize(data)
	weapon.owner_node = get_parent() as Node2D
	add_child(weapon)
	_weapons.append(weapon)
	return weapon

func tick(delta: float) -> void:
	# 取所有武器中最大的射程作为搜索范围
	var max_range: float = 0.0
	for weapon in _weapons:
		if weapon.weapon_data:
			var wr: float = weapon.get_weapon_range()
			if wr > max_range:
				max_range = wr
	var target: Node2D = _find_closest_enemy(max_range)
	for weapon in _weapons:
		weapon.tick(delta, target)

func _find_closest_enemy(range_limit: float = INF) -> Node2D:
	if not is_inside_tree():
		return null
	var owner_node: Node2D = get_parent() as Node2D
	if not owner_node:
		return null
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var closest: Node2D = null
	var min_dist: float = range_limit  # 只考虑射程内的敌人
	for enemy in enemies:
		if enemy is Node2D:
			var dist: float = owner_node.global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest

func _create_weapon(weapon_type: String) -> Weapon:
	match weapon_type:
		"bullet":    return BulletWeapon.new()
		"boomerang": return BoomerangWeapon.new()
		"laser":     return LaserWeapon.new()
		"shotgun":   return ShotgunWeapon.new()
		"minigun":   return BulletWeapon.new()
		"ice_gun":   return IceGunWeapon.new()
		"rocket":    return RocketWeapon.new()
		"lightning": return LightningWeapon.new()
		"blade":     return BladeWeapon.new()
		"flamethrower": return FlamethrowerWeapon.new()
	push_error("WeaponManager: 未知 weapon_type: " + weapon_type)
	return null
