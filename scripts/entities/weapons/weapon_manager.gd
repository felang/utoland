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
var _on_weapon_drag_callback: Callable

func set_weapon_drag_callback(callback: Callable) -> void:
	_on_weapon_drag_callback = callback

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

## 热更新：添加单个武器（商店购买后立即调用）
func add_weapon(weapon_id: String, level: int) -> void:
	if not GameConfig.weapons.has(weapon_id):
		push_error("WeaponManager: 未知武器 id: " + weapon_id)
		return
	var data: WeaponData = GameConfig.weapons[weapon_id]
	var weapon: Weapon = _add_weapon(data, weapon_id)
	if weapon:
		weapon.set_level(level)
		_apply_passive_to_weapon(weapon)

## 热更新：移除指定索引的武器（卖出时调用）
func remove_weapon(index: int) -> void:
	if index < 0 or index >= _weapons.size():
		return
	_weapons[index].queue_free()
	_weapons.remove_at(index)
	_weapon_sprites[index].queue_free()
	_weapon_sprites.remove_at(index)
	_sprite_rot_offsets.remove_at(index)

## 完全重建：清除所有武器并从 deployed_weapons 重新初始化
func refresh_weapons() -> void:
	for w in _weapons:
		w.queue_free()
	_weapons.clear()
	for s in _weapon_sprites:
		s.queue_free()
	_weapon_sprites.clear()
	_sprite_rot_offsets.clear()
	initialize(InventoryManager.deployed_weapons)

func _add_weapon(data: WeaponData, weapon_id: String) -> Weapon:
	var weapon: Weapon = _create_weapon(weapon_id)
	if not weapon:
		return null
	weapon.initialize(data)
	weapon.owner_node = get_parent() as Node2D
	weapon.attacker.target_finder = func(range_limit: float) -> Node2D:
		var origin: Vector2 = weapon.get_fire_position()
		return _find_nearest_enemy_from(origin, range_limit)
	add_child(weapon)
	_weapons.append(weapon)
	# 创建漂浮精灵
	var spr := _create_weapon_sprite(data, weapon_id)
	add_child(spr)
	_weapon_sprites.append(spr)
	_sprite_rot_offsets.append(SPRITE_ROTATION_OFFSET.get(weapon_id, 0.0))
	weapon.sprite = spr
	# 添加点击区域（供商店阶段拖拽卖出用）
	var click_area := Area2D.new()
	click_area.name = "ClickArea"
	click_area.input_pickable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = SPRITE_SIZE * 1.5
	shape.shape = circle
	click_area.add_child(shape)
	spr.add_child(click_area)
	click_area.input_event.connect(_on_weapon_click.bind(_weapons.size() - 1))
	return weapon

func tick(delta: float) -> void:
	for weapon in _weapons:
		weapon.attacker.tick(delta)
	_current_target = _find_closest_enemy_unlimited()
	_update_sprites(delta)

func _find_nearest_enemy_from(origin: Vector2, range_limit: float) -> Node2D:
	if not is_inside_tree():
		return null
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var closest: Node2D = null
	var min_dist: float = range_limit
	for enemy in enemies:
		if enemy is Node2D:
			var dist: float = origin.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest

func _find_closest_enemy_unlimited() -> Node2D:
	var owner_nd: Node2D = get_parent() as Node2D
	if not owner_nd:
		return null
	return _find_nearest_enemy_from(owner_nd.global_position, INF)

func _apply_passive_to_weapon(weapon: Weapon) -> void:
	var dmg_mult: float = PlayerState.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var spd_mult: float = PlayerState.player_stats.get(Enums.Stat.ATTACK_SPEED_MULT, 1.0)
	weapon.attacker.damage_multiplier = dmg_mult
	weapon.attacker.speed_multiplier = spd_mult

func _on_weapon_click(_viewport: Node, event: InputEvent, _shape_idx: int, weapon_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _on_weapon_drag_callback.is_valid():
			_on_weapon_drag_callback.call(weapon_index)

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
