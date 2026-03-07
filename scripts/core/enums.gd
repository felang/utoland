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
	const WARRIOR = "warrior"
	const RANGER = "ranger"
	const TANK = "tank"

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
	const WALK_DOWN = "walk_down"
	const WALK_UP = "walk_up"
	const WALK_LEFT = "walk_left"
	const WALK_RIGHT = "walk_right"
	const DEFAULT = "default"
