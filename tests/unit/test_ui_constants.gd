extends GutTest

func test_colors_defined() -> void:
	assert_not_null(UIConstants.COLOR_BG_PRIMARY)
	assert_not_null(UIConstants.COLOR_BG_PANEL)
	assert_not_null(UIConstants.COLOR_ACCENT_DANGER)
	assert_not_null(UIConstants.COLOR_GOLD)
	assert_not_null(UIConstants.COLOR_POSITIVE)
	assert_not_null(UIConstants.COLOR_RARITY_COMMON)
	assert_not_null(UIConstants.COLOR_RARITY_RARE)
	assert_not_null(UIConstants.COLOR_RARITY_EPIC)

func test_font_sizes_defined() -> void:
	assert_eq(UIConstants.FONT_SIZE_TITLE, 32)
	assert_eq(UIConstants.FONT_SIZE_SUBTITLE, 24)
	assert_eq(UIConstants.FONT_SIZE_BODY, 18)
	assert_eq(UIConstants.FONT_SIZE_SMALL, 14)

func test_rarity_color_helper() -> void:
	assert_eq(UIConstants.get_rarity_color("common"), UIConstants.COLOR_RARITY_COMMON)
	assert_eq(UIConstants.get_rarity_color("rare"), UIConstants.COLOR_RARITY_RARE)
	assert_eq(UIConstants.get_rarity_color("epic"), UIConstants.COLOR_RARITY_EPIC)
	assert_eq(UIConstants.get_rarity_color("unknown"), UIConstants.COLOR_RARITY_COMMON)
