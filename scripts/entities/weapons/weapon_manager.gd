# WeaponManager — 统一管理玩家所有武器
# 每帧查找一次最近敌人，分发给所有武器的 tick()
class_name WeaponManager
extends Node

var _weapons: Array[Weapon] = []

func initialize(weapon_ids: Array[String]) -> void:
	for id in weapon_ids:
		if not GameConfig.weapons.has(id):
			push_error("WeaponManager: 未知武器 id: " + id)
			continue
		_add_weapon(GameConfig.weapons[id])

func _add_weapon(data: WeaponData) -> void:
	var weapon: Weapon = _create_weapon(data.projectile_type)
	if not weapon:
		return
	weapon.initialize(data)
	add_child(weapon)
	_weapons.append(weapon)

func tick(delta: float) -> void:
	var target: Node2D = _find_closest_enemy()
	for weapon in _weapons:
		weapon.tick(delta, target)

func _find_closest_enemy() -> Node2D:
	if not is_inside_tree():
		return null
	var owner_node: Node2D = get_parent() as Node2D
	if not owner_node:
		return null
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var min_dist: float = INF
	for enemy in enemies:
		if enemy is Node2D:
			var dist: float = owner_node.global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest

func _create_weapon(projectile_type: String) -> Weapon:
	match projectile_type:
		"bullet":    return BulletWeapon.new()
		"boomerang": return BoomerangWeapon.new()
		"laser":     return LaserWeapon.new()
	push_error("WeaponManager: 未知 projectile_type: " + projectile_type)
	return null
