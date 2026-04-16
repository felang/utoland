extends GutTest

const PERK_IDS: Array[String] = [
	"vitality", "swift", "power", "rapid",
	"reach", "greed", "study", "expansion",
]

func test_all_perk_files_load() -> void:
	for id in PERK_IDS:
		var path: String = "res://resources/perks/%s.tres" % id
		assert_true(ResourceLoader.exists(path), "perk 文件不存在: " + path)
		var perk: PerkData = load(path)
		assert_not_null(perk, "perk 加载失败: " + path)
		assert_eq(perk.id, id, "perk id 不匹配: " + path)

func test_vitality_effect() -> void:
	var perk: PerkData = load("res://resources/perks/vitality.tres")
	assert_eq(perk.effect_type, PerkData.EffectType.HP_PERCENT)
	assert_almost_eq(perk.effect_value, 0.1, 0.001)

func test_expansion_effect() -> void:
	var perk: PerkData = load("res://resources/perks/expansion.tres")
	assert_eq(perk.effect_type, PerkData.EffectType.POPULATION_FLAT)
	assert_almost_eq(perk.effect_value, 1.0, 0.001)
