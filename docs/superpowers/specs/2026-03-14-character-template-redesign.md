# 角色模板重新设计

## 概述

重新设计 CharacterData Resource 模板，为 5 个角色提供差异化的数值属性和被动技能系统。

## 变更范围

### 新增字段
- `starting_gold: int` — 初始资金，用于第一波战斗前的布置阶段
- `passive_type: String` — 被动技能类型枚举（使用 `Enums.PassiveType` 常量）
- `passive_value: float` — 被动技能数值

### 移除字段
- `hp_regen: float` — 暂不需要生命回复
- `move_speed_mult: float` — 与 `speed` 功能重复，移除避免混淆

### 保留字段（无变化）
- `id`, `display_name`, `description`
- `max_hp`, `speed`, `damage_mult`, `attack_speed_mult`
- `default_weapon`, `default_tower`
- `passive_description`
- `sprite_frames_path`, `portrait_path`, `sprite_pixel_size`

## 完整字段定义

### 基础信息
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `id` | String | `""` | 角色唯一标识 |
| `display_name` | String | `""` | 中文显示名 |
| `description` | String | `""` | 角色描述/定位 |

### 数值属性
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `max_hp` | float | `100.0` | 血量上限 |
| `speed` | float | `100.0` | 移动速度 |
| `damage_mult` | float | `1.0` | 武器伤害倍率 |
| `attack_speed_mult` | float | `1.0` | 武器攻速倍率 |

### 初始装备
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `starting_gold` | int | `0` | 初始资金，与 `GameConfig.PLAYER["initial_coins"]` 叠加。公式：`coins = initial_coins + starting_gold` |
| `default_weapon` | String | `""` | 初始武器 ID |
| `default_tower` | String | `""` | 初始植物 ID |

### 被动技能
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `passive_type` | String | `""` | 被动类型，使用 `Enums.PassiveType` 常量（见下方枚举表） |
| `passive_value` | float | `0.0` | 被动数值 |
| `passive_description` | String | `""` | 被动技能中文描述（UI 展示用） |

### 美术资源
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `sprite_frames_path` | String | `""` | SpriteFrames 资源路径 |
| `portrait_path` | String | `""` | 头像 PNG 路径 |
| `sprite_pixel_size` | float | `16.0` | 原始精灵像素尺寸 |

## 被动技能类型枚举

在 `enums.gd` 中新增 `PassiveType` 常量类（与 WeaponId、TowerId 等保持一致风格）：

```gdscript
class PassiveType:
    const NONE = ""
    const KILL_HEAL = "kill_heal"
    const TOWER_ATTACK_SPEED_BONUS = "tower_attack_speed_bonus"
    const TOWER_HP_BONUS = "tower_hp_bonus"
    const COIN_BONUS = "coin_bonus"
    const DAMAGE_ON_LOW_HP = "damage_on_low_hp"
```

被动技能通过 `passive_type` + `passive_value` 组合定义，由现有系统的数值机制实现，不需要额外的技能框架代码。

| passive_type | 含义 | passive_value 示例 | 实现方式 |
|---|---|---|---|
| `kill_heal` | 击杀敌人回复血量 | `2.0`（回复 2 HP） | player.gd 监听 `EventBus.enemy_killed` 信号，调用 `health.heal(passive_value)` |
| `tower_attack_speed_bonus` | 所有塔攻速提升 | `0.15`（+15%） | 塔 `_ready()` 时从 `GameData` 读取被动倍率，自行 `apply_buff`。波间塔重建时自动生效 |
| `tower_hp_bonus` | 所有塔血量提升 | `0.2`（+20%） | 塔 `_ready()` 时从 `GameData` 读取被动倍率，应用到 HealthComponent 初始化 |
| `coin_bonus` | 金币掉落数量提升 | `0.2`（+20%） | `GameData` 存储 `coin_drop_mult`（从被动初始化），`enemy.gd` 的 `_drop_coins()` 读取 `GameData.coin_drop_mult` 作为额外乘数 |
| `damage_on_low_hp` | 低血量时伤害提升 | `0.3`（HP<30%时+30%伤害） | 阈值固定为 30% HP。`passive_value` 仅表示伤害加成比例。武器 `get_damage()` 计算时检查 `player.health.current_hp / max_hp < 0.3` |

> 注：以上为初始设计的被动类型候选，具体为每个角色分配哪种被动在实现阶段确定。可随需求扩展新类型。

## 移除字段的级联清理

移除 `hp_regen` 和 `move_speed_mult` 需要同步清理以下引用：

- `enums.gd` — 移除 `Enums.Stat.HP_REGEN` 和 `Enums.Stat.MOVE_SPEED_MULT` 常量
- `game_data.gd` — 从 `player_stats` 字典中移除对应键，移除 `character_hp_regen` 和 `character_move_speed_mult` 变量
- `player.gd` — 移除 hp_regen_timer 和回血循环逻辑，移除 move_speed_mult 读取
- `character_selection.gd` — 从 `STAT_BASELINES` 和 UI 展示中移除 hp_regen 相关项
- 测试文件 — 更新引用了这些字段的测试用例

## 影响范围

### 需要修改的文件
1. `scripts/resources/character_data.gd` — 增删字段
2. `resources/characters/*.tres`（5 个文件）— 更新数据值，填入差异化数值
3. `scripts/core/enums.gd` — 新增 `PassiveType` 常量类，移除 `Stat.HP_REGEN`/`Stat.MOVE_SPEED_MULT`
4. `scripts/core/game_data.gd` — 移除 `character_hp_regen`/`character_move_speed_mult`，新增 `starting_gold`/`coin_drop_mult` 处理，`reset()` 中金币公式改为 `initial_coins + starting_gold`
5. `scripts/entities/player.gd` — 移除 hp_regen 循环和 move_speed_mult 引用，添加被动技能初始化（如 `kill_heal` 连接 EventBus 信号）
6. `scripts/entities/towers/tower.gd` — `_ready()` 中读取 GameData 被动倍率，应用 `tower_attack_speed_bonus`/`tower_hp_bonus`
7. `scripts/entities/enemy.gd` — `_drop_coins()` 中读取 `GameData.coin_drop_mult`
8. `scripts/ui/character_selection.gd` — UI 展示更新（去掉 hp_regen 显示，加 starting_gold 和被动信息，调整 STAT_BASELINES）
9. `scripts/ui/placement.gd` — `starting_gold` 在首波布置阶段的金币初始化
10. 测试文件 — 更新引用了 hp_regen/move_speed_mult 的测试用例

### 不需要修改的文件
- `scripts/core/game_config.gd` — 加载逻辑无变化（自动从 .tres 读取新字段）
- `scripts/core/scene_factory.gd` — 不直接使用 CharacterData（塔自行读取 GameData 被动倍率）
