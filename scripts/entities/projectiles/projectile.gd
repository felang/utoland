class_name Projectile
extends Node2D

var data: ProjectileData = null
var damage: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var _is_pooled: bool = false
var _should_destroy: bool = false

func setup(p_data: ProjectileData, dmg: float, from: Vector2, dir: Vector2) -> void:
	data = p_data
	damage = dmg
	direction = dir
	global_position = from
	_should_destroy = false
	# Hitbox 伤害值同步 + 碰撞连线
	var hitbox = get_node_or_null("Hitbox") as Hitbox
	if hitbox:
		hitbox.damage = dmg
		hitbox.monitoring = true  # 池化复用时重新启用碰撞检测
		if hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.disconnect(_on_hitbox_area_entered)
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	# 设置精灵（动态创建）
	_setup_sprite()
	# 设置旋转
	rotation = dir.angle()
	# 通知子组件初始化
	for child in get_children():
		if child.has_method("on_projectile_setup"):
			child.on_projectile_setup(self)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	var target: Node2D = area.get_parent()
	if target:
		on_hit(target)

func on_hit(target: Node2D) -> void:
	# 无穿透/弹射的投射物：命中后立即关闭碰撞，防止同帧多次命中
	if not _has_lifecycle_component():
		var hitbox = get_node_or_null("Hitbox") as Hitbox
		if hitbox:
			hitbox.set_deferred("monitoring", false)
	for child in get_children():
		if child.has_method("on_hit"):
			child.on_hit(target, self)
	EffectsManager.spawn_hit_sparks(global_position)
	if _should_destroy:
		request_destroy()
	elif not _has_lifecycle_component():
		request_destroy()

func _has_lifecycle_component() -> bool:
	for child in get_children():
		if child.get("manages_lifecycle"):
			return true
	return false

func reset_for_pool() -> void:
	_should_destroy = false
	var hitbox = get_node_or_null("Hitbox") as Hitbox
	if hitbox and hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.disconnect(_on_hitbox_area_entered)
	for child in get_children():
		if child.has_method("reset"):
			child.reset()
	_cleanup_sprite()

func request_destroy() -> void:
	SceneFactory.call_deferred("release_projectile", self)

func _setup_sprite() -> void:
	_cleanup_sprite()
	if not data or data.sprite_path.is_empty():
		return
	var texture: Texture2D = load(data.sprite_path)
	if not texture:
		return
	var sprite := Sprite2D.new()
	sprite.name = "_PooledSprite"
	sprite.texture = texture
	sprite.scale = Vector2(2, 2)  # 16px 素材适配 32px 网格
	add_child(sprite)

func _cleanup_sprite() -> void:
	var old_sprite = get_node_or_null("_PooledSprite")
	if old_sprite:
		old_sprite.queue_free()
