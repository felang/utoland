extends Node

# 配置驱动优化 - 游戏配置中心
# Resource 资源注册表 + 向后兼容字典

# ===== 常量（保留不变） =====

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

# ===== 玩家配置（保持 const 避免 Autoload 顺序问题） =====
const PLAYER = {
	"initial_hp": 100.0,
	"initial_speed": 200.0,
	"initial_coins": 100,
	"hp_regen_interval": 5.0,
	"default_enemy_touch_damage": 10.0  # 敌人没有 touch_damage 属性时的默认伤害
}

# ===== 精灵图配置（暂保留 const，后续资源化） =====
const SPRITES = {
	"player": {
		"warrior": {
			"idle": "res://assets/sprites/player/knight_idle.png",
			"walk": "res://assets/sprites/player/knight_walk.png",
			"frame_size": Vector2(16, 16),
			"idle_frames": 4,
			"walk_frames": 4,
			"walk_directions": 4,
			"fps": 8.0
		},
		"ranger": {
			"idle": "res://assets/sprites/player/hunter_idle.png",
			"walk": "res://assets/sprites/player/hunter_walk.png",
			"frame_size": Vector2(16, 16),
			"idle_frames": 4,
			"walk_frames": 4,
			"walk_directions": 4,
			"fps": 8.0
		},
		"tank": {
			"idle": "res://assets/sprites/player/monk_idle.png",
			"walk": "res://assets/sprites/player/monk_walk.png",
			"frame_size": Vector2(16, 16),
			"idle_frames": 4,
			"walk_frames": 4,
			"walk_directions": 4,
			"fps": 8.0
		}
	},
	"enemies": {
		"normal": {
			"spritesheet": "res://assets/sprites/enemies/slime.png",
			"frame_size": Vector2(16, 16),
			"walk_frames": 4,
			"walk_directions": 4,
			"fps": 8.0
		},
		"fast": {
			"spritesheet": "res://assets/sprites/enemies/bluebat.png",
			"frame_size": Vector2(16, 16),
			"walk_frames": 4,
			"walk_directions": 4,
			"fps": 10.0
		},
		"tank": {
			"spritesheet": "res://assets/sprites/enemies/trex.png",
			"frame_size": Vector2(16, 16),
			"walk_frames": 4,
			"walk_directions": 4,
			"fps": 6.0
		}
	},
	"towers": {
		"tileset": "res://assets/sprites/towers/tileset_towers.png",
		"shooter": {"region": Rect2(32, 0, 16, 16)},
		"wall": {"region": Rect2(64, 32, 16, 16)},
		"slow": {"region": Rect2(320, 0, 16, 16)}
	},
	"projectiles": {
		"bullet": "res://assets/sprites/projectiles/kunai.png",
		"boomerang": "res://assets/sprites/projectiles/shuriken.png"
	},
	"items": {
		"coin": "res://assets/sprites/items/gold_coin.png"
	}
}

# ===== 资源注册表 =====
var weapons: Dictionary = {}
var enemies: Dictionary = {}
var towers: Dictionary = {}
var waves: Array = []  # Array of WaveData，按 wave_number 排序
var characters: Dictionary = {}
var maps: Dictionary = {}
var effects: EffectConfigData = null
var shop: ShopConfigData = null
var spawn: SpawnConfigData = null

# ===== 向后兼容字典（运行时从 Resource 构建） =====
var WEAPONS: Dictionary = {}
var ENEMIES: Dictionary = {}
var TOWERS: Dictionary = {}
var WAVES: Dictionary = {}
var CHARACTERS: Dictionary = {}
var SHOP: Dictionary = {}
var MAPS: Dictionary = {}
var EFFECTS: Dictionary = {}


func _ready() -> void:
	_load_resources_from_dir("res://resources/weapons/", weapons)
	_load_resources_from_dir("res://resources/enemies/", enemies)
	_load_resources_from_dir("res://resources/towers/", towers)
	_load_waves("res://resources/waves/")
	_load_resources_from_dir("res://resources/characters/", characters)
	_load_resources_from_dir("res://resources/maps/", maps)
	effects = load("res://resources/effects/default_effects.tres")
	shop = load("res://resources/shop/default_shop.tres")
	spawn = load("res://resources/spawn/default_spawn.tres")
	_build_compat_dicts()


