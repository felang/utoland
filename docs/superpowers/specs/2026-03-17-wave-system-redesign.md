# 波次系统重设计：纯时间制 + 分段生成

## 概述

将波次系统从"时间 + 敌人数量"双重结束条件改为**纯时间限制**（土豆兄弟风格）。总波次从 20 波缩减为 **15 波**，每 5 波一个 Boss 关（第 5/10/15 波）。

## 设计决策

| 决策项 | 方案 |
|--------|------|
| 波次结束条件 | 仅时间，时间到清除所有残余敌人 |
| Boss 波次 | 同样受时间限制，Boss 没杀死算错过奖励 |
| 生成节奏 | 分段式（每波 2-3 阶段，前慢后快） |
| 敌人数量控制 | `max_alive_enemies` 场上同时存在上限 |
| 难度缩放 | 保持现有逻辑（Wave 11+ 指数增长 HP/伤害）不变 |
| 波次时长 | 逐波递增，在 `.tres` 中配置 |

## WaveData 资源改造

### 移除字段

- `total_enemies: int` — 不再需要固定敌人总数
- `spawn_interval: float` — 由分段配置替代

### 新增字段

```gdscript
## 场上敌人同时存在上限
@export var max_alive_enemies: int = 30

## 分段生成配置
## 每段: {duration_ratio: float, spawn_interval: float, enemy_weights: Dictionary(可选)}
@export var spawn_phases: Array[Dictionary] = []
```

### 保留字段

- `wave_number: int`
- `time_limit: float` — 逐波递增（如 40s → 90s）
- `enemy_weights: Dictionary` — 作为默认权重，段内可覆盖
- `elite_chance / elite_hp_mult / elite_damage_mult / elite_coin_mult / elite_scale / elite_exp_mult`
- `is_boss_wave: bool`
- `boss_id: String`

### 移除字段

- `boss_escort_count: int` — 改由分段的间隔和时长自然控制护卫密度

### spawn_phases 示例

```gdscript
# 普通波次（3 阶段：热身 → 正常 → 高压）
spawn_phases = [
    {duration_ratio = 0.3, spawn_interval = 2.0},
    {duration_ratio = 0.5, spawn_interval = 0.8},
    {duration_ratio = 0.2, spawn_interval = 0.4}
]

# Boss 波次（2 阶段：护卫 → Boss 登场）
spawn_phases = [
    {duration_ratio = 0.6, spawn_interval = 1.0, enemy_weights = {"normal": 50, "fast": 30, "tank": 20}},
    {duration_ratio = 0.4, spawn_interval = 0.6, enemy_weights = {"fast": 40, "tank": 60}}
]
```

- 各段 `duration_ratio` 之和必须 = 1.0
- 段内 `enemy_weights` 可选，省略时继承波次级别的 `enemy_weights`

## EnemySpawner 改造

### 新增状态

```gdscript
var _current_phase_index: int = 0
var _phase_time_elapsed: float = 0.0
var _phase_duration: float = 0.0       # 当前阶段实际秒数
var _current_spawn_interval: float = 0.0
var _current_enemy_weights: Dictionary = {}
```

### 生成逻辑

```
每帧 _process(delta):
  1. 如果 !_is_wave_active → 返回
  2. 检查阶段切换：_phase_time_elapsed >= _phase_duration → 进入下一阶段
  3. 检查 max_alive_enemies：场上敌人数 >= max_alive_enemies → 跳过生成
  4. spawn_timer += delta，达到 _current_spawn_interval → 生成一个敌人
  5. Boss 波次：进入最后阶段时生成 Boss（仅一次）
```

### 阶段切换

```gdscript
func _enter_phase(index: int) -> void:
    _current_phase_index = index
    var phase = _current_wave_data.spawn_phases[index]
    _phase_duration = _current_wave_data.time_limit * phase.duration_ratio
    _phase_time_elapsed = 0.0
    _current_spawn_interval = phase.spawn_interval
    _current_enemy_weights = phase.get("enemy_weights", _current_wave_data.enemy_weights)
```

