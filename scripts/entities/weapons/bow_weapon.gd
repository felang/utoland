# BowWeapon — 单发射击的基础远程武器
class_name BowWeapon
extends Weapon

const ARROW_SPRITE_PATH := "res://assets/projectiles/arrow.png"

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		push_error("BowWeapon: owner has no parent scene")
		return
	var fire_pos: Vector2 = get_fire_position()
	var direction: Vector2 = fire_pos.direction_to(target.global_position)
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	bullet.speed = weapon_data.bullet_speed
	scene_parent.add_child(bullet)
	bullet.setup(base_damage, weapon_data.knockback_force, fire_pos, direction)
	# 添加箭矢精灵
	if ResourceLoader.exists(ARROW_SPRITE_PATH):
		var sprite := Sprite2D.new()
		sprite.texture = load(ARROW_SPRITE_PATH)
		sprite.rotation = direction.angle()
		bullet.add_child(sprite)
	AudioManager.play("shoot")
