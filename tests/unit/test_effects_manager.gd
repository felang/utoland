extends GutTest

# EffectsManager 单元测试

func test_effects_manager_exists():
	assert_not_null(EffectsManager, "EffectsManager autoload 应存在")

func test_effects_manager_has_spawn_methods():
	assert_true(EffectsManager.has_method("spawn_damage_number"), "应有 spawn_damage_number 方法")
	assert_true(EffectsManager.has_method("spawn_hit_sparks"), "应有 spawn_hit_sparks 方法")
	assert_true(EffectsManager.has_method("spawn_death_effect"), "应有 spawn_death_effect 方法")
