# 代码规范整改 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 消除 ~150 处魔法字符串、补全类型标注、修正私有前缀、移除未使用 export，提升代码可维护性。

**Architecture:** 创建 `scripts/core/enums.gd` (class_name Enums) 集中管理所有字符串常量，然后逐模块替换引用并补全类型标注。

**Tech Stack:** GDScript (Godot 4.6), GUT 测试框架

---

### Task 1: 创建 Enums 类

**Files:**
- Create: `scripts/core/enums.gd`

**Step 1: 创建 enums.gd**

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

**Step 2: 提交**

```bash
git add scripts/core/enums.gd
git commit -m "refactor: 创建 Enums 常量类，集中管理魔法字符串"
```

---

### Task 2: 替换 core/ 模块魔法字符串

**Files:**
- Modify: `scripts/core/game_data.gd` — 玩家属性 key 替换为 Enums.Stat.*
- Modify: `scripts/core/scene_factory.gd` — 敌人/塔/投射物类型替换为 Enums.Enemy.*/Tower.*/Projectile.*
- Modify: `scripts/core/scene_manager.gd` — 场景名替换为 Enums.Scene.*
- Modify: `scripts/core/sprite_loader.gd` — 动画名替换为 Enums.Anim.*
- Modify: `scripts/core/game_config.gd` — SPRITES key 和塔类型替换为 Enums 常量

**Step 1: 替换**

逐文件替换所有魔法字符串。Read 每个文件，找到所有字符串字面量，替换为对应 Enums 常量。

替换规则：
- `"max_hp"` → `Enums.Stat.MAX_HP`（同理其他 Stat 常量）
- `"normal"` / `"fast"` / `"tank"`（敌人上下文）→ `Enums.Enemy.*`
- `"shooter"` / `"wall"` / `"slow"`（塔上下文）→ `Enums.Tower.*`
- `"bullet"` / `"boomerang"` / `"laser"`（投射物上下文）→ `Enums.Projectile.*`
- `"start_menu"` 等 → `Enums.Scene.*`
- `"idle"` / `"walk_down"` 等 → `Enums.Anim.*`
- `"rifle"` / `"boomerang"` / `"laser"`（武器上下文）→ `Enums.Weapon.*`
- `"warrior"` / `"ranger"` / `"tank"`（角色上下文）→ `Enums.Character.*`
- `"forest"` / `"desert"` → `Enums.Map.*`

注意：`game_config.gd` 中 SPRITES 字典的 key 和 Resource 加载路径中的字符串都需要替换。scene_manager.gd 中 SCENES 字典 key 替换为 Enums.Scene 常量。

**Step 2: 提交**

```bash
git add scripts/core/
git commit -m "refactor: core/ 模块魔法字符串替换为 Enums 常量"
```

---

### Task 3: 替换 entities/ 模块魔法字符串 + 类型标注 + 私有前缀

**Files:**
- Modify: `scripts/entities/player.gd` — 组名、SPRITES key、类型标注
- Modify: `scripts/entities/enemy.gd` — 组名、SPRITES key、类型标注、私有前缀、移除未使用 export
- Modify: `scripts/entities/coin.gd` — 组名、类型标注

**Step 1: enemy.gd 全面修改**

魔法字符串替换：
- `add_to_group("enemies")` → `add_to_group(Enums.Group.ENEMIES)`
- `SPRITES["enemies"]` 等 → 对应 Enums 常量
- `"tank"` 角色检查 → `Enums.Character.TANK`

私有前缀修正（同时更新所有调用处）：
- `chase_player()` → `_chase_player()`
- `attack_tower(_delta)` → `_attack_tower(_delta: float)`
- `drop_coins()` → `_drop_coins()`

移除未使用 export：
- 删除 `@export var touch_damage: float = 10.0`
- 删除 `@export var tower_attack_rate: float = 1.0`（如确认未使用）

类型标注补全（所有函数加 `-> void`，参数加类型）：
- `func _ready():` → `func _ready() -> void:`
- `func _physics_process(_delta):` → `func _physics_process(_delta: float) -> void:`
- 等等所有函数

