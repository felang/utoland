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

# 亲和色
const COLOR_AFFINITY_SHOOTER := Color("#3388ff")
const COLOR_AFFINITY_ENGINEER := Color("#33cc55")

# HUD 像素风颜色
const COLOR_HUD_BG := COLOR_BG_PRIMARY           # 进度条/面板背景（与主背景同色）
const COLOR_HUD_BORDER := Color("#444444")       # 进度条/面板边框
const COLOR_HUD_XP := Color("#6c9bff")           # 经验条蓝色
const COLOR_HUD_XP_BG := Color("#3a3a6e")        # 经验图标背景
const COLOR_HUD_COIN_BG := Color("#8a6c00")      # 金币图标背景
const COLOR_HUD_HP_YELLOW := Color("#e6c84b")    # HP 中等血量黄色

# HUD 尺寸
const HUD_ICON_FONT_SIZE := 12                   # 图标内符号字号
const HUD_ICON_BORDER := 2                       # 图标边框宽度
const HUD_ICON_CORNER := 3                       # 图标圆角
const HUD_BAR_WIDTH := 120                       # 进度条宽度
const HUD_HP_BAR_HEIGHT := 15                    # HP 条高度
const HUD_XP_BAR_HEIGHT := 12                    # XP 条高度
const HUD_BAR_CORNER := 2                        # 进度条圆角
const HUD_WAVE_PADDING_H := 12                   # 波次面板水平内边距
const HUD_WAVE_PADDING_V := 3                    # 波次面板垂直内边距

# ===== 字号 =====
const FONT_SIZE_TITLE := 48
const FONT_SIZE_SUBTITLE := 36
const FONT_SIZE_BODY := 27
const FONT_SIZE_SMALL := 21
const FONT_SIZE_TINY := 18

# ===== 间距 =====
const MARGIN_SCREEN := 18
const MARGIN_PANEL := 24
const GAP_ITEMS := 18
const GAP_SECTIONS := 30

# ===== 圆角 =====
const CORNER_RADIUS_BUTTON := 8
const CORNER_RADIUS_PANEL := 12

# ===== 按钮内边距 =====
const BUTTON_PADDING_H := 12
const BUTTON_PADDING_V := 8

# ===== 辅助方法 =====

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
	style.content_margin_left = BUTTON_PADDING_H
	style.content_margin_right = BUTTON_PADDING_H
	style.content_margin_top = BUTTON_PADDING_V
	style.content_margin_bottom = BUTTON_PADDING_V
	return style