func _load_resources_from_dir(path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_error("无法打开资源目录: " + path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: Resource = load(path + file_name)
			if res and "id" in res:
				target[res.id] = res
		file_name = dir.get_next()


func _load_waves(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_error("无法打开波次目录: " + path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: Resource = load(path + file_name)
			if res is WaveData:
				waves.append(res)
		file_name = dir.get_next()
	waves.sort_custom(func(a: WaveData, b: WaveData) -> bool: return a.wave_number < b.wave_number)


func _build_compat_dicts() -> void:
	# 从 Resource 构建向后兼容字典

	# WEAPONS
	for id in weapons:
		var w: WeaponData = weapons[id]
		var d: Dictionary = {
			"name": w.display_name,
			"projectile_type": w.projectile_type,
			"fire_rate": w.fire_rate,
			"damage": w.damage,
			"range": w.weapon_range,
		}
		if w.projectile_type == "bullet":
			d["bullet_count"] = w.bullet_count
			d["bullet_speed"] = w.bullet_speed
		elif w.projectile_type == "boomerang":
			d["speed"] = w.boomerang_speed
			d["outbound_distance"] = w.outbound_distance
			d["return_speed_mult"] = w.return_speed_mult
		elif w.projectile_type == "laser":
			d["beam_range"] = w.beam_range
			d["beam_width"] = w.beam_width
			d["beam_duration"] = w.beam_duration
		WEAPONS[id] = d

	# ENEMIES
	for id in enemies:
		var e: EnemyData = enemies[id]
		ENEMIES[id] = {
			"name": e.display_name, "hp": e.hp, "speed": e.speed,
			"damage": e.damage, "coin_drop_min": e.coin_drop_min, "coin_drop_max": e.coin_drop_max
		}

	# TOWERS
	for id in towers:
		var t: TowerData = towers[id]
		var d: Dictionary = {
			"name": t.display_name, "hp": t.hp, "damage": t.damage,
			"fire_rate": t.fire_rate, "range": t.attack_range,
			"shop_price_min": t.shop_price_min, "shop_price_max": t.shop_price_max
		}
		if t.slow_percent > 0:
			d["slow_percent"] = t.slow_percent
		TOWERS[id] = d

	# WAVES
	var wave_configs: Array = []
	for w in waves:
		wave_configs.append({
			"duration": w.duration,
			"spawn_interval": w.spawn_interval,
			"enemy_types": Array(w.enemy_types)
		})
	WAVES = {"total_waves": waves.size(), "wave_configs": wave_configs}

	# CHARACTERS
	for id in characters:
		var c: CharacterData = characters[id]
		CHARACTERS[id] = {
			"name": c.display_name, "description": c.description,
			"max_hp": c.max_hp, "speed": c.speed,
			"damage_mult": c.damage_mult, "attack_speed_mult": c.attack_speed_mult,
			"move_speed_mult": c.move_speed_mult, "hp_regen": c.hp_regen
		}

	# MAPS
	for id in maps:
		var m: MapData = maps[id]
		MAPS[id] = {
			"name": m.display_name, "description": m.description,
			"preview_image": m.preview_image, "background": m.background,
			"fallback_color": m.fallback_color
		}

	# SHOP
	if shop:
		SHOP = {
			"refresh_cost": shop.refresh_cost, "item_count": shop.item_count,
			"passive_price_min": shop.passive_price_min, "passive_price_max": shop.passive_price_max,
			"heal_price": shop.heal_price, "heal_amount": shop.heal_amount
		}

	# EFFECTS
	if effects:
		EFFECTS = {
			"camera_shake": {
				"player_hit": {"intensity": effects.camera_shake_player_hit_intensity, "duration": effects.camera_shake_player_hit_duration},
				"enemy_kill": {"intensity": effects.camera_shake_enemy_kill_intensity, "duration": effects.camera_shake_enemy_kill_duration},
				"wave_start": {"intensity": effects.camera_shake_wave_start_intensity, "duration": effects.camera_shake_wave_start_duration}
			},
			"knockback": {"distance": effects.knockback_distance, "duration": effects.knockback_duration},
			"hit_flash": {"duration": effects.hit_flash_duration, "color": effects.hit_flash_color},
			"invincible_blink": {"interval": effects.invincible_blink_interval, "alpha_low": effects.invincible_blink_alpha_low, "alpha_high": effects.invincible_blink_alpha_high},
			"damage_number": {
				"float_distance": effects.damage_number_float_distance,
				"random_offset_x": effects.damage_number_random_offset_x,
				"duration": effects.damage_number_duration,
				"big_damage_threshold": effects.damage_number_big_threshold,
				"big_damage_scale": effects.damage_number_big_scale,
				"normal_color": effects.damage_number_normal_color,
				"big_color": effects.damage_number_big_color
			},
			"death_particles": {"count": effects.death_particle_count, "spread": effects.death_particle_spread, "lifetime": effects.death_particle_lifetime, "gravity": effects.death_particle_gravity},
			"hit_sparks": {"count": effects.hit_spark_count, "lifetime": effects.hit_spark_lifetime, "spread_speed": effects.hit_spark_spread_speed},
			"coin_pickup": {"shrink_duration": effects.coin_pickup_shrink_duration},
			"bullet_trail": {"length": effects.bullet_trail_length, "width": effects.bullet_trail_width, "color": effects.bullet_trail_color},
			"boomerang": {"rotation_speed": effects.boomerang_rotation_speed, "trail_points": effects.boomerang_trail_points, "trail_width": effects.boomerang_trail_width, "trail_color": effects.boomerang_trail_color, "return_rotation_mult": effects.boomerang_return_rotation_mult},
			"laser": {"beam_width": effects.laser_beam_width, "core_color": effects.laser_core_color, "edge_color": effects.laser_edge_color, "flash_alpha": effects.laser_flash_alpha, "flash_duration": effects.laser_flash_duration},
			"camera": {"zoom": effects.camera_zoom, "smoothing_speed": effects.camera_smoothing_speed, "look_ahead_distance": effects.camera_look_ahead_distance, "look_ahead_smoothing": effects.camera_look_ahead_smoothing}
		}
