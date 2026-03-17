# GameData 拆分设计

## 背景

`GameData`（339 行）承担 6 个职责：角色系统、经济系统、经验/人口系统、部署管理、里程碑增强、统计系统。文件过大、职责混杂导致代码难以定位、扩展波及面大、子系统耦合紧密、测试困难。

## 目标

- 将 GameData 拆分为 4 个独立 Autoload，各司其职
- 删除未使用的里程碑/战斗增强字段
- 一步到位更新所有引用（~30 个文件）

## 方案：精细四拆

移除 `GameData` Autoload，新增 4 个：

| Autoload | 文件 | 职责 |
|----------|------|------|
| **PlayerState** | `scripts/core/player_state.gd` | 角色身份、属性、被动、player_stats、selected_map、current_wave、pending_heal |
| **PlayerProgression** | `scripts/core/player_progression.gd` | exp、level、population cap 计算 |
| **InventoryManager** | `scripts/core/inventory_manager.gd` | coins、deployed_weapons/towers、shop_slots、buy/sell、merge、deploy_id、population 使用量 |
| **StatsTracker** | `scripts/core/stats_tracker.gd` | 击杀、金币、伤害统计、连杀 |

### Autoload 加载顺序

```
GameConfig → PlayerState → PlayerProgression → InventoryManager → StatsTracker → SceneFactory → ...
```

### 依赖关系

- `PlayerState` → `GameConfig`（读 CharacterData）
- `PlayerProgression` → `GameConfig`（读 ExpConfig）
- `InventoryManager` → `GameConfig`（读武器/塔 Resource、PLAYER 常量）、`PlayerState`（读 current_character 获取 CharacterData）、`PlayerProgression`（查人口上限）、`EventBus`
- `StatsTracker` → 无依赖

### reset() 策略

由调用方（`character_selection.gd`、`result.gd`）依次调用各 Autoload 的 `reset()`，不做跨 Autoload 自动联动。

**调用顺序必须为**：`PlayerState.reset()` → `PlayerProgression.reset()` → `InventoryManager.reset()` → `StatsTracker.reset()`

原因：`InventoryManager.reset()` 需要读取 `PlayerState.current_character` 来获取 CharacterData（starting_gold、recommended_weapon/tower、starting_weapon）。

各 Autoload 不再使用 `_DEFAULTS` 字典批量重置，改为在各自的 `reset()` 中逐字段显式赋默认值。

## API 设计

### PlayerState (`scripts/core/player_state.gd`)

```gdscript
var current_character: String
var selected_map: String
var current_wave: int
var character_max_hp: float
var character_speed: float
var character_damage_mult: float
var character_attack_speed_mult: float
var new_passive_id: String
var new_passive_value: float
var new_passive_value_2: float
var player_stats: Dictionary  # {Enums.Stat.*: float}
var pending_heal: int

func init_character(character_id: String) -> void
func reset() -> void  # 调用 init_character(current_character)，重置 player_stats/selected_map/pending_heal
```

### PlayerProgression (`scripts/core/player_progression.gd`)

```gdscript
var player_level: int
var current_exp: int
var total_exp_earned: int

func exp_for_level(level: int) -> int
func add_exp(amount: int) -> void       # 自动升级 + emit EventBus 信号
func get_population_cap() -> int
func reset() -> void
```

### InventoryManager (`scripts/core/inventory_manager.gd`)

```gdscript
var coins: int
var deployed_weapons: Array[Dictionary]
var deployed_towers: Array[Dictionary]
var shop_slots: Array[Dictionary]
var is_first_shop_visit: bool
var _recommended_weapon: String
var _recommended_tower: String
var _next_deploy_id: int

func get_population_used() -> int
func can_deploy() -> bool
func can_buy_item(item_id: String, item_level: int) -> bool
func buy_and_equip_weapon(weapon_id: String, cost: int) -> bool
func buy_and_place_tower(tower_id: String, cost: int, grid_pos: Vector2i) -> int
func move_tower(deploy_id: int, new_grid_pos: Vector2i) -> bool
func sell_from_deployed_weapon(deploy_index: int) -> int
func sell_from_deployed_tower(deploy_id: int) -> int
func reset() -> void  # 读 PlayerState.current_character 获取 CharacterData，设置 coins/recommended/starting_weapon
```

跨 Autoload 依赖：`can_deploy()` 调用 `PlayerProgression.get_population_cap()`；`reset()` 读 `PlayerState.current_character`。

### StatsTracker (`scripts/core/stats_tracker.gd`)

```gdscript
var total_kills: int
var total_coins_earned: int
var total_damage_taken: float
var max_kill_streak: int
var current_kill_streak: int

func record_kill() -> void
func reset_kill_streak() -> void
func record_damage_taken(amount: float) -> void
func record_coins_earned(amount: int) -> void
func reset() -> void
```

## 引用迁移映射

