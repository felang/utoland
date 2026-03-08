# 波次系统重新设计

日期：2026-03-08

## 设计目标

1. **更多变化和策略性** — 波次内容更丰富，不再是单调的随机刷怪
2. **Boss 和精英怪** — 普通波有精英怪点缀，特定波次有独立 Boss 战
3. **可控难度曲线** — 基于敌人数量（击杀制）推进，而非纯时间驱动

## 核心决策

| 决策项 | 选择 |
|--------|------|
| 波次结束条件 | 击杀制 + 时间上限兜底 |
| 精英怪设计 | 属性加成（复用现有敌人，运行时乘倍率） |
| Boss 设计 | 独立实体（独立 EnemyData + 场景 + 专属行为） |
| 波次总数 | 可配置，不同地图不同波次数量 |
| 敌人生成方式 | 权重随机 |

## WaveData Resource 扩展

```gdscript
class_name WaveData
extends Resource

# 基础配置
@export var wave_number: int = 1
@export var total_enemies: int = 15          # 本波敌人总数（击杀制）
@export var time_limit: float = 60.0         # 时间上限兜底
@export var spawn_interval: float = 1.5      # 生成间隔

# 敌人权重（替代原 enemy_types）
@export var enemy_weights: Dictionary = {"normal": 100}  # {enemy_id: weight}

# 精英怪
@export var elite_chance: float = 0.0        # 0.0 ~ 1.0
@export var elite_hp_mult: float = 1.5
@export var elite_damage_mult: float = 1.3
@export var elite_coin_mult: float = 2.0
@export var elite_scale: float = 1.2         # 体型放大倍率

# Boss 波
@export var is_boss_wave: bool = false
@export var boss_id: String = ""             # Boss 的 EnemyData id
@export var boss_escort_count: int = 0       # 护卫小怪数量
```

**说明：**
- `enemy_weights` 按权重随机选取敌人类型
- 精英怪复用 EnemyData，运行时乘以倍率 + 放大体型
- Boss 波先刷护卫小怪，再生成 Boss

## WaveManager 逻辑改造

### 波次结束条件（双轨制）

```
波次结束 = enemies_killed >= total_enemies 或 时间 >= time_limit
```

### 新增状态

- `enemies_spawned: int` — 已生成敌人数
- `enemies_killed: int` — 已击杀敌人数
- `boss_spawned: bool` — Boss 是否已生成

### 普通波流程

1. `wave_started` 信号
2. EnemySpawner 按 `spawn_interval` 生成，直到 `enemies_spawned >= total_enemies`
3. 玩家击杀敌人 → `enemies_killed++`
4. `enemies_killed >= total_enemies` → `complete_wave()`
5. 或 `time_limit` 到 → `complete_wave()`（兜底）

### Boss 波流程

1. `wave_started` 信号
2. 先生成 `boss_escort_count` 个护卫小怪（间隔生成）
3. 护卫全部生成后，生成 Boss
4. Boss 死亡 → `complete_wave()`（不等小怪清完）
5. 或 `time_limit` 到 → `complete_wave()`（兜底）

### 击杀计数

- 敌人死亡时通过 EventBus 发出 `enemy_killed` 信号
- WaveManager 监听并累加计数

## EnemySpawner 改造

### 权重随机选敌

从 `enemy_weights {"normal": 70, "fast": 30}` 中按权重随机选取。

### 精英怪生成

每次生成敌人时 roll 概率，命中则：
- `enemy.health.max_hp *= elite_hp_mult`
- `enemy.health.current_hp = enemy.health.max_hp`
- `enemy.data.damage *= elite_damage_mult`
- `enemy.scale *= elite_scale`
- `enemy.add_to_group("elites")`

### 生成上限控制

`enemies_spawned >= wave_data.total_enemies` 时停止生成。

### Boss 波分阶段

```
状态机：
  ESCORT_PHASE → 按 spawn_interval 生成护卫，达到 boss_escort_count
  BOSS_PHASE → 生成 Boss
  DONE → 停止生成
```

## Boss 实体设计

Boss 复用 EnemyData Resource，但有独立 `.tscn` 场景和专属行为节点。

### 初期 Boss 规划