### 场上敌人计数

通过 `get_tree().get_nodes_in_group("enemies").size()` 获取当前场上敌人数量，与 `max_alive_enemies` 比较。

## WaveManager 改造

### 简化结束条件

```gdscript
# 移除 enemies_killed 计数和相关逻辑
# 移除 _on_enemy_killed 中的完成检查
# 仅保留时间到期触发 complete_wave()

func _process(delta: float) -> void:
    if not is_wave_active:
        return
    wave_time_left -= delta
    if wave_time_left <= 0:
        complete_wave()
```

### Boss 波次处理

- 保留 `EventBus.boss_killed` 信号监听
- Boss 被杀 → 不再立即结束波次，仅标记 Boss 已击杀（用于奖励判定）
- 时间到 → 统一走 `complete_wave()` 清场

### 信号调整

- `enemy_killed` 信号保留（用于 HUD 显示、经验等），但不再用于波次完成判定
- 新增可选：`boss_escaped` 信号（Boss 波次时间到但 Boss 未被击杀时触发，用于 UI 提示）

## 波次配置（15 波，forest 地图）

| 波次 | 时长 | max_alive | 阶段概要 | Boss |
|------|------|-----------|----------|------|
| 1 | 40s | 15 | 慢启动，纯 normal | - |
| 2 | 42s | 18 | normal 为主，少量 fast | - |
| 3 | 45s | 20 | normal + fast | - |
| 4 | 48s | 22 | 三种混合，5% 精英 | - |
| **5** | **60s** | **25** | 护卫 → Boss 登场 | **boss_brute** |
| 6 | 50s | 22 | fast 为主 | - |
| 7 | 52s | 25 | fast + tank，8% 精英 | - |
| 8 | 55s | 28 | 三种高压，10% 精英 | - |
| 9 | 58s | 30 | tank 为主 | - |
| **10** | **75s** | **30** | 护卫 → Boss 登场 | **boss_summoner** |
| 11 | 60s | 30 | 高密度三种混合 | - |
| 12 | 65s | 32 | fast + tank，12% 精英 | - |
| 13 | 70s | 35 | 极高密度 | - |
| 14 | 75s | 38 | 全精英前奏，15% 精英 | - |
| **15** | **90s** | **40** | 终极护卫 → Boss 登场 | **boss_guardian** |

## 影响范围

### 需要修改的文件

| 文件 | 改动 |
|------|------|
| `scripts/resources/wave_data.gd` | 移除 `total_enemies`/`spawn_interval`/`boss_escort_count`，新增 `max_alive_enemies`/`spawn_phases` |
| `scripts/systems/enemy_spawner.gd` | 分段生成逻辑、max_alive 检查、移除 BossPhase 状态机（简化为阶段切换） |
| `scripts/systems/wave_manager.gd` | 移除击杀计数完成逻辑、Boss 击杀不再立即结束波次 |
| `scripts/core/event_bus.gd` | 可选新增 `boss_escaped` 信号 |
| `resources/waves/forest/*.tres` | 全部重写为 15 波配置 |
| `resources/waves/desert/*.tres` | 同上（如果有） |
| `tests/unit/test_wave_manager.gd` | 更新测试用例 |
| `tests/unit/test_boss_wave_spawner.gd` | 更新 Boss 波次测试 |
| `tests/unit/test_wave_scaling.gd` | 调整为 15 波 |
| `tests/integration/test_wave_system.gd` | 更新集成测试 |

### 不需要修改的文件

- `scripts/core/game_config.gd` — 波次加载逻辑不变
- `scripts/core/game_data.gd` — 波次状态跟踪不变
- `scripts/ui/main.gd` — Phase 状态机和信号监听不变
- `scripts/ui/hud.gd` — 倒计时显示逻辑不变
- 难度缩放逻辑 — 保持不变
- 精英系统 — 保持不变
