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
	const SHOOTER = "shooter"
	const WALL = "wall"
	const SLOW = "slow"

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

# 物品标签
class ItemTag:
	const SHOOTER  = "shooter"   # 射手
	const ENGINEER = "engineer"  # 工程
	const UNIVERSAL = "universal" # 通用

# 物品稀有度
class ItemRarity:
	const COMMON = "common"
	const RARE   = "rare"
	const EPIC   = "epic"

# 物品效果类型
class ItemEffect:
	const STAT_BOOST    = "stat_boost"     # 修改 player_stats
	const TOWER_STAT    = "tower_stat"     # 修改塔属性倍率（存 player_stats）
	const CONSUMABLE    = "consumable"     # 一次性效果
	const PIERCE        = "pierce"         # 穿甲弹：子弹穿透
	const MULTISHOT     = "multishot"      # 弹幕：多发
	const KILL_STACK    = "kill_stack"     # 蓄力：击杀叠层
	const LIFESTEAL     = "lifesteal"      # 吸血
	const TOWER_LINK    = "tower_link"     # 联动系统
	const WAVE_GOLD     = "wave_gold"      # 金矿：波次结束给金币
	const WAVE_HEAL_TOWERS = "wave_heal_towers"  # 战场维修
	const TOWER_REGEN   = "tower_regen"    # 纳米修复
	const SYMBIOSIS     = "symbiosis"      # 共生
	const WAR_MACHINE   = "war_machine"    # 战争机器
	const BULLET_SPEED     = "bullet_speed"
	const WEAPON_RANGE     = "weapon_range"
	const CRIT             = "crit"
	const SPLIT            = "split"
	const WAVE_SHIELD      = "wave_shield"
	const WAVE_HEAL_PLAYER = "wave_heal_player"
	const DAMAGE_REDUCTION = "damage_reduction"
	const DODGE            = "dodge"
	const MAGNET           = "magnet"
	const SLOW_AURA        = "slow_aura"
	const AUTO_DASH        = "auto_dash"
	const DESTINY       = "destiny"        # 天命