| Boss ID | 出现时机 | 风格 | 专属行为 |
|---------|---------|------|---------|
| `boss_brute` | 中期 | 重型近战 | 冲锋、践踏（范围伤害） |
| `boss_summoner` | 后期 | 召唤师 | 周期召唤小怪、远离玩家 |
| `boss_guardian` | 最终波 | 终极 Boss | 护盾阶段、多阶段血条 |

### Boss 场景结构

```
Boss (CharacterBody2D) [boss_*.gd extends enemy.gd]
├── HealthComponent
├── SpriteAnimator
├── Hurtbox
├── KnockbackHandler（可选）
└── BossAbility（专属行为节点）
```

### 集成方式

- SceneFactory 新增 `create_boss(boss_id)` 或复用 `create_enemy(boss_id)` 区分
- Boss EnemyData 配在 `resources/enemies/`
- Boss 场景放在 `scenes/entities/enemies/`
- Boss 死亡发出 `boss_killed` 信号

## 难度曲线示例（18 波）

| 波次 | 类型 | 总敌人 | 间隔 | 时间上限 | 敌人权重 | 精英概率 | Boss |
|------|------|--------|------|---------|---------|---------|------|
| 1 | 普通 | 10 | 2.0s | 45s | normal:100 | 0% | — |
| 2 | 普通 | 12 | 1.8s | 45s | normal:80, fast:20 | 0% | — |
| 3 | 普通 | 15 | 1.5s | 50s | normal:70, fast:30 | 5% | — |
| 4-5 | 普通 | 18-20 | 1.3s | 50s | normal:60, fast:40 | 8% | — |
| 6-7 | 普通 | 22-25 | 1.2s | 55s | normal:40, fast:35, tank:25 | 10% | — |
| 8 | Boss | 10护卫 | 1.0s | 90s | fast:60, tank:40 | 0% | boss_brute |
| 9-12 | 普通 | 28-35 | 1.0s | 60s | normal:30, fast:40, tank:30 | 15% | — |
| 13-14 | 普通 | 38-40 | 0.8s | 60s | fast:50, tank:50 | 20% | — |
| 15 | Boss | 15护卫 | 0.8s | 120s | normal:30, fast:40, tank:30 | 10% | boss_summoner |
| 16-17 | 普通 | 42-45 | 0.6s | 65s | fast:40, tank:60 | 25% | — |
| 18 | Boss | 20护卫 | 0.5s | 150s | fast:50, tank:50 | 15% | boss_guardian |

## MapData 扩展

新增 `wave_count: int` 字段。波次 .tres 文件按地图分目录：`resources/waves/<map_id>/`。

## EventBus 新增信号

```gdscript
signal enemy_killed(enemy_id: String, is_elite: bool)
signal boss_killed(boss_id: String)
```

## 改动范围

### 需要修改

| 文件 | 改动 |
|------|------|
| `scripts/resources/wave_data.gd` | 新增字段 |
| `scripts/systems/wave_manager.gd` | 击杀制 + 时间兜底，监听新信号 |
| `scripts/systems/enemy_spawner.gd` | 权重随机、精英生成、上限控制、Boss 分阶段 |
| `scripts/entities/enemy.gd` | 死亡时发出 enemy_killed，支持精英属性注入 |
| `scripts/core/event_bus.gd` | 新增 enemy_killed、boss_killed |
| `scripts/resources/map_data.gd` | 新增 wave_count |
| `scripts/core/game_config.gd` | 按地图分目录加载波次 |
| `resources/waves/*.tres` | 全部重写 |

### 需要新增

| 文件 | 说明 |
|------|------|
| `resources/enemies/boss_*.tres` | Boss EnemyData |
| `scenes/entities/enemies/boss_*.tscn` | Boss 场景 |
| `scripts/entities/boss_*.gd` | Boss 行为脚本 |
| `resources/waves/<map_id>/` | 按地图分目录波次配置 |

### 不需要改动

- 商店系统（ShopManager / ShopItemGenerator / ShopEffectApplier）
- ItemEffectManager（继续监听 wave_completed/wave_started）
- Player / Tower / 组件系统
- HUD（后续可增加波次信息，非本次必须）

## 暂不实现（后续迭代）

- Boss 多阶段血条
- Boss 专属 BGM
- Boss 血条 UI
- Boss 具体行为实现（冲锋、召唤等，本次只搭框架）
