# WeaponManager — 统一管理玩家所有武器
# 每帧查找一次最近敌人，分发给所有武器的 tick()
# 武器精灵围绕角色漂浮显示
class_name WeaponManager
extends Node2D

const ORBIT_RADIUS: float = 20.0
const ORBIT_SPEED: float = TAU / 2.0  # 1 圈 / 2 秒
const SPRITE_SIZE: int = 6

const WEAPON_COLORS: Dictionary = {
	"bow": Color.GREEN,
	"shuriken": Color.CORNFLOWER_BLUE,
	"sword": Color.RED,
}

var _weapons: Array[Weapon] = []
var _weapon_sprites: Array[Sprite2D] = []
var _orbit_angle: float = 0.0
var _current_target: Node2D = null

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
	# 创建漂浮精灵
	var sprite := _create_weapon_sprite(data)
	add_child(sprite)
	_weapon_sprites.append(sprite)
	weapon.sprite = sprite
	return weapon

func tick(delta: float) -> void:
	# 取所有武器中最大的射程作为搜索范围
	var max_range: float = 0.0
	for weapon in _weapons:
		if weapon.weapon_data:
			var wr: float = weapon.get_weapon_range()
			if wr > max_range:
				max_range = wr
	_current_target = _find_closest_enemy(max_range)
	for weapon in _weapons:
		weapon.tick(delta, _current_target)
	# 更新漂浮精灵位置
	_update_sprites(delta)

func _update_sprites(delta: float) -> void:
	if _weapon_sprites.is_empty():
		return
	var count: int = _weapon_sprites.size()
	var angle_step: float = TAU / count
	if _current_target == null:
		# 无目标：匀速环绕
		_orbit_angle += ORBIT_SPEED * delta
	else:
		# 有目标：朝向目标方向
		var owner_node: Node2D = get_parent() as Node2D
		if owner_node:
			var dir: Vector2 = owner_node.global_position.direction_to(_current_target.global_position)
			var target_angle: float = dir.angle()
			# 平滑过渡到目标角度
			_orbit_angle = lerp_angle(_orbit_angle, target_angle, 8.0 * delta)
	for i in range(count):
		var angle: float = _orbit_angle + angle_step * i
		_weapon_sprites[i].position = Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS
		# 精灵朝向轨道角度（素材默认朝下=PI/2，补偿 -PI/2）
		_weapon_sprites[i].rotation = angle - PI / 2.0

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
		"bow":       return BowWeapon.new()
		"shuriken": return ShurikenWeapon.new()
		"sword":     return SwordWeapon.new()
	push_error("WeaponManager: 未知 weapon_type: " + weapon_type)
	return null

func _create_weapon_sprite(data: WeaponData) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.z_index = 1
	# 优先加载 icon_path 图片，无则用彩色圆形占位
	if data.icon_path != "" and ResourceLoader.exists(data.icon_path):
		sprite.texture = load(data.icon_path)
	else:
		var color: Color = WEAPON_COLORS.get(data.weapon_type, Color.WHITE)
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
		sprite.texture = ImageTexture.create_from_image(img)
	return sprite