**Step 2: player.gd 修改**

魔法字符串替换：
- `add_to_group("player")` → `add_to_group(Enums.Group.PLAYER)`
- `SPRITES["player"]` → 使用 Enums 常量
- `PLAYER["hp_regen_interval"]` 等保持（PLAYER 是 GameConfig 常量字典，非实体类型）

类型标注补全。

**Step 3: coin.gd 修改**

魔法字符串替换：
- `add_to_group("coins")` → `add_to_group(Enums.Group.COINS)`
- `get_first_node_in_group("player")` → `get_first_node_in_group(Enums.Group.PLAYER)`

类型标注补全：
- `func _ready():` → `func _ready() -> void:`
- `func _process(delta):` → `func _process(delta: float) -> void:`
- `func _on_body_entered(body):` → `func _on_body_entered(body: Node2D) -> void:`

**Step 4: 提交**

```bash
git add scripts/entities/player.gd scripts/entities/enemy.gd scripts/entities/coin.gd
git commit -m "refactor: entities/ 主实体魔法字符串替换 + 类型标注 + 私有前缀"
```

---

### Task 4: 替换 weapons/ 和 projectiles/ 模块

**Files:**
- Modify: `scripts/entities/weapons/weapon.gd` — 属性 key
- Modify: `scripts/entities/weapons/weapon_manager.gd` — 组名、投射物类型
- Modify: `scripts/entities/weapons/bullet_weapon.gd` — 属性 key
- Modify: `scripts/entities/weapons/boomerang_weapon.gd` — 属性 key
- Modify: `scripts/entities/weapons/laser_weapon.gd` — 属性 key
- Modify: `scripts/entities/projectiles/boomerang_projectile.gd` — 状态字符串 → BoomerangState enum

**Step 1: weapon_manager.gd**

替换：
- `get_first_node_in_group("player")` → `get_first_node_in_group(Enums.Group.PLAYER)`
- `get_nodes_in_group("enemies")` → `get_nodes_in_group(Enums.Group.ENEMIES)`
- match 语句中 `"bullet"` → `Enums.Projectile.BULLET`，`"boomerang"` → `Enums.Projectile.BOOMERANG`，`"laser"` → `Enums.Projectile.LASER`

**Step 2: weapon.gd 和三个武器子类**

替换属性 key：
- `GameData.player_stats["damage_mult"]` → `GameData.player_stats[Enums.Stat.DAMAGE_MULT]`
- `GameData.player_stats["attack_speed_mult"]` → `GameData.player_stats[Enums.Stat.ATTACK_SPEED_MULT]`

**Step 3: boomerang_projectile.gd**

状态字符串替换为 enum：
- `var _state: String = "OUTBOUND"` → `var _state: Enums.BoomerangState = Enums.BoomerangState.OUTBOUND`
- 所有 `"OUTBOUND"` → `Enums.BoomerangState.OUTBOUND`
- 所有 `"RETURNING"` → `Enums.BoomerangState.RETURNING`

**Step 4: 类型标注补全（所有文件）**

**Step 5: 提交**

```bash
git add scripts/entities/weapons/ scripts/entities/projectiles/
git commit -m "refactor: weapons/projectiles 魔法字符串替换 + BoomerangState enum"
```

---

### Task 5: 替换 towers/ 模块

**Files:**
- Modify: `scripts/entities/towers/tower.gd` — 组名、移除未使用 export
- Modify: `scripts/entities/towers/tower_shooter.gd` — 组名、属性 key、私有前缀、类型标注
- Modify: `scripts/entities/towers/tower_slow.gd` — 组名、类型标注

**Step 1: tower.gd**

- `add_to_group("towers")` → `add_to_group(Enums.Group.TOWERS)`
- 移除未使用的 `@export var cost: int = 30`（如确认未使用）
- 类型标注补全

**Step 2: tower_shooter.gd**

