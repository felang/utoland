class_name UIConstants

# ===== 配色方案 =====
const COLOR_BG_PRIMARY := Color("#1a1a2e")
const COLOR_BG_PANEL := Color("#16213e")
const COLOR_BG_PANEL_ALPHA := Color(0.086, 0.129, 0.243, 0.9)
const COLOR_ACCENT_DANGER := Color("#e94560")
const COLOR_GOLD := Color("#ffd700")
const COLOR_POSITIVE := Color("#4ecca3")
const COLOR_TEXT_PRIMARY := Color("#e0e0e0")
const COLOR_TEXT_SECONDARY := Color("#a0a0a0")
const COLOR_BUTTON_NORMAL := Color("#2a2a4a")
const COLOR_BUTTON_HOVER := Color("#3a3a6a")
const COLOR_BUTTON_PRESSED := Color("#1a1a3a")
const COLOR_BUTTON_DISABLED := Color("#333333")

# 稀有度色
const COLOR_RARITY_COMMON := Color("#9e9e9e")
const COLOR_RARITY_RARE := Color("#4fc3f7")
const COLOR_RARITY_EPIC := Color("#ab47bc")

# 亲和色
const COLOR_AFFINITY_SHOOTER := Color("#3388ff")
const COLOR_AFFINITY_ENGINEER := Color("#33cc55")

# ===== 字号 =====
const FONT_SIZE_TITLE := 32
const FONT_SIZE_SUBTITLE := 24
const FONT_SIZE_BODY := 18
const FONT_SIZE_SMALL := 14

# ===== 间距 =====
const MARGIN_SCREEN := 12
const MARGIN_PANEL := 16
const GAP_ITEMS := 12
const GAP_SECTIONS := 20

# ===== 圆角 =====
const CORNER_RADIUS_BUTTON := 8
const CORNER_RADIUS_PANEL := 12

# ===== 辅助方法 =====

static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		Enums.ItemRarity.RARE:
			return COLOR_RARITY_RARE
		Enums.ItemRarity.EPIC:
			return COLOR_RARITY_EPIC
		_:
			return COLOR_RARITY_COMMON

static func create_panel_stylebox(bg_color := COLOR_BG_PANEL_ALPHA, corner := CORNER_RADIUS_PANEL, border_color := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	if border_width > 0:
		style.border_color = border_color
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
	style.content_margin_left = MARGIN_PANEL
	style.content_margin_right = MARGIN_PANEL
	style.content_margin_top = MARGIN_PANEL
	style.content_margin_bottom = MARGIN_PANEL
	return style

static func create_button_stylebox(color: Color, corner := CORNER_RADIUS_BUTTON) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
