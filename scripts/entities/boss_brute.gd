extends "res://scripts/entities/boss_base.gd"

# Boss: 蛮兽 — 重型近战 Boss，周期性冲锋攻击

enum ChargeState { CHASE, WINDUP, CHARGING, STUNNED }

var _charge_state: int = ChargeState.CHASE
var _charge_timer: float = 0.0
var _charge_elapsed: float = 0.0
var _charge_direction: Vector2 = Vector2.ZERO
var _charge_duration: float = 0.6  # 冲锋持续时间
var _stun_duration: float = 0.5    # 眩晕持续时间
var _stun_timer: float = 0.0
var _original_damage: float = 0.0
var _min_charge_distance: float = 80.0  # 最小冲锋距离

func _ready() -> void:
	super._ready()
	_charge_timer = data.charge_cooldown
	_original_damage = data.damage

func _physics_process(delta: float) -> void:
	if data.charge_cooldown <= 0.0:
		# 没有冲锋数据则走普通 enemy 逻辑
		super._physics_process(delta)
		return

	match _charge_state:
		ChargeState.CHASE:
			_process_chase(delta)
		ChargeState.WINDUP:
			_process_windup(delta)
		ChargeState.CHARGING:
			_process_charging(delta)
		ChargeState.STUNNED:
			_process_stunned(delta)

func _process_chase(delta: float) -> void:
	# 正常追击（复用 enemy 逻辑）
	_chase_player()

	# 冲锋冷却计时
	_charge_timer -= delta
	if _charge_timer <= 0.0 and _can_charge():
		_start_windup()

func _can_charge() -> bool:
	if not player or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) > _min_charge_distance

func _start_windup() -> void:
	_charge_state = ChargeState.WINDUP
	_charge_elapsed = 0.0
	velocity = Vector2.ZERO
	# 闪红预警
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	AudioManager.play("boss_appear", -3.0)

func _process_windup(delta: float) -> void:
	_charge_elapsed += delta
	if _charge_elapsed >= data.charge_windup_time:
		_start_charge()

func _start_charge() -> void:
	_charge_state = ChargeState.CHARGING
	_charge_elapsed = 0.0
	# 锁定冲锋方向
	if player and is_instance_valid(player):
		_charge_direction = global_position.direction_to(player.global_position)
	else:
		_charge_direction = Vector2.RIGHT
	# 提高伤害
	_hitbox.damage = _original_damage * data.charge_damage_mult
	modulate = Color(1.8, 0.2, 0.2, 1.0)

func _process_charging(delta: float) -> void:
	_charge_elapsed += delta
	velocity = _charge_direction * speed * data.charge_speed_mult
	move_and_slide()
	_sprite_animator.update_animation_no_idle(velocity)

	if _charge_elapsed >= _charge_duration:
		_start_stun()

func _start_stun() -> void:
	_charge_state = ChargeState.STUNNED
	_stun_timer = _stun_duration
	velocity = Vector2.ZERO
	# 恢复正常伤害
	_hitbox.damage = _original_damage
	modulate = Color(0.7, 0.7, 0.7, 1.0)

func _process_stunned(delta: float) -> void:
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_charge_state = ChargeState.CHASE
		_charge_timer = data.charge_cooldown
		modulate = Color.WHITE
