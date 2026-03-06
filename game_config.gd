extends Node

# 配置驱动优化 - 游戏配置中心
# 所有游戏数值统一在此管理

# 开发模式开关
const DEBUG_MODE = true

# 全局尺寸标准
const BASE_VIEWPORT_WIDTH = 640
const BASE_VIEWPORT_HEIGHT = 360
const PPU = 30
const GRID_SIZE = 30

const MAP_COLS = 40
const MAP_ROWS = 30
const MAP_PIXEL_WIDTH = MAP_COLS * GRID_SIZE   # 1200
const MAP_PIXEL_HEIGHT = MAP_ROWS * GRID_SIZE  # 900
const MAP_HALF_WIDTH = MAP_PIXEL_WIDTH / 2.0     # 600
const MAP_HALF_HEIGHT = MAP_PIXEL_HEIGHT / 2.0   # 450

# 实体尺寸标准（像素）
const ENTITY_SIZE_STANDARD = GRID_SIZE      # 30
const ENTITY_SIZE_TANK = int(GRID_SIZE * 1.5)  # 45
const BULLET_SIZE = int(GRID_SIZE * 0.2)    # 6
const COIN_RADIUS = int(GRID_SIZE * 0.2)    # 6

# UI 尺寸标准（640x360 逻辑分辨率）
const UI_BUTTON_SIZE = Vector2(160, 36)
const UI_BUTTON_SMALL_SIZE = Vector2(120, 32)
const UI_MAP_CARD_SIZE = Vector2(240, 140)
const UI_RESULT_PANEL_SIZE = Vector2(320, 220)
const UI_SHOP_PANEL_SIZE = Vector2(560, 300)
const UI_CARD_GAP = 20

# 武器配置
const WEAPONS = {
	"rifle": {
		"name": "步枪",
		"projectile_type": "bullet",
		"fire_rate": 0.1,
		"damage": 10.0,
		"bullet_count": 1,
		"bullet_speed": 600,
		"range": 300.0
	},
	"boomerang": {
		"name": "回旋镖",
		"projectile_type": "boomerang",
		"fire_rate": 0.8,
		"damage": 15.0,
		"speed": 350.0,
		"outbound_distance": 200.0,
		"return_speed_mult": 1.3,
		"range": 200.0
	},
	"laser": {
		"name": "激光枪",
		"projectile_type": "laser",
		"fire_rate": 0.15,
		"damage": 8.0,
		"beam_range": 400.0,
		"beam_width": 2.0,
		"beam_duration": 0.08,
		"range": 400.0
	}
}

# 敌人配置
const ENEMIES = {
	"normal": {
		"name": "普通敌人",
		"hp": 50.0,
		"speed": 100.0,
		"damage": 10.0,
		"coin_drop_min": 1,
		"coin_drop_max": 3
	},
	"fast": {
		"name": "快速敌人",
		"hp": 35.0,
		"speed": 180.0,
		"damage": 8.0,
		"coin_drop_min": 2,
		"coin_drop_max": 4
	},
	"tank": {
		"name": "坦克敌人",
		"hp": 200.0,
		"speed": 50.0,
		"damage": 25.0,
		"coin_drop_min": 5,
		"coin_drop_max": 10
	}
}

# 塔配置
const TOWERS = {
	"shooter": {
		"name": "射手塔",
		"hp": 80.0,
		"damage": 15.0,
		"fire_rate": 1.0,
		"range": 300.0,
		"shop_price_min": 35,
		"shop_price_max": 45
	},
	"wall": {
		"name": "墙塔",
		"hp": 300.0,
		"damage": 0.0,
		"fire_rate": 0.0,
		"range": 0.0,
		"shop_price_min": 35,
		"shop_price_max": 45
	},
	"slow": {
		"name": "减速塔",
		"hp": 70.0,
		"damage": 0.0,
		"fire_rate": 0.0,
		"range": 200.0,
		"slow_percent": 0.3,
		"shop_price_min": 35,
		"shop_price_max": 45
	}
}

