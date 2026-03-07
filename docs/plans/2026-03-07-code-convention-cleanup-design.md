# 代码规范整改设计

## 目标

消除代码库中的魔法字符串、补全类型标注、修正命名规范，提升可维护性和 IDE 支持。

## 范围

### 做

1. **魔法字符串 → 枚举/常量** — 创建 `Enums` 类（class_name 全局可用），替换 ~150 处魔法字符串
2. **类型标注补全** — ~43 个函数返回类型 + ~12 个参数类型
3. **私有前缀修正** — 6 个仅内部调用的方法加 `_` 前缀
4. **移除未使用 export** — `enemy.gd` 的 `touch_damage`

### 不做（后续）

- Dictionary → Resource（shop_manager passive_upgrades、placement 塔数据）
- 代码重复提取（武器 fire()、投射物 trail/cleanup）
- 硬编码魔法数字 → Resource

## 方案：集中式 Enums 类

创建 `scripts/core/enums.gd`，使用 `class_name Enums`，不需要 Autoload。

### 枚举定义

```gdscript
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
    const WEAPON_SELECT = "weapon_select"
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
class Weapon:
    const RIFLE = "rifle"
    const BOOMERANG = "boomerang"
    const LASER = "laser"

# 敌人类型
class Enemy:
    const NORMAL = "normal"
    const FAST = "fast"
    const TANK = "tank"

# 塔类型
class Tower:
    const SHOOTER = "shooter"
    const WALL = "wall"
    const SLOW = "slow"

# 投射物类型
class Projectile:
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
```

### 使用方式

```gdscript
# 之前
add_to_group("enemies")
SceneManager.go_to("shop")
GameData.player_stats["damage_mult"]

# 之后
add_to_group(Enums.Group.ENEMIES)
SceneManager.go_to(Enums.Scene.SHOP)
GameData.player_stats[Enums.Stat.DAMAGE_MULT]
```

### 设计决策

- **用内部 class + const 而非 enum** — GDScript enum 只支持 int 值，我们需要 String 值保持与现有数据兼容
- **BoomerangState 用 enum** — 状态机不需要字符串值，int enum 更合适
- **class_name 而非 Autoload** — 纯常量不需要节点实例，class_name 更轻量

## 类型标注规则

- 所有函数必须有返回类型（`-> void`、`-> bool` 等）
- 所有参数必须有类型（`delta: float`、`body: Node2D`、`event: InputEvent`）
- 生命周期函数同样要求

## 私有前缀修正

| 文件 | 原名 | 新名 |
|------|------|------|
| enemy.gd | chase_player() | _chase_player() |
| enemy.gd | attack_tower() | _attack_tower() |
| enemy.gd | drop_coins() | _drop_coins() |
| tower_shooter.gd | shoot_nearest_enemy() | _shoot_nearest_enemy() |
| placement.gd | use_fallback_background() | _use_fallback_background() |
