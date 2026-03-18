# WeaponManager — Pivot+Offset 架构统一管理玩家所有武器
# Pivot.position 在轨道圆上移动（无旋转），Offset.position=(0,0) 仅在近战突刺时变化
# TargetFinder 挂在 Pivot 下（索敌中心=轨道位置），攻击组件挂在 Offset 下
class_name WeaponManager
extends Node2D

signal weapon_attack_executed(target: Node2D)  # 任意武器命中时广播（用于 swift_combo 连击更新）

const ORBIT_SPEED: float = TAU / 12.0
const SPRITE_SCALE: float = 12.0

# 武器精灵颜色映射（后备方案，无 icon 时使用）
const WEAPON_COLORS: Dictionary = {
	"bow": Color.GREEN,
	"shuriken": Color.CORNFLOWER_BLUE,
	"sword": Color.RED,
}

var _pivots: Array[Node2D] = []
var _weapon_data_list: Array[WeaponData] = []
var _orbit_angle: float = 0.0
var _projectile_container: Node = null
## 动态伤害倍率回调（由 Player 注入，用于 swift_combo/blood_rage 等动态被动）
var _dynamic_damage_mult_getter: Callable

func _ready() -> void:
	# 使用 SceneFactory 分层容器
	_projectile_container = SceneFactory.get_projectile_layer()

## 清除所有武器并从传入的 weapon_entries 创建
func initialize(weapon_entries: Array[Dictionary]) -> void:
	_clear_all()
	for entry in weapon_entries:
		add_weapon(entry.id, entry.level)

## 热更新：添加单个武器（商店购买后立即调用）
func add_weapon(weapon_id: String, level: int) -> void:
	if not GameConfig.weapons.has(weapon_id):
		push_error("WeaponManager: 未知武器 id: " + weapon_id)
		return
	var weapon_data: WeaponData = GameConfig.weapons[weapon_id]
	_weapon_data_list.append(weapon_data)

	# 创建 Pivot
	var pivot := Node2D.new()
	pivot.name = "WeaponPivot_%d" % _pivots.size()
	add_child(pivot)

	# 创建 WeaponOffset（初始位置 0,0，突刺时才改变）
	var offset := Node2D.new()
	offset.name = "WeaponOffset"
	offset.position = Vector2.ZERO
	pivot.add_child(offset)

	var sprite := Sprite2D.new()
	sprite.name = "WeaponSprite"
	sprite.rotation = weapon_data.sprite_rotation_offset
	_setup_weapon_sprite(sprite, weapon_id)
	sprite.scale = Vector2(2, 2)
	offset.add_child(sprite)

	var fire_point := Marker2D.new()
	fire_point.name = "FirePoint"
	offset.add_child(fire_point)

	# 索敌和攻击组件挂在 Pivot 下（不受 Offset 突刺偏移影响）
	var finder := TargetFinderComponent.new()
	finder.name = "TargetFinderComponent"
	pivot.add_child(finder)

	if weapon_data.projectile_data:
		var ranged := RangedAttackComponent.new()
		ranged.name = "RangedAttackComponent"
		ranged.attack_config = weapon_data.attack_config
		ranged.projectile_data = weapon_data.projectile_data
		ranged.projectile_spawned.connect(_on_projectile_spawned)
		ranged.attack_executed.connect(func(t: Node2D, _p: Node2D) -> void:
			_on_attack_executed(pivot, weapon_data, t)
		)
		pivot.add_child(ranged)
		ranged.set_level(level)
	elif weapon_data.melee_config:
		var melee := MeleeAttackComponent.new()
		melee.name = "MeleeAttackComponent"
		melee.attack_config = weapon_data.attack_config
		melee.melee_config = weapon_data.melee_config
		melee.attack_executed.connect(func(t: Node2D) -> void:
			_on_attack_executed(pivot, weapon_data, t)
		)
		pivot.add_child(melee)
		melee.set_level(level)

	_pivots.append(pivot)
	# 注入被动加成
	_apply_passive_to_pivot(pivot)
	_redistribute_angles()

## 热更新：移除指定索引的武器（卖出时调用）
func remove_weapon(index: int) -> void:
	if index < 0 or index >= _pivots.size():
		return
	var pivot: Node2D = _pivots[index]
	_pivots.remove_at(index)
	_weapon_data_list.remove_at(index)
	pivot.queue_free()
	_redistribute_angles()

## 完全重建：清除所有武器并从 InventoryManager.deployed_weapons 重新初始化
func refresh_weapons() -> void:
	_clear_all()
	for entry in InventoryManager.deployed_weapons:
		add_weapon(entry.id, entry.level)

