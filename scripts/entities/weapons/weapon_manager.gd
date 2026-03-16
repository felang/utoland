# WeaponManager — 统一管理玩家所有武器
class_name WeaponManager
extends Node2D

const ORBIT_RADIUS: float = 15.0
const ORBIT_SPEED: float = TAU / 8.0
const SPRITE_SIZE: int = 6

const WEAPON_COLORS: Dictionary = {
	"bow": Color.GREEN,
	"shuriken": Color.CORNFLOWER_BLUE,
	"sword": Color.RED,
}

const SPRITE_ROTATION_OFFSET: Dictionary = {
	"bow": -PI / 2.0,
	"shuriken": 0.0,
	"sword": PI / 2.0,
}

var _weapons: Array[Weapon] = []
var _weapon_sprites: Array[Sprite2D] = []
var _sprite_rot_offsets: Array[float] = []
var _orbit_angle: float = 0.0
var _current_target: Node2D = null

func initialize(weapon_entries: Array[Dictionary]) -> void:
	for entry in weapon_entries:
		if not GameConfig.weapons.has(entry.id):
			push_error("WeaponManager: 未知武器 id: " + entry.id)
			continue
		var data: WeaponData = GameConfig.weapons[entry.id]
		var weapon: Weapon = _add_weapon(data, entry.id)
		if weapon:
			weapon.set_level(entry.level)
			_apply_passive_to_weapon(weapon)

func _add_weapon(data: WeaponData, weapon_id: String) -> Weapon:
	var weapon: Weapon = _create_weapon(weapon_id)
	if not weapon:
		return null
	weapon.initialize(data)
	weapon.owner_node = get_parent() as Node2D
	weapon.attacker.target_finder = _find_nearest_enemy
	add_child(weapon)
	_weapons.append(weapon)
	# 创建漂浮精灵
	var spr := _create_weapon_sprite(data, weapon_id)
	add_child(spr)
	_weapon_sprites.append(spr)
	_sprite_rot_offsets.append(SPRITE_ROTATION_OFFSET.get(weapon_id, 0.0))
	weapon.sprite = spr
	# 监听投射物创建（分裂系统，Task 18）
	weapon.projectile_created.connect(_on_weapon_projectile_created)
	return weapon

func tick(delta: float) -> void:
	for weapon in _weapons:
		weapon.attacker.tick(delta)
	_current_target = _find_closest_enemy_unlimited()
	_update_sprites(delta)

func _find_nearest_enemy(range_limit: float) -> Node2D:
	if not is_inside_tree():
		return null
	var owner_nd: Node2D = get_parent() as Node2D
	if not owner_nd:
		return null
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var closest: Node2D = null
	var min_dist: float = range_limit
	for enemy in enemies:
		if enemy is Node2D:
			var dist: float = owner_nd.global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest

func _find_closest_enemy_unlimited() -> Node2D:
	return _find_nearest_enemy(INF)

func _apply_passive_to_weapon(weapon: Weapon) -> void:
	var dmg_mult: float = GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var spd_mult: float = GameData.player_stats.get(Enums.Stat.ATTACK_SPEED_MULT, 1.0)
	weapon.attacker.damage_multiplier = dmg_mult
	weapon.attacker.speed_multiplier = spd_mult

func _on_weapon_projectile_created(proj: ProjectileBase) -> void:
	# 分裂系统占位（Task 18 实现）
	pass

func _create_weapon(weapon_id: String) -> Weapon:
	match weapon_id:
		"shuriken":
			return ShurikenWeapon.new()
		_:
			return Weapon.new()

func _update_sprites(delta: float) -> void:
	if _weapon_sprites.is_empty():
		return
	_orbit_angle += ORBIT_SPEED * delta
	var count: int = _weapon_sprites.size()
	var angle_step: float = TAU / count
	var has_target: bool = _current_target != null and is_instance_valid(_current_target)
	var target_angle: float = 0.0
	if has_target:
		var owner_nd: Node2D = get_parent() as Node2D
		if owner_nd:
			target_angle = owner_nd.global_position.direction_to(_current_target.global_position).angle()
	for i in range(count):
		var slot_angle: float = _orbit_angle + angle_step * i
		_weapon_sprites[i].position = Vector2(cos(slot_angle), sin(slot_angle)) * ORBIT_RADIUS
		var face_angle: float
		if has_target:
			face_angle = target_angle
		else:
			face_angle = slot_angle
		_weapon_sprites[i].rotation = face_angle + _sprite_rot_offsets[i]

func _create_weapon_sprite(data: WeaponData, weapon_id: String) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.z_index = 1
	if data.icon_path != "" and ResourceLoader.exists(data.icon_path):
		spr.texture = load(data.icon_path)
	else:
		var color: Color = WEAPON_COLORS.get(weapon_id, Color.WHITE)
		var img := Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
		var center := Vector2(SPRITE_SIZE / 2.0, SPRITE_SIZE / 2.0)
		var radius: float = SPRITE_SIZE / 2.0
		for x in range(SPRITE_SIZE):
			for y in range(SPRITE_SIZE):
				var dist: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
				if dist <= radius:
					img.set_pixel(x, y, color)
				else:
					img.set_pixel(x, y, Color.TRANSPARENT)
		spr.texture = ImageTexture.create_from_image(img)
	return spr
