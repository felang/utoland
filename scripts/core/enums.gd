class_name Enums

# 组名
class Group:
	const PLAYER = "player"
	const ENEMIES = "enemies"
	const TOWERS = "towers"
	const COINS = "coins"
	const DAMAGE_NUMBERS = "damage_numbers"
	const WAVE_MANAGER = "wave_manager"

# 场景名
class Scene:
	const START_MENU = "start_menu"
	const CHARACTER_SELECTION = "character_selection"
	const MAP_SELECT = "map_select"
	const PLACEMENT = "placement"
	const MAIN = "main"
	const RESULT = "result"

# 角色 ID
class Character:
	const DORA = "dora"
	const GORG = "gorg"
	const KAZE = "kaze"
	const MERLIN = "merlin"
	const NEMO = "nemo"

# 武器 ID
class WeaponId:
	const RIFLE = "rifle"
	const BOOMERANG = "boomerang"
	const LASER = "laser"

# 敌人类型
class Enemy:
	const NORMAL = "normal"
	const FAST = "fast"
	const TANK = "tank"
	const BOSS_BRUTE = "boss_brute"
	const BOSS_SUMMONER = "boss_summoner"
	const BOSS_GUARDIAN = "boss_guardian"

# 塔类型
class TowerId:
	const PEA_SHOOTER = "pea_shooter"
	const STUMP = "stump"
	const ICE_FLOWER = "ice_flower"

# 投射物类型
class ProjectileId:
	const BULLET = "bullet"
	const BOOMERANG = "boomerang"
	const LASER = "laser"

# 地图 ID
class Map:
	const FOREST = "forest"
	const DESERT = "desert"

# 玩家属性 key
class Stat:
	const MAX_HP = "max_hp"
	const HP_MULT = "hp_mult"
	const HP_REGEN = "hp_regen"
	const DAMAGE_MULT = "damage_mult"
	const ATTACK_SPEED_MULT = "attack_speed_mult"
	const MOVE_SPEED_MULT = "move_speed_mult"
	const TOWER_MULT = "tower_mult"

# 回旋镖状态
enum BoomerangState { OUTBOUND, RETURNING }

# 动画名
class Anim:
	const IDLE = "idle"
	const IDLE_DOWN = "idle_down"
	const IDLE_UP = "idle_up"
	const IDLE_LEFT = "idle_left"
	const IDLE_RIGHT = "idle_right"
	const WALK_DOWN = "walk_down"
	const WALK_UP = "walk_up"
	const WALK_LEFT = "walk_left"
	const WALK_RIGHT = "walk_right"
	const ATTACK = "attack"
	const DEAD = "dead"
	const DEFAULT = "default"
