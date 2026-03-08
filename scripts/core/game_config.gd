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
var items: Dictionary = {}  # ShopItemData 注册表


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
	_load_resources_from_dir("res://resources/items/", items)


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