## 每帧视觉更新（_process 调用）：推进轨道角度、旋转 Pivot、精灵朝向目标
func tick_visual(delta: float) -> void:
	_orbit_angle += ORBIT_SPEED * delta
	var count: int = _pivots.size()
	for i in count:
		var pivot: Node2D = _pivots[i]
		var weapon_data: WeaponData = _weapon_data_list[i] if i < _weapon_data_list.size() else null
		# Pivot 用 position 在轨道圆上移动（不旋转）
		var base_angle: float = _orbit_angle + (TAU / max(count, 1)) * i
		var poff: float = weapon_data.pivot_offset if weapon_data else 15.0
		pivot.position = Vector2(poff, 0).rotated(base_angle)
		# 精灵朝向目标（仅旋转精灵）
		var finder = pivot.get_node_or_null("TargetFinderComponent")
		var target: Node2D = finder.get_target() if finder else null
		var sprite = pivot.get_node_or_null("WeaponOffset/WeaponSprite")
		var rot_offset: float = weapon_data.sprite_rotation_offset if weapon_data else 0.0
		if target and is_instance_valid(target) and sprite:
			var aim_angle: float = pivot.global_position.angle_to_point(target.global_position)
			sprite.rotation = aim_angle + rot_offset
		elif sprite:
			sprite.rotation = rot_offset

## 物理帧攻击判定（_physics_process 调用）：驱动攻击组件，确保与物理检测同步
func tick_combat(delta: float) -> void:
	# 计算动态伤害倍率（swift_combo / blood_rage 等每帧变化的被动）
	var dynamic_dmg_mult: float = 1.0
	if _dynamic_damage_mult_getter.is_valid():
		dynamic_dmg_mult = _dynamic_damage_mult_getter.call()
	var base_dmg_mult: float = PlayerState.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var count: int = _pivots.size()
	for i in count:
		var pivot: Node2D = _pivots[i]
		# 驱动攻击组件（在 Pivot 下）
		var attack = pivot.get_node_or_null("RangedAttackComponent")
		if not attack:
			attack = pivot.get_node_or_null("MeleeAttackComponent")
		if attack:
			attack.damage_multiplier = base_dmg_mult * dynamic_dmg_mult
			attack.tick(delta)

## 注入动态伤害倍率回调（Player 调用，用于 swift_combo/blood_rage 等每帧变化的被动）
func set_dynamic_damage_mult_getter(getter: Callable) -> void:
	_dynamic_damage_mult_getter = getter

# — 内部方法 —

func _on_projectile_spawned(proj: Node2D) -> void:
	if _projectile_container and is_instance_valid(_projectile_container):
		_projectile_container.add_child(proj)
	else:
		# 后备：重新获取投射物容器
		_projectile_container = SceneFactory.get_projectile_layer()
		if _projectile_container:
			_projectile_container.add_child(proj)

func _on_attack_executed(pivot: Node2D, weapon_data: WeaponData, target: Node2D = null) -> void:
	# 广播命中信号，供 Player 更新连击状态
	if target and is_instance_valid(target):
		weapon_attack_executed.emit(target)
	if not weapon_data.hide_sprite_on_fire:
		return
	var sprite = pivot.get_node_or_null("WeaponOffset/WeaponSprite")
	if not sprite:
		return
	sprite.visible = false
	var attack_comp = pivot.get_node_or_null("RangedAttackComponent")
	if attack_comp:
		var restore_time: float = attack_comp.get_final_cooldown() * weapon_data.sprite_restore_ratio
		get_tree().create_timer(restore_time).timeout.connect(func() -> void:
			if is_instance_valid(sprite):
				sprite.visible = true
		)

func _apply_passive_to_pivot(pivot: Node2D) -> void:
	var dmg_mult: float = PlayerState.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var spd_mult: float = PlayerState.player_stats.get(Enums.Stat.ATTACK_SPEED_MULT, 1.0)
	var attack = pivot.get_node_or_null("RangedAttackComponent")
	if not attack:
		attack = pivot.get_node_or_null("MeleeAttackComponent")
	if attack:
		attack.damage_multiplier = dmg_mult
		attack.speed_multiplier = spd_mult

func _redistribute_angles() -> void:
	# 均匀分布初始角度偏移；实际旋转由 tick() 控制
	pass

## 在 pivot 的 WeaponOffset 子树中查找节点
func _find_in_offset(pivot: Node2D, node_name: String) -> Node:
	var offset = pivot.get_node_or_null("WeaponOffset")
	if offset:
		return offset.get_node_or_null(node_name)
	return null

func _clear_all() -> void:
	for pivot in _pivots:
		pivot.queue_free()
	_pivots.clear()
	_weapon_data_list.clear()

func _setup_weapon_sprite(sprite: Sprite2D, weapon_id: String) -> void:
	var weapon_data: WeaponData = GameConfig.weapons.get(weapon_id)
	if weapon_data and not weapon_data.icon_path.is_empty():
		if ResourceLoader.exists(weapon_data.icon_path):
			var tex: Texture2D = load(weapon_data.icon_path)
			if tex:
				sprite.texture = tex
				return
	# 后备：彩色方块
	var size: int = SPRITE_SCALE as int
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var color: Color = WEAPON_COLORS.get(weapon_id, Color.WHITE)
	img.fill(color)
	sprite.texture = ImageTexture.create_from_image(img)
