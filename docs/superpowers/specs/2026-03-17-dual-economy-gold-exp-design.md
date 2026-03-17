# 金币经验双轨制设计

## 概述

将当前单一金币资源改为金币 + 经验双轨制：
- **经验球**：怪物掉落，玩家拾取后累计经验，自动升级（提升人口上限）
- **金币**：每波固定奖励 + 向日葵生成，用于商店消费

## 核心规则

| 资源 | 来源 | 用途 |
|------|------|------|
| 经验 | 怪物掉落经验球、波次结束强制收集 | 自动升级（提升人口上限） |
| 金币 | 初始金币（100 + 角色 bonus）、每波固定 10、向日葵生成、卖出装备 | 商店购买武器/塔/刷新 |

## 1. 经验球实体

### 新文件
- `scripts/entities/exp_orb.gd`
- `scenes/entities/exp_orb.tscn`

### 行为
- `@export var value: int = 1` — 经验值
- `@export var attract_range: float = 30.0` — 短距离吸引（金币为 75）
- `@export var attract_speed: float = 200.0`
- 碰到玩家后调用 `player.add_exp(value)`，播放拾取音效（`"exp_pickup"` 占位，可复用已有音效）+ 缩放消失动画
- 波次结束时通过 `force_attract()` 强制吸引全部收集

### 场景结构
- Area2D 根节点
- Sprite2D 子节点（经验球精灵，占位图）
- CollisionShape2D 子节点（CircleShape2D）

### SceneFactory
- 新增 `create_exp_orb() -> Area2D`

## 2. 经验等级系统

### GameData 新增字段
- `var current_exp: int = 0` — 累计总经验（升级不重置）
- `var total_exp_earned: int = 0` — 统计用（结算页面显示）
- `player_level` 保留，不再由金币驱动
- `_DEFAULTS` 字典和 `reset()` 中需包含 `current_exp` 和 `total_exp_earned`

### 经验公式
升到等级 N 所需总经验：
```
exp_for_level(n) = floor(base_exp * n ^ exp_exponent)
```
默认参数 `base_exp=5, exp_exponent=2`：
- Lv2: 20, Lv3: 45, Lv5: 125, Lv10: 500

### 等级/人口无上限
- 人口上限 = `initial_population + (player_level - 1) * population_per_level`
- 默认 `initial_population=2, population_per_level=1`
- 靠经验曲线（指数增长）自然限制后期成长速度

### 新 Resource
- `scripts/resources/exp_config.gd`
  - `@export var base_exp: float = 5.0`
  - `@export var exp_exponent: float = 2.0`
  - `@export var initial_population: int = 2`
  - `@export var population_per_level: int = 1`
- `resources/exp_config.tres` — 数据文件
- `GameConfig` 注册 `exp_config: ExpConfig`

### GameData 升级逻辑
- `add_exp(amount: int)` — 累加 `current_exp` 和 `total_exp_earned`，循环检查是否达到下一级阈值，自动升级
- 升级时 emit `EventBus.player_level_changed`
- `get_population_cap()` 改用公式：`initial_population + (player_level - 1) * population_per_level`（从 ExpConfig 读取），不再读 ShopConfig 数组
- 移除 `buy_level_up()` 方法

### ShopConfig 字段移除
- 移除 `level_up_costs: PackedInt32Array`（升级不再花金币）
- 移除 `population_per_level: PackedInt32Array`（人口上限改由 ExpConfig 公式计算）

## 3. 金币来源改动

### 每波固定金币
- 波次结束进入 SHOP 阶段时，给玩家 +10 金币
- 金额配置：`ShopConfig` 新增 `@export var wave_reward: int = 10`
- emit `EventBus.coins_changed`

### 向日葵不变
- 继续通过 `EventBus.coins_generated` 生成金币

### 敌人不再掉金币
- `_on_died()` 不再调用 `_drop_coins()`
- `_drop_coins()` 方法和 `EnemyData.coin_drop_min/max` 字段保留，供未来使用

## 4. 敌人掉落改动

### EnemyData 新增字段
- `@export var exp_drop_min: int = 1`
- `@export var exp_drop_max: int = 1`

### enemy.gd 改动
- 新增 `_drop_exp_orbs()` 方法（参考 `_drop_coins()` 实现）
- `_on_died()` 调用 `_drop_exp_orbs()` 替代 `_drop_coins()`
- 精英怪倍率：`apply_elite()` 保留 `coin_mult` 参数，新增第 5 个参数 `exp_mult`，存入 `_elite_exp_mult`。调用方 `enemy_spawner.gd` 同步更新
- `WaveData` 新增 `@export var elite_exp_mult: float = 2.0`，各波次 `.tres` 文件配置

