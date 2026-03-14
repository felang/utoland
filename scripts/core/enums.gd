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
	const SHOP = "shop"
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
	const SHOTGUN = "shotgun"
	const MINIGUN = "minigun"
	const ROCKET = "rocket"
	const FLAMETHROWER = "flamethrower"
	const LIGHTNING = "lightning"
	const ICE_GUN = "ice_gun"
	const BLADE = "blade"

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
	const CACTUS = "cactus"
	const ROSE = "rose"
	const MUSHROOM = "mushroom"
	const VINE = "vine"
	const DANDELION = "dandelion"
	const PITCHER = "pitcher"
	const THORN = "thorn"
	const OAK = "oak"
	const SUNFLOWER = "sunflower"
	const MINT = "mint"
	const HEAL_FLOWER = "heal_flower"
	const BAMBOO = "bamboo"

# 投射物类型
class ProjectileId:
	const BULLET = "bullet"
	const BOOMERANG = "boomerang"
	const LASER = "laser"
	const ROCKET = "rocket"
	const FLAME = "flame"
	const CHAIN = "chain"
	const MELEE = "melee"

# 地图 ID
class Map:
	const FOREST = "forest"
	const DESERT = "desert"

# 玩家属性 key
class Stat:
	const MAX_HP = "max_hp"
	const HP_MULT = "hp_mult"
	const DAMAGE_MULT = "damage_mult"
	const ATTACK_SPEED_MULT = "attack_speed_mult"
	const TOWER_MULT = "tower_mult"

# 协同标签
class Tag:
	const ASSAULT = "assault"
	const CONTROL = "control"
	const BLAST = "blast"
	const FORTIFY = "fortify"
	const BOOST = "boost"
	const ALL = [ASSAULT, CONTROL, BLAST, FORTIFY, BOOST]

# 武器稀有度
class WeaponRarity:
	const COMMON = 0
	const RARE = 1
	const EPIC = 2


# 塔稀有度
class TowerRarity:
	const COMMON = 0
	const RARE = 1
	const EPIC = 2

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
