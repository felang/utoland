# ShurikenWeapon — 手里剑武器（自身即投射物）
# 发射时漂浮精灵隐藏，冷却结束后恢复
class_name ShurikenWeapon
extends Weapon

const SHURIKEN_SPRITE_PATH := "res://assets/projectiles/shuriken.png"

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var final_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var fire_pos: Vector2 = get_fire_position()
	var direction: Vector2 = fire_pos.direction_to(target.global_position)
	var shuriken: ShurikenProjectile = SceneFactory.create_shuriken_projectile()
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		push_error("ShurikenWeapon: owner has no parent scene")
		return
	# 给投射物添加精灵
	if ResourceLoader.exists(SHURIKEN_SPRITE_PATH):
		var proj_sprite := Sprite2D.new()
		proj_sprite.texture = load(SHURIKEN_SPRITE_PATH)
		shuriken.add_child(proj_sprite)
	scene_parent.add_child(shuriken)
	shuriken.set_player(owner_node)
	shuriken.weapon_data = weapon_data
	shuriken.setup(final_damage, weapon_data.knockback_force, fire_pos, direction)
	# 隐藏漂浮精灵
	if sprite and is_instance_valid(sprite):
		sprite.visible = false

func tick(delta: float, target: Node2D) -> void:
	_cooldown -= delta
	# 冷却结束时恢复漂浮精灵
	if _cooldown <= 0.0 and sprite and is_instance_valid(sprite):
		sprite.visible = true
	if _cooldown <= 0.0 and target:
		fire(target)
		var speed_mult: float = GameData.player_stats.get(Enums.Stat.ATTACK_SPEED_MULT, 1.0)
		_cooldown = get_fire_rate() / speed_mult
