extends Node

# 配置驱动优化 - 游戏配置中心
# Resource 资源注册表

# ===== 常量（保留不变） =====

# 开发模式开关
const DEBUG_MODE = true

# 全局尺寸标准
const BASE_VIEWPORT_WIDTH = 640
const BASE_VIEWPORT_HEIGHT = 360
const PPU = 32
const GRID_SIZE = 32

# 地图尺寸（动态计算，_ready() 中赋值）
var MAP_PIXEL_WIDTH: float = 0.0
var MAP_PIXEL_HEIGHT: float = 0.0
var MAP_HALF_WIDTH: float = 0.0
var MAP_HALF_HEIGHT: float = 0.0

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

# ===== 精灵图配置（玩家精灵已迁移到 CharacterData.sprite_frames_path） =====
const SPRITES = {
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
		},
		"boss_brute": {
			"spritesheet": "res://assets/sprites/enemies/trex.png",
			"frame_size": Vector2(16, 16),
			"walk_frames": 4,
			"walk_directions": 4,
			"fps": 5.0
		},
		"boss_summoner": {
			"spritesheet": "res://assets/sprites/enemies/bluebat.png",
			"frame_size": Vector2(16, 16),
			"walk_frames": 4,
			"walk_directions": 4,
			"fps": 5.0
		},
		"boss_guardian": {
			"spritesheet": "res://assets/sprites/enemies/trex.png",
			"frame_size": Vector2(16, 16),
			"walk_frames": 4,
			"walk_directions": 4,
			"fps": 4.0
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
var waves: Array = []  # 当前地图的波次（向后兼容）
var waves_by_map: Dictionary = {}  # {map_id: Array[WaveData]}
var characters: Dictionary = {}
var maps: Dictionary = {}
var effects: EffectConfigData = null
var shop: ShopConfigData = null
var spawn: SpawnConfigData = null
var items: Dictionary = {}  # ShopItemData 注册表


func _ready() -> void:
	_load_resources_from_dir("res://resources/weapons/", weapons)
	_load_resources_from_dir("res://resources/enemies/", enemies)
	_load_resources_from_dir("res://resources/towers/", towers)
	_load_waves_by_map("res://resources/waves/")
	_load_resources_from_dir("res://resources/characters/", characters)
	_load_resources_from_dir("res://resources/maps/", maps)
	effects = load("res://resources/effects/default_effects.tres")
	shop = load("res://resources/shop/default_shop.tres")
	spawn = load("res://resources/spawn/default_spawn.tres")
	_load_resources_from_dir("res://resources/items/", items)
	# 动态计算地图尺寸
	_compute_map_dimensions()


func _compute_map_dimensions() -> void:
	var fx: EffectConfigData = effects
	if fx:
		MAP_PIXEL_WIDTH = BASE_VIEWPORT_WIDTH / fx.camera_zoom * fx.map_size_ratio
		MAP_PIXEL_HEIGHT = BASE_VIEWPORT_HEIGHT / fx.camera_zoom * fx.map_size_ratio
	else:
		# fallback：与旧尺寸接近
		MAP_PIXEL_WIDTH = 1280.0
		MAP_PIXEL_HEIGHT = 960.0
	MAP_HALF_WIDTH = MAP_PIXEL_WIDTH / 2.0
	MAP_HALF_HEIGHT = MAP_PIXEL_HEIGHT / 2.0


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


func _load_waves_by_map(base_path: String) -> void:
	var dir := DirAccess.open(base_path)
	if not dir:
		push_error("无法打开波次目录: " + base_path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			var map_waves: Array = []
			_load_wave_files(base_path + entry + "/", map_waves)
			if map_waves.size() > 0:
				waves_by_map[entry] = map_waves
		entry = dir.get_next()

	# 向后兼容：如果没有子目录结构，直接从根目录加载
	if waves_by_map.is_empty():
		_load_wave_files(base_path, waves)
	else:
		# 默认加载 forest
		if waves_by_map.has("forest"):
			waves = waves_by_map["forest"]

func _load_wave_files(path: String, target: Array) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: Resource = load(path + file_name)
			if res is WaveData:
				target.append(res)
		file_name = dir.get_next()
	target.sort_custom(func(a: WaveData, b: WaveData) -> bool: return a.wave_number < b.wave_number)

func get_waves_for_map(map_id: String) -> Array:
	if waves_by_map.has(map_id):
		return waves_by_map[map_id]
	return waves
