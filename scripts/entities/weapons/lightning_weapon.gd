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
	# 超导风暴：目标被减速时 +2 链数，衰减为 1.0（无衰减）
	if GameData.active_pair_synergies.has("superconductor") and _is_target_slowed(target):
		chain.chain_count += 2
		chain.chain_decay = 1.0
	scene_parent.add_child(chain)
	chain.global_position = target.global_position
	chain.execute_chain(target, base_damage)
	AudioManager.play("shoot")

## 检查目标是否被减速
func _is_target_slowed(target: Node2D) -> bool:
	if not target or not is_instance_valid(target):
		return false
	var sh: SlowHandler = target.get_node_or_null("SlowHandler") as SlowHandler
	if sh and not sh._active_slows.is_empty():
		return true
	return false
