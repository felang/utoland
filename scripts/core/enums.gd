class_name Enums

# 组名
class Group:
	const PLAYER = "player"
	const ENEMIES = "enemies"
	const TOWERS = "towers"
	const COINS = "coins"
	const DAMAGE_NUMBERS = "damage_numbers"
	const WAVE_MANAGER = "wave_manager"
	const EXP_ORBS = "exp_orbs"

# 场景名
class Scene:
	const START_MENU = "start_menu"
	const CHARACTER_SELECTION = "character_selection"
	const MAP_SELECT = "map_select"
	const MAIN = "main"
	const RESULT = "result"

# 角色 ID
class Character:
	const DORA = "dora"
	const GORG = "gorg"
	const KAZE = "kaze"
	const MERLIN = "merlin"
	const NEMO = "nemo"

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
	const ICE_FLOWER = "ice_flower"
	const SUNFLOWER = "sunflower"

# 投射物类型
class ProjectileId:
	const BULLET = "bullet"
	const SHURIKEN = "shuriken"

# 地图 ID
class Map:
	const FOREST = "forest"
	const DESERT = "desert"

# 玩家属性 key
class Stat:
	const MAX_HP = "max_hp"
	const TOWER_MULT = "tower_mult"
	# Perk bonus(战斗中 3 选 1 累加)
	const HP_BONUS_PERCENT = "hp_bonus_percent"
	const MOVE_SPEED_BONUS_PERCENT = "move_speed_bonus_percent"
	const DAMAGE_BONUS_PERCENT = "damage_bonus_percent"
	const ATTACK_SPEED_BONUS_PERCENT = "attack_speed_bonus_percent"
	const PICKUP_RADIUS_BONUS_PERCENT = "pickup_radius_bonus_percent"
	const COIN_DROP_BONUS_PERCENT = "coin_drop_bonus_percent"
	const EXP_GAIN_BONUS_PERCENT = "exp_gain_bonus_percent"
	const POPULATION_BONUS = "population_bonus"

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
