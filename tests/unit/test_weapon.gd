# test_weapon.gd — Weapon 基类单元测试
extends GutTest

func test_weapon_tick_decrements_cooldown():
	var w = Weapon.new()
	add_child_autofree(w)
	var data = WeaponData.new()
	data.id = "test_weapon_tick"
	data.fire_rate_per_level = PackedFloat32Array([1.0])
	data.damage_per_level = PackedFloat32Array([10.0])
	data.weapon_range_per_level = PackedFloat32Array([300.0])
	GameData.owned_weapons[data.id] = 1
	w.initialize(data)
	w._cooldown = 0.5

	var target = Node2D.new()
	add_child_autofree(target)
	w.tick(0.1, target)

	assert_almost_eq(w._cooldown, 0.4, 0.001)
	GameData.owned_weapons.erase(data.id)

func test_weapon_resets_cooldown_after_firing():
	# 重置 player_stats 确保 attack_speed_mult = 1.0，隔离跨测试状态
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	var w = Weapon.new()
	add_child_autofree(w)
	var data = WeaponData.new()
	data.id = "test_weapon_cd"
	data.fire_rate_per_level = PackedFloat32Array([0.5])
	data.damage_per_level = PackedFloat32Array([10.0])
	data.weapon_range_per_level = PackedFloat32Array([300.0])
	GameData.owned_weapons[data.id] = 1
	w.initialize(data)
	w._cooldown = 0.0

	var target = Node2D.new()
	add_child_autofree(target)
	w.tick(0.016, target)

	# 冷却被重置为 fire_rate / attack_speed_mult
	assert_almost_eq(w._cooldown, 0.5, 0.01)
	GameData.owned_weapons.erase(data.id)
