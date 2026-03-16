extends GutTest

func test_colors_defined() -> void:
	assert_not_null(UIConstants.COLOR_BG_PRIMARY)
	assert_not_null(UIConstants.COLOR_BG_PANEL)
	assert_not_null(UIConstants.COLOR_ACCENT_DANGER)
	assert_not_null(UIConstants.COLOR_GOLD)
	assert_not_null(UIConstants.COLOR_POSITIVE)

func test_font_sizes_defined() -> void:
	assert_eq(UIConstants.FONT_SIZE_TITLE, 32)
	assert_eq(UIConstants.FONT_SIZE_SUBTITLE, 24)
	assert_eq(UIConstants.FONT_SIZE_BODY, 18)
	assert_eq(UIConstants.FONT_SIZE_SMALL, 14)