# 波次配置
const WAVES = {
	"total_waves": 10,
	"wave_configs": [
		{"duration": 45, "spawn_interval": 1.5, "enemy_types": ["normal"]},
		{"duration": 45, "spawn_interval": 1.5, "enemy_types": ["normal"]},
		{"duration": 50, "spawn_interval": 1.0, "enemy_types": ["normal", "fast"]},
		{"duration": 50, "spawn_interval": 1.0, "enemy_types": ["normal", "fast"]},
		{"duration": 55, "spawn_interval": 1.0, "enemy_types": ["normal", "fast"]},
		{"duration": 55, "spawn_interval": 0.8, "enemy_types": ["normal", "fast", "tank"]},
		{"duration": 60, "spawn_interval": 0.8, "enemy_types": ["normal", "fast", "tank"]},
		{"duration": 60, "spawn_interval": 0.8, "enemy_types": ["normal", "fast", "tank"]},
		{"duration": 60, "spawn_interval": 0.5, "enemy_types": ["normal", "fast", "tank"]},
		{"duration": 60, "spawn_interval": 0.5, "enemy_types": ["normal", "fast", "tank"]}
	]
}

# 玩家配置
const PLAYER = {
	"initial_hp": 100.0,
	"initial_speed": 200.0,
	"initial_coins": 100,
	"hp_regen_interval": 5.0,
	"default_enemy_touch_damage": 10.0  # 敌人没有 touch_damage 属性时的默认伤害
}

# 角色配置
const CHARACTERS = {
	"warrior": {
		"name": "战士",
		"description": "高生命值，低速度",
		"max_hp": 150.0,
		"speed": 180.0,
		"damage_mult": 1.2,
		"attack_speed_mult": 1.0,
		"move_speed_mult": 0.9,
		"hp_regen": 0.0
	},
	"ranger": {
		"name": "游侠",
		"description": "低生命值，高速度",
		"max_hp": 80.0,
		"speed": 250.0,
		"damage_mult": 0.9,
		"attack_speed_mult": 1.1,
		"move_speed_mult": 1.25,
		"hp_regen": 0.0
	},
	"tank": {
		"name": "坦克",
		"description": "超高生命值，极低速度",
		"max_hp": 200.0,
		"speed": 150.0,
		"damage_mult": 0.8,
		"attack_speed_mult": 0.9,
		"move_speed_mult": 0.75,
		"hp_regen": 1.0
	}
}

# 商店配置
const SHOP = {
	"refresh_cost": 10,
	"item_count": 4,
	"passive_price_min": 20,
	"passive_price_max": 40,
	"heal_price": 12,
	"heal_amount": 50
}

# 地图配置
const MAPS = {
	"forest": {
		"name": "森林",
		"description": "茂密的森林环境",
		"preview_image": "res://assets/maps/forest_preview.png",
		"background": "res://assets/maps/forest_bg.png",
		"fallback_color": "#2d5016"
	},
	"desert": {
		"name": "沙漠",
		"description": "炎热的沙漠地带",
		"preview_image": "res://assets/maps/desert_preview.png",
		"background": "res://assets/maps/desert_bg.png",
		"fallback_color": "#d4a574"
	}
}

# 特效配置
const EFFECTS = {
	"camera_shake": {
		"player_hit": {"intensity": 3.0, "duration": 0.1},
		"enemy_kill": {"intensity": 2.0, "duration": 0.08},
		"wave_start": {"intensity": 5.0, "duration": 0.2}
	},
	"knockback": {
		"distance": 15.0,
		"duration": 0.1
	},
	"hit_flash": {
		"duration": 0.05,
		"color": Color.WHITE
	},
	"invincible_blink": {
		"interval": 0.08,
		"alpha_low": 0.3,
		"alpha_high": 1.0
	},
	"damage_number": {
		"float_distance": 30.0,
		"random_offset_x": 10.0,
		"duration": 0.6,
		"big_damage_threshold": 30.0,
		"big_damage_scale": 1.3,
		"normal_color": Color.WHITE,
		"big_color": Color.YELLOW
	},
	"death_particles": {
		"count": 10,
		"spread": 20.0,
		"lifetime": 0.3,
		"gravity": 200.0
	},
	"hit_sparks": {
		"count": 5,
		"lifetime": 0.15,
		"spread_speed": 100.0
	},
	"coin_pickup": {
		"shrink_duration": 0.15
	},
	"bullet_trail": {
		"length": 15.0,
		"width": 2.0,
		"color": Color(1, 1, 0, 0.6)
	},
	"boomerang": {
		"rotation_speed": 720.0,
		"trail_points": 6,
		"trail_width": 3.0,
		"trail_color": Color(0.2, 0.8, 1.0, 0.6),
		"return_rotation_mult": 1.5
	},
	"laser": {
		"beam_width": 4.0,
		"core_color": Color(1, 1, 1, 0.9),
		"edge_color": Color(1, 0.2, 0.2, 0.7),
		"flash_alpha": 0.03,
		"flash_duration": 0.05
	}
}