- `get_nodes_in_group("enemies")` → `get_nodes_in_group(Enums.Group.ENEMIES)`
- `GameData.player_stats["tower_mult"]` → `GameData.player_stats[Enums.Stat.TOWER_MULT]`
- `shoot_nearest_enemy()` → `_shoot_nearest_enemy()`（更新调用处）
- 类型标注补全

**Step 3: tower_slow.gd**

- `get_nodes_in_group("enemies")` → `get_nodes_in_group(Enums.Group.ENEMIES)`
- `func _on_enemy_entered(body):` → `func _on_enemy_entered(body: Node2D) -> void:`
- `func _on_enemy_exited(body):` → `func _on_enemy_exited(body: Node2D) -> void:`
- 类型标注补全

**Step 4: 提交**

```bash
git add scripts/entities/towers/
git commit -m "refactor: towers/ 魔法字符串替换 + 类型标注 + 私有前缀"
```

---

### Task 6: 替换 systems/ 模块

**Files:**
- Modify: `scripts/systems/wave_manager.gd` — 组名、场景名、类型标注
- Modify: `scripts/systems/enemy_spawner.gd` — 类型标注
- Modify: `scripts/systems/shop_manager.gd` — 塔类型、属性 key、场景名
- Modify: `scripts/systems/effects_manager.gd` — 组名

**Step 1: wave_manager.gd**

- `add_to_group("wave_manager")` → `add_to_group(Enums.Group.WAVE_MANAGER)`
- `SceneManager.go_to("result")` → `SceneManager.go_to(Enums.Scene.RESULT)`
- `SceneManager.go_to("shop")` → `SceneManager.go_to(Enums.Scene.SHOP)`
- `get_nodes_in_group("enemies")` → `get_nodes_in_group(Enums.Group.ENEMIES)`
- `get_nodes_in_group("towers")` → `get_nodes_in_group(Enums.Group.TOWERS)`
- `get_nodes_in_group("coins")` → `get_nodes_in_group(Enums.Group.COINS)`
- 类型标注补全

**Step 2: enemy_spawner.gd**

- 类型标注补全
- `func _process(delta):` → `func _process(delta: float) -> void:`

**Step 3: shop_manager.gd**

- 塔类型数组：`["shooter", "wall", "slow"]` → `[Enums.Tower.SHOOTER, Enums.Tower.WALL, Enums.Tower.SLOW]`
- `SceneManager.go_to("placement")` → `SceneManager.go_to(Enums.Scene.PLACEMENT)`
- `SceneManager.go_to("main")` → `SceneManager.go_to(Enums.Scene.MAIN)`
- passive_upgrades 中的 stat key：`"hp_mult"` → `Enums.Stat.HP_MULT` 等
- 类型标注补全

**Step 4: effects_manager.gd**

- `add_to_group("damage_numbers")` → `add_to_group(Enums.Group.DAMAGE_NUMBERS)`
- `get_nodes_in_group("coins")` → `get_nodes_in_group(Enums.Group.COINS)`

**Step 5: 提交**

```bash
git add scripts/systems/
git commit -m "refactor: systems/ 魔法字符串替换 + 类型标注"
```

---

### Task 7: 替换 ui/ 模块

**Files:**
- Modify: `scripts/ui/main.gd` — 塔类型、类型标注
- Modify: `scripts/ui/hud.gd` — 组名、类型标注
- Modify: `scripts/ui/placement.gd` — 塔类型、场景名、组名、类型标注、私有前缀
- Modify: `scripts/ui/result.gd` — 场景名、类型标注
- Modify: `scripts/ui/start_menu.gd` — 场景名
- Modify: `scripts/ui/character_selection.gd` — 角色 ID、场景名
- Modify: `scripts/ui/weapon_select.gd` — 场景名
- Modify: `scripts/ui/map_select.gd` — 地图 ID、场景名

**Step 1: placement.gd**

