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
		"shop_price_min": 35,
		"shop_price_max": 45
	},
	"slow": {
		"name": "减速塔",
		"hp": 70.0,
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
	"hp_regen_interval": 5.0
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
