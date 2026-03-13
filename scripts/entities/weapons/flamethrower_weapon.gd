# FlamethrowerWeapon — 维持单个 FlameProjectile 持续伤害
class_name FlamethrowerWeapon
extends Weapon

var _flame: FlameProjectile = null

func fire(_target: Node2D) -> void:
	# 持续型，不使用 cooldown fire 模式
	pass

func tick(delta: float, target: Node2D) -> void:
	if not _flame or not is_instance_valid(_flame):
		_create_flame()
	if target:
		_flame.visible = true
		_flame.global_position = owner_node.global_position
		_flame.update_direction(target.global_position)
		_flame.flame_damage = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	else:
		_flame.visible = false

func _create_flame() -> void:
	_flame = SceneFactory.create_flame_projectile()
	_flame.flame_range = get_weapon_range()
	_flame.cone_angle = weapon_data.flame_cone_angle
	var scene_parent: Node = owner_node.get_parent()
	if scene_parent:
		scene_parent.add_child(_flame)
