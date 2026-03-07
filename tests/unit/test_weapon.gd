# test_weapon.gd — Weapon 基类单元测试
extends GutTest

func test_weapon_tick_decrements_cooldown():
	var w = Weapon.new()
	add_child_autofree(w)
	var data = WeaponData.new()
	data.fire_rate = 1.0
	data.damage = 10.0
	w.initialize(data)
	w._cooldown = 0.5

	var target = Node2D.new()
	add_child_autofree(target)
	w.tick(0.1, target)

	assert_almost_eq(w._cooldown, 0.4, 0.001)

func test_weapon_resets_cooldown_after_firing():
	var w = Weapon.new()
	add_child_autofree(w)
	var data = WeaponData.new()
	data.fire_rate = 0.5
	data.damage = 10.0
	w.initialize(data)
	w._cooldown = 0.0

	var target = Node2D.new()
	add_child_autofree(target)
	w.tick(0.016, target)

	# 冷却被重置为 fire_rate / attack_speed_mult
	assert_almost_eq(w._cooldown, 0.5, 0.01)
