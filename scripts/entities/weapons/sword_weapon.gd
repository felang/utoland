# SwordWeapon — 前方扇形挥砍近战武器
class_name SwordWeapon
extends Weapon

const SLASH_ANGLE: float = 90.0  # 扇形角度（度）

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var attack_range: float = get_weapon_range()
	var half_angle: float = deg_to_rad(SLASH_ANGLE / 2.0)

	# 查找扇形范围内的敌人
	if not owner_node.is_inside_tree():
		return
	var enemies: Array[Node] = owner_node.get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	for enemy in enemies:
		if enemy is Node2D:
			var to_enemy: Vector2 = enemy.global_position - owner_node.global_position
			var dist: float = to_enemy.length()
			if dist > attack_range:
				continue
			var angle: float = direction.angle_to(to_enemy.normalized())
			if absf(angle) <= half_angle:
				if enemy.has_node("Hurtbox"):
					var hurtbox: Hurtbox = enemy.get_node("Hurtbox")
					hurtbox.take_hit(base_damage, direction * weapon_data.knockback_force)
				EffectsManager.spawn_hit_sparks(enemy.global_position)
	AudioManager.play("shoot")
