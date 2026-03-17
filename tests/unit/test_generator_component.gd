extends GutTest

var comp: GeneratorComponent

func before_each() -> void:
	comp = GeneratorComponent.new()
	add_child(comp)

func after_each() -> void:
	comp.queue_free()

func test_set_level_updates_amount() -> void:
	var cfg := GeneratorConfigData.new()
	cfg.generate_amount_per_level = PackedFloat32Array([5, 8, 12])
	cfg.generate_interval_per_level = PackedFloat32Array([10, 8, 6])
	comp.config = cfg
	comp.set_level(2)
	assert_eq(comp._amount, 8)
	assert_almost_eq(comp._interval, 8.0, 0.01)

func test_generated_signal_exists() -> void:
	assert_has_signal(comp, "generated")
