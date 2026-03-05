extends Node

# 配置驱动优化 - 游戏配置中心
# 所有游戏数值统一在此管理

# 开发模式开关
const DEBUG_MODE = true

# 武器配置
const WEAPONS = {
	"rifle": {
		"name": "步枪",
		"fire_rate": 0.1,
		"damage": 10.0,
		"bullet_count": 1,
		"bullet_speed": 600
	},
	"shotgun": {
		"name": "霰弹枪",
		"fire_rate": 0.6,
		"damage": 6.0,
		"bullet_count": 5,
		"spread_angles": [-7.5, -3.75, 0, 3.75, 7.5],
		"bullet_speed": 500
	},
	"sniper": {
		"name": "狙击枪",
		"fire_rate": 1.0,
		"damage": 30.0,
		"bullet_count": 1,
		"bullet_speed": 800
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
