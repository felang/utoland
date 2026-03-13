# LightningWeapon — 瞬时链式跳跃伤害
class_name LightningWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		return
	var chain: ChainProjectile = SceneFactory.create_chain_projectile()
	chain.chain_count = weapon_data.chain_count
	chain.chain_decay = weapon_data.chain_decay
	chain.chain_range = weapon_data.chain_range
	scene_parent.add_child(chain)
	chain.global_position = target.global_position
	chain.execute_chain(target, base_damage)
	AudioManager.play("shoot")