- 塔类型：`"shooter"` → `Enums.Tower.SHOOTER` 等
- 场景名：`SceneManager.go_to("main")` → `SceneManager.go_to(Enums.Scene.MAIN)`
- 组名：`get_nodes_in_group("towers")` → `get_nodes_in_group(Enums.Group.TOWERS)`, `get_nodes_in_group("enemies")` → `get_nodes_in_group(Enums.Group.ENEMIES)`
- 节点名匹配：`"TowerShooter"` / `"TowerWall"` / `"TowerSlow"` — 保持（这些是节点名不是类型 ID）
- `use_fallback_background()` → `_use_fallback_background()`（更新调用处）
- 类型标注补全

**Step 2: 其他 UI 文件**

character_selection.gd:
- `"warrior"` → `Enums.Character.WARRIOR`，`"ranger"` → `Enums.Character.RANGER`，`"tank"` → `Enums.Character.TANK`
- `SceneManager.go_to("weapon_select")` → `SceneManager.go_to(Enums.Scene.WEAPON_SELECT)`

map_select.gd:
- `"forest"` → `Enums.Map.FOREST`，`"desert"` → `Enums.Map.DESERT`
- `SceneManager.go_to("placement")` → `SceneManager.go_to(Enums.Scene.PLACEMENT)`

start_menu.gd:
- `SceneManager.go_to("character_selection")` → `SceneManager.go_to(Enums.Scene.CHARACTER_SELECTION)`

weapon_select.gd:
- `SceneManager.go_to("map_select")` → `SceneManager.go_to(Enums.Scene.MAP_SELECT)`

result.gd:
- `SceneManager.go_to("start_menu")` → `SceneManager.go_to(Enums.Scene.START_MENU)`

hud.gd:
- `get_first_node_in_group("player")` → `get_first_node_in_group(Enums.Group.PLAYER)`

main.gd:
- 塔数据 `tower_data["type"]` 中的值替换
- 类型标注补全

**Step 3: 提交**

```bash
git add scripts/ui/
git commit -m "refactor: ui/ 魔法字符串替换 + 类型标注 + 私有前缀"
```

---

### Task 8: 替换 tests/ 中的魔法字符串

**Files:**
- Modify: `tests/unit/` 和 `tests/integration/` 中所有引用魔法字符串的测试文件

**Step 1: 查找并替换**

搜索所有测试文件中的魔法字符串，替换为 Enums 常量。常见模式：
- `"warrior"` → `Enums.Character.WARRIOR`
- `"rifle"` → `Enums.Weapon.RIFLE`
- `"normal"` / `"fast"` / `"tank"` → `Enums.Enemy.*`
- `"shooter"` / `"wall"` / `"slow"` → `Enums.Tower.*`
- `"forest"` → `Enums.Map.FOREST`
- 组名和场景名同理

注意：测试文件中的断言字符串、描述字符串不需要替换，只替换作为参数传入的实体 ID 和 key。

**Step 2: 提交**

```bash
git add tests/
git commit -m "refactor: tests/ 魔法字符串替换为 Enums 常量"
```

---

### Task 9: 运行全量测试验证

**Step 1: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Expected: 全部 161+ 个测试通过（数量可能因测试文件中枚举引用调整而变化）。

**Step 2: 修复失败的测试**

如有失败，逐个检查是否是替换遗漏或拼写错误导致。

**Step 3: 最终提交（如有修复）**

```bash
git add -A
git commit -m "fix: 修复规范整改后的测试问题"
```

---

## 注意事项

1. **不要替换 `.tres` 文件中的字符串** — Resource 文件中的 ID 是数据，保持原样
2. **不要替换注释中的字符串** — 注释仅供阅读
3. **不要替换 GameConfig.PLAYER / GameConfig.SPRITES 字典的 key 定义处** — 只替换访问处（或同时替换定义和访问，保持一致）
4. **`"tank"` 有歧义** — 在角色上下文用 `Enums.Character.TANK`，在敌人上下文用 `Enums.Enemy.TANK`，注意区分
5. **节点名字符串保持原样** — 如 `"TowerShooter"`、`"HUD"` 等是 Godot 节点名，不是类型 ID
6. **BoomerangState 是 int enum** — 替换后 `_state` 变量类型从 String 变为 `Enums.BoomerangState`，match 语句也需更新