| 旧引用 | 新引用 |
|--------|--------|
| `GameData.current_character` | `PlayerState.current_character` |
| `GameData.selected_map` | `PlayerState.selected_map` |
| `GameData.current_wave` | `PlayerState.current_wave` |
| `GameData.character_max_hp/speed/damage_mult/attack_speed_mult` | `PlayerState.*` |
| `GameData.new_passive_id/value/value_2` | `PlayerState.*` |
| `GameData.player_stats` | `PlayerState.player_stats` |
| `GameData.pending_heal` | `PlayerState.pending_heal` |
| `GameData.init_character()` | `PlayerState.init_character()` |
| `GameData.player_level` | `PlayerProgression.player_level` |
| `GameData.current_exp` | `PlayerProgression.current_exp` |
| `GameData.total_exp_earned` | `PlayerProgression.total_exp_earned` |
| `GameData.exp_for_level()` | `PlayerProgression.exp_for_level()` |
| `GameData.add_exp()` | `PlayerProgression.add_exp()` |
| `GameData.get_population_cap()` | `PlayerProgression.get_population_cap()` |
| `GameData.coins` | `InventoryManager.coins` |
| `GameData.deployed_weapons` | `InventoryManager.deployed_weapons` |
| `GameData.deployed_towers` | `InventoryManager.deployed_towers` |
| `GameData.shop_slots` | `InventoryManager.shop_slots` |
| `GameData.can_deploy/can_buy_item` | `InventoryManager.*` |
| `GameData.buy_and_equip_weapon/buy_and_place_tower` | `InventoryManager.*` |
| `GameData.move_tower` | `InventoryManager.move_tower()` |
| `GameData.sell_from_deployed_weapon/tower` | `InventoryManager.*` |
| `GameData._check_merge` | `InventoryManager._check_merge()`（内部方法） |
| `GameData._recommended_weapon/tower` | `InventoryManager._recommended_weapon/tower` |
| `GameData.is_first_shop_visit` | `InventoryManager.is_first_shop_visit` |
| `GameData.record_kill/reset_kill_streak` | `StatsTracker.*` |
| `GameData.record_damage_taken/record_coins_earned` | `StatsTracker.*` |
| `GameData.total_kills/total_coins_earned/total_damage_taken/max_kill_streak` | `StatsTracker.*` |
| `GameData.reset()` | 各 Autoload 分别 `.reset()` |

## 里程碑字段删除

删除以下字段（未使用的保留字段）：

```
pierce_count, multishot_active, multishot_damage_mult,
split_count, split_damage_mult, bullet_speed_mult,
weapon_range_mult, crit_chance, crit_damage_mult
```

受影响文件：

| 文件 | 引用 | 处理 |
|------|------|------|
| `weapon_manager.gd:133-158` | `split_count`、`split_damage_mult`、分裂弹逻辑 | 删除分裂弹代码块 |
| `weapon.gd:51` | `pierce_count` | 移除额外穿透加成 |
| `shuriken_weapon.gd:12` | `pierce_count` | 移除额外穿透加成 |

## 需要更新的文件清单（~30 个）

### 生产代码（~16 个）
- `scripts/ui/main.gd` — InventoryManager（coins）+ PlayerState（selected_map）+ StatsTracker（record_coins_earned）
- `scripts/entities/player.gd` — PlayerState + PlayerProgression + InventoryManager（coins 同步）+ StatsTracker
- `scripts/entities/enemy.gd` — StatsTracker
- `scripts/entities/coin.gd` — StatsTracker
- `scripts/entities/weapons/weapon_manager.gd` — InventoryManager + PlayerState，删除分裂弹代码
- `scripts/entities/weapons/weapon.gd` — 删除 pierce_count 引用
- `scripts/entities/weapons/shuriken_weapon.gd` — 删除 pierce_count 引用
- `scripts/entities/towers/tower_shooter.gd` — PlayerState
- `scripts/systems/wave_manager.gd` — PlayerState
- `scripts/systems/shop_manager.gd` — InventoryManager
- `scripts/systems/drag_manager.gd` — InventoryManager
- `scripts/ui/hud.gd` — PlayerProgression
- `scripts/ui/result.gd` — PlayerState + StatsTracker + InventoryManager
- `scripts/ui/shop_overlay.gd` — InventoryManager + PlayerProgression + PlayerState
- `scripts/ui/character_selection.gd` — PlayerState + InventoryManager + PlayerProgression + StatsTracker
- `scripts/ui/map_select.gd` — PlayerState
- `scripts/ui/debug_panel.gd` — InventoryManager + PlayerState

### 测试文件（~12 个）
- `tests/unit/test_game_data.gd` — 重命名/拆分为对应 Autoload 测试
- `tests/unit/test_game_data_economy.gd` — 拆分到 InventoryManager + PlayerProgression 测试
- `tests/unit/test_game_data_stats.gd` — 迁移到 StatsTracker 测试
- `tests/unit/test_merge_system.gd` — InventoryManager
- `tests/unit/test_shop_manager.gd` — InventoryManager + PlayerProgression
- `tests/unit/test_shop_overlay.gd` — InventoryManager + PlayerProgression
- `tests/unit/test_drag_manager.gd` — InventoryManager + PlayerProgression
- `tests/unit/test_weapon_manager.gd` — InventoryManager
- `tests/unit/test_new_passives.gd` — PlayerState + PlayerProgression + InventoryManager
- `tests/unit/test_character_selection.gd` — PlayerState
- `tests/integration/test_tower_placement.gd` — InventoryManager
- `tests/integration/test_combat_flow.gd` — PlayerState

### 项目配置
- `project.godot` — 移除 GameData autoload，新增 4 个
- `CLAUDE.md` — 更新 Autoload 单例文档