### 经验球分组
- `enums.gd` 新增 `EXP_ORBS` 分组常量
- 经验球创建时加入该分组，用于波次结束时批量强制吸引

### 各敌人 .tres 配置
需为每种敌人配置 `exp_drop_min/max`。Boss 敌人应配置较高数值。

## 5. Player 改动

### player.gd
- 新增 `add_exp(amount: int)` 方法
  - 调用 `GameData.add_exp(amount)`
  - emit `EventBus.exp_collected`

### 现有方法
- `add_coins()` 保留（向日葵金币仍需要）

## 6. UI 改动

### ShopOverlay
- 移除升级按钮相关：`_level_up_button` 变量及创建、`_update_level_up_button()` 方法及调用、`_on_level_up_pressed()` 方法
- 人口上限显示改为调用 `GameData.get_population_cap()`（当前直接读 ShopConfig 数组）
- 信息栏保留：金币 | 等级 Lv.N | 人口 used/max | 波次 WN

### HUD
- 不改动（后续统一优化）

### 结算页面（result.gd）
- 新增统计项："获取经验" = 总经验收集量
- 保留"获取金币"统计
- GameData 新增 `var total_exp_earned: int = 0`

## 7. EventBus 信号

### 新增
- `signal exp_collected(value: int, position: Vector2)` — 经验球被拾取
- `signal exp_changed(current_exp: int, exp_to_next: int)` — 经验值变化

### 保留不变
- `coins_changed`, `coins_generated`, `player_level_changed`

## 8. 数据流

### 战斗阶段
```
敌人死亡 → _drop_exp_orbs() → SceneFactory.create_exp_orb()
  → 经验球落地，短距离吸引（30px）
  → 玩家碰触 → player.add_exp(value) → GameData.add_exp(amount)
  → 达到阈值 → 自动升级 → EventBus.player_level_changed
  → 向日葵生成金币（不变）
```

### 波次结束
```
波次结束 → 经验球强制吸引 → 全部收集
  → 固定 +10 金币 → EventBus.coins_changed
  → 进入 SHOP 阶段
```

### 商店阶段
```
花金币买武器/塔/刷新（不变）
无"升级"按钮
开战 → BATTLE 阶段
```

## 9. 改动文件清单

| 操作 | 文件 |
|------|------|
| 新建 | `scripts/entities/exp_orb.gd`, `scenes/entities/exp_orb.tscn` |
| 新建 | `scripts/resources/exp_config.gd`, `resources/exp_config.tres` |
| 新建 | 经验球精灵占位图 |
| 改动 | `scripts/entities/enemy.gd` — 新增 `_drop_exp_orbs()`，`apply_elite()` 新增 exp_mult |
| 改动 | `scripts/entities/player.gd` — 新增 `add_exp()` |
| 改动 | `scripts/core/game_data.gd` — 新增 `current_exp`/`total_exp_earned`/`add_exp()`，改写 `get_population_cap()`，移除 `buy_level_up()`，`reset()` 重置新字段 |
| 改动 | `scripts/core/game_config.gd` — 注册 `exp_config` |
| 改动 | `scripts/core/scene_factory.gd` — 新增 `create_exp_orb()` |
| 改动 | `scripts/core/event_bus.gd` — 新增经验信号 |
| 改动 | `scripts/core/enums.gd` — 新增 `EXP_ORBS` 分组常量 |
| 改动 | `scripts/resources/enemy_data.gd` — 新增 `exp_drop_min/max` |
| 改动 | `scripts/resources/shop_config.gd` — 新增 `wave_reward`，移除 `level_up_costs`/`population_per_level` |
| 改动 | `scripts/systems/wave_manager.gd` — 新增 `attract_all_exp_orbs()` 或修改现有吸引逻辑 |
| 改动 | `scripts/ui/shop_overlay.gd` — 移除升级按钮 |
| 改动 | `scripts/ui/main.gd` — 波次结束给固定金币 |
| 改动 | `scripts/ui/result.gd` — 新增经验统计 |
| 改动 | 各敌人 `.tres` — 配置 `exp_drop_min/max` |
| 改动 | `scripts/systems/enemy_spawner.gd` — `apply_elite()` 调用传入 exp_mult |
| 改动 | `scripts/resources/wave_data.gd` — 新增 `elite_exp_mult` 字段 |
| 改动 | 各波次 `.tres` — 配置 `elite_exp_mult` |
| 改动 | `tests/unit/test_game_data_economy.gd` — 移除 buy_level_up 测试，新增 add_exp/升级/人口测试 |
| 改动 | `tests/unit/test_elite_enemy.gd` — 更新 apply_elite 测试 |
