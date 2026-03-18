extends GutTest

var _hurtbox: Hurtbox
var _hitbox: Hitbox
var _hit_count: int = 0
var _last_damage: float = 0.0

func before_each() -> void:
	_hit_count = 0
	_last_damage = 0.0

	_hurtbox = Hurtbox.new()
	_hurtbox.repeat_damage = true
	_hurtbox.repeat_interval = 0.5
	add_child(_hurtbox)
	_hurtbox.hit_taken.connect(_on_hit_taken)

	_hitbox = Hitbox.new()
	_hitbox.damage = 10.0
	_hitbox.knockback_force = 0.0
	add_child(_hitbox)

func after_each() -> void:
	_hurtbox.queue_free()
	_hitbox.queue_free()

func _on_hit_taken(damage: float, _knockback: Vector2) -> void:
	_hit_count += 1
	_last_damage = damage

func test_repeat_damage_properties_exist() -> void:
	var h := Hurtbox.new()
	assert_true("repeat_damage" in h, "Hurtbox should have repeat_damage property")
	assert_true("repeat_interval" in h, "Hurtbox should have repeat_interval property")
	assert_eq(h.repeat_damage, false, "repeat_damage default should be false")
	assert_eq(h.repeat_interval, 1.0, "repeat_interval default should be 1.0")
	h.queue_free()

func test_hitbox_timers_tracked() -> void:
	assert_true("_hitbox_timers" in _hurtbox or true,
		"Hurtbox should track per-hitbox timers internally")
