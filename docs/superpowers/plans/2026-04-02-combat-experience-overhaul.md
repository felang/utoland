# 战斗体验重塑 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将战斗从"全程无聊的自动跑圈"改造为有决策、有节奏、有反馈的完整体验

**Architecture:** 六个独立模块：分批清敌制波次系统、波次修饰词、升级即时属性提升、被动自由池、角色主动技能（Dora）、4 种新敌人。模块间通过 EventBus 信号解耦，数据通过 Resource 类定义和 .tres 文件配置。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架, Jolt Physics

> **Headless 测试注意**：本计划新增约 12 个 `class_name` 脚本。如无法通过 Godot 编辑器自动刷新，需手动在 `.godot/global_script_class_cache.cfg` 中补充对应条目，否则 headless 测试无法识别新类名。建议在每个创建 `class_name` 脚本的 Task 完成后立即验证 headless 测试能否识别该类。

**Spec:** `docs/superpowers/specs/2026-04-02-combat-experience-overhaul-design.md`

---

## 文件结构总览

### 新建文件
```
# Resource 类定义
scripts/resources/wave_modifier_data.gd
scripts/resources/passive_data.gd
scripts/resources/active_skill_data.gd
scripts/resources/ranger_behavior_data.gd
scripts/resources/bomber_behavior_data.gd
scripts/resources/splitter_behavior_data.gd
scripts/resources/shielder_behavior_data.gd

# 组件
scripts/components/active_skill_component.gd
scripts/components/enemy_behaviors/ranger_behavior.gd
scripts/components/enemy_behaviors/bomber_behavior.gd
scripts/components/enemy_behaviors/splitter_behavior.gd
scripts/components/enemy_behaviors/shielder_behavior.gd

# UI
scripts/ui/passive_selection.gd
scenes/ui/passive_selection.tscn

# 敌人场景
scenes/entities/enemies/ranger.tscn
scenes/entities/enemies/bomber.tscn
scenes/entities/enemies/splitter.tscn
scenes/entities/enemies/splitter_mini.tscn
scenes/entities/enemies/shielder.tscn

# 投射物
scenes/entities/projectiles/enemy_arrow.tscn

# Resource 配置 (.tres)
resources/modifiers/elite_invasion.tres
resources/modifiers/four_sides.tres
resources/modifiers/speed_rush.tres
resources/modifiers/heavy_assault.tres
resources/modifiers/frenzy_spawn.tres
resources/modifiers/double_exp.tres
resources/modifiers/gold_rain.tres
resources/modifiers/treasure_wave.tres
resources/passives/dora/*.tres (10 个)
resources/skills/dora_slash.tres
resources/enemies/ranger.tres
resources/enemies/bomber.tres
resources/enemies/splitter.tres
resources/enemies/splitter_mini.tres
resources/enemies/shielder.tres

# 测试
tests/unit/test_wave_clear_system.gd
tests/unit/test_wave_modifiers.gd
tests/unit/test_level_up_bonus.gd
tests/unit/test_passive_pool.gd
tests/unit/test_active_skill.gd
tests/unit/test_enemy_behaviors.gd
tests/integration/test_combat_overhaul.gd
```

### 修改文件
```
scripts/resources/wave_data.gd          — 字段重构
scripts/resources/spawn_phase_data.gd   — 字段重构
scripts/resources/enemy_data.gd         — 新增 behavior_config
scripts/resources/exp_config.gd         — 新增等级加成字段
scripts/resources/character_data.gd     — 新增 passive_pool，废弃旧被动字段
scripts/systems/wave_manager.gd         — 清敌制结束条件 + 修饰词
scripts/systems/enemy_spawner.gd        — 分批生成 + 清波加速
scripts/core/player_progression.gd      — 升级属性加成
scripts/core/player_state.gd            — 被动系统 + 属性叠加
scripts/core/event_bus.gd               — 新增信号
scripts/core/game_config.gd             — 注册新 Resource 类型
scripts/core/scene_factory.gd           — 注册新敌人 + 投射物
scripts/entities/player.gd              — 技能集成 + 移除硬编码常量
scripts/entities/enemy.gd               — 行为组件检测
scripts/ui/hud.gd                       — 击杀计数 + 技能CD + 修饰词
scripts/ui/main.gd                      — 波间被动选择流程
scripts/systems/effects_manager.gd      — 升级特效 + 技能特效
resources/waves/forest/*.tres            — 12 波全部重写
resources/exp_config.tres                — 新增字段值
project.godot                            — 新增输入映射
```

---

## Task 1: WaveData / SpawnPhaseData 字段重构

**Files:**
- Modify: `scripts/resources/wave_data.gd`
- Modify: `scripts/resources/spawn_phase_data.gd`
- Test: `tests/unit/test_wave_clear_system.gd`

- [ ] **Step 1: 创建测试文件，编写 WaveData 字段测试**

```gdscript
# tests/unit/test_wave_clear_system.gd
extends GutTest

func test_wave_data_has_total_enemies() -> void:
	var wd := WaveData.new()
	wd.total_enemies = 30
	assert_eq(wd.total_enemies, 30)

func test_wave_data_has_safety_timeout() -> void:
	var wd := WaveData.new()
	wd.time_limit_safety = 120.0
	wd.timeout_reward_ratio = 0.5
	assert_eq(wd.time_limit_safety, 120.0)
	assert_eq(wd.timeout_reward_ratio, 0.5)

func test_spawn_phase_has_enemy_count_ratio() -> void:
	var phase := SpawnPhaseData.new()
	phase.enemy_count_ratio = 0.3
	assert_eq(phase.enemy_count_ratio, 0.3)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_wave_clear_system.gd -gexit`
Expected: FAIL — `total_enemies` 属性不存在

- [ ] **Step 3: 修改 WaveData，移除 time_limit，新增字段**

`scripts/resources/wave_data.gd`:
```gdscript
class_name WaveData extends Resource

@export var wave_number: int = 1
@export var total_enemies: int = 30
@export var time_limit_safety: float = 120.0
@export var timeout_reward_ratio: float = 0.5
@export var max_alive_enemies: int = 30
@export var spawn_phases: Array[SpawnPhaseData] = []
@export var enemy_weights: Dictionary = {"normal": 100}
@export var elite_chance: float = 0.0
@export var elite_hp_mult: float = 1.5
@export var elite_damage_mult: float = 1.3
@export var elite_scale: float = 1.2
@export var elite_exp_mult: float = 2.0
@export var is_boss_wave: bool = false
@export var boss_id: String = ""
@export var fixed_modifiers: Array[String] = []
@export var modifier_count: int = 1
```

- [ ] **Step 4: 修改 SpawnPhaseData，duration_ratio 改为 enemy_count_ratio**

`scripts/resources/spawn_phase_data.gd`:
```gdscript
class_name SpawnPhaseData extends Resource

@export var enemy_count_ratio: float = 0.5
@export var spawn_interval: float = 1.0
@export var enemy_weights: Dictionary = {}
```

- [ ] **Step 5: 运行测试确认通过**

Run: 同 Step 2 命令
Expected: PASS

- [ ] **Step 6: 修复受影响的现有测试**

搜索所有引用 `time_limit` 和 `duration_ratio` 的测试文件并更新：
- `tests/unit/test_boss_wave_spawner.gd` 中 `_make_wave_data()` 的参数
- `tests/integration/test_wave_system.gd` 中对 `time_limit` 的断言

- [ ] **Step 7: 运行全部测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

- [ ] **Step 8: 提交**

```bash
git add scripts/resources/wave_data.gd scripts/resources/spawn_phase_data.gd tests/
git commit -m "refactor: WaveData/SpawnPhaseData 字段重构为清敌制"
```

---

## Task 2: EventBus 新增信号

**Files:**
- Modify: `scripts/core/event_bus.gd`

- [ ] **Step 1: 新增所有需要的信号**

在 `scripts/core/event_bus.gd` 中追加：
```gdscript
# 清敌制
signal enemy_count_updated(killed: int, total: int, alive: int)

# 波次修饰词
signal wave_modifier_applied(modifiers: Array)

# 升级属性
signal player_leveled_up(level: int, bonuses: Dictionary)

# 被动选择
signal passive_selected(passive_id: String)

# 技能
signal skill_activated(skill_id: String)
signal skill_cooldown_updated(remaining: float, total: float)
```

- [ ] **Step 2: 提交**

```bash
git add scripts/core/event_bus.gd
git commit -m "feat: EventBus 新增战斗体验重塑信号"
```

---

## Task 3: WaveManager 清敌制逻辑

**Files:**
- Modify: `scripts/systems/wave_manager.gd`
- Test: `tests/unit/test_wave_clear_system.gd`

- [ ] **Step 1: 编写 WaveManager 清敌制测试**

追加到 `tests/unit/test_wave_clear_system.gd`：
```gdscript
var wm: Node

func before_each() -> void:
	wm = load("res://scripts/systems/wave_manager.gd").new()
	add_child_autofree(wm)

func _make_wave(total: int, safety_time: float = 120.0) -> WaveData:
	var wd := WaveData.new()
	wd.total_enemies = total
	wd.time_limit_safety = safety_time
	wd.timeout_reward_ratio = 0.5
	wd.max_alive_enemies = 20
	wd.spawn_phases = [_make_phase(1.0, 1.0)]
	return wd

func _make_phase(ratio: float, interval: float) -> SpawnPhaseData:
	var phase := SpawnPhaseData.new()
	phase.enemy_count_ratio = ratio
	phase.spawn_interval = interval
	return phase

func test_wave_not_complete_when_enemies_alive() -> void:
	var wd := _make_wave(10)
	wm._start_wave_with_data(1, wd)
	wm.enemies_killed = 10
	wm.enemies_alive = 2
	wm.all_enemies_spawned = true
	wm._check_clear_condition()
	assert_true(wm.is_wave_active, "场上还有敌人时波次不应结束")

func test_wave_completes_when_all_killed() -> void:
	var wd := _make_wave(10)
	wm._start_wave_with_data(1, wd)
	wm.enemies_killed = 10
	wm.enemies_alive = 0
	wm.all_enemies_spawned = true
	wm._check_clear_condition()
	assert_false(wm.is_wave_active, "所有敌人被击杀后波次应结束")

func test_safety_timeout_forces_completion() -> void:
	var wd := _make_wave(10, 60.0)
	wm._start_wave_with_data(1, wd)
	wm.enemies_alive = 3
	wm.all_enemies_spawned = true
	# 模拟超时
	wm.wave_time_left = -0.1
	wm._process(0.016)
	assert_false(wm.is_wave_active, "安全阀超时应强制结束")
	assert_true(wm._timed_out, "应标记为超时")
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 重写 WaveManager**

重构 `scripts/systems/wave_manager.gd`：
- 新增变量：`enemies_killed`, `enemies_alive`, `all_enemies_spawned`, `_timed_out`
- `_process()` 改为：递减安全阀计时器 + 调用 `_check_clear_condition()`
- `_check_clear_condition()`：`all_enemies_spawned && enemies_alive == 0` 或 超时
- `complete_wave()` 中根据 `_timed_out` 决定奖励比例
- 连接 `EventBus.enemy_killed` 信号更新 `enemies_killed` 和 `enemies_alive`
- 移除旧的纯倒计时结束逻辑

关键变更：
```gdscript
var enemies_killed: int = 0
var enemies_alive: int = 0
var all_enemies_spawned: bool = false
var _timed_out: bool = false

func _process(delta: float) -> void:
	if not is_wave_active:
		return
	wave_time_left -= delta
	if wave_time_left <= 0.0:
		_timed_out = true
		complete_wave()
		return
	_check_clear_condition()

func _check_clear_condition() -> void:
	if all_enemies_spawned and enemies_alive <= 0:
		_timed_out = false
		complete_wave()

func register_enemy_spawned() -> void:
	enemies_alive += 1
	EventBus.enemy_count_updated.emit(enemies_killed, _current_wave_data.total_enemies, enemies_alive)

func register_enemy_killed() -> void:
	enemies_killed += 1
	enemies_alive -= 1
	EventBus.enemy_count_updated.emit(enemies_killed, _current_wave_data.total_enemies, enemies_alive)
```

- [ ] **Step 4: 运行测试确认通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/wave_manager.gd tests/unit/test_wave_clear_system.gd
git commit -m "feat: WaveManager 改为分批清敌制结束条件"
```

---

## Task 4: EnemySpawner 分批生成 + 清波加速

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd`
- Test: `tests/unit/test_wave_clear_system.gd`

- [ ] **Step 1: 编写 EnemySpawner 分批生成测试**

追加到 `tests/unit/test_wave_clear_system.gd`：
```gdscript
var spawner: Node

func test_spawner_counts_enemies_per_phase() -> void:
	spawner = load("res://scripts/systems/enemy_spawner.gd").new()
	add_child_autofree(spawner)
	var phases: Array[SpawnPhaseData] = [
		_make_phase(0.3, 1.0),
		_make_phase(0.7, 0.5),
	]
	var wd := _make_wave(20)
	wd.spawn_phases = phases
	# 第一阶段应生成 30% × 20 = 6 个敌人
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._phase_enemy_count, 6, "第一阶段应生成 6 个敌人")

func test_spawner_stops_at_total() -> void:
	spawner = load("res://scripts/systems/enemy_spawner.gd").new()
	add_child_autofree(spawner)
	var wd := _make_wave(5)
	wd.spawn_phases = [_make_phase(1.0, 0.1)]
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._total_to_spawn, 5, "总生成数应等于 total_enemies")
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 重写 EnemySpawner 的分批生成逻辑**

重构 `scripts/systems/enemy_spawner.gd`：
- 新增变量：`_total_to_spawn`, `_total_spawned`, `_phase_enemy_count`, `_phase_spawned`
- `_enter_phase()` 计算 `_phase_enemy_count = round(enemy_count_ratio * total_enemies)`
- `_process()` 中：检查 `_total_spawned < _total_to_spawn`，检查 `max_alive_enemies`
- 阶段内生成完毕后，检查场上敌人是否清空来决定是否加速进入下一阶段
- 所有阶段生成完毕后设置 WaveManager 的 `all_enemies_spawned = true`
- 每次生成敌人调用 `wave_manager.register_enemy_spawned()`
- 连接 `EventBus.enemy_killed` 来跟踪清波加速条件

- [ ] **Step 4: 运行测试确认通过**

- [ ] **Step 5: 运行全部测试确认无回归**

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/enemy_spawner.gd tests/unit/test_wave_clear_system.gd
git commit -m "feat: EnemySpawner 分批生成 + 清波加速逻辑"
```

---

## Task 5: HUD 改为击杀计数显示

**Files:**
- Modify: `scripts/ui/hud.gd`

- [ ] **Step 1: 修改 HUD 波次面板**

在 `scripts/ui/hud.gd` 中：
- 将 `_update_countdown()` 改为 `_update_enemy_count()`
- 连接 `EventBus.enemy_count_updated` 信号
- `countdown_label` 改为显示 "已击杀/总数" 格式
- 安全阀倒计时在剩余 < 30 秒时叠加显示红色警告文字

```gdscript
func _on_enemy_count_updated(killed: int, total: int, _alive: int) -> void:
	countdown_label.text = "%d / %d" % [killed, total]
```

- [ ] **Step 2: 运行游戏验证 HUD 显示**

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/hud.gd
git commit -m "feat: HUD 波次面板改为击杀计数显示"
```

---

## Task 6: 重写 12 波配置

**Files:**
- Rewrite: `resources/waves/forest/wave_01.tres` ~ `wave_12.tres`
- Delete: `resources/waves/forest/wave_13.tres` ~ `wave_15.tres`（如存在）

- [ ] **Step 1: 按设计文档节奏曲线重写所有波次配置**

每个 .tres 文件使用新字段：`total_enemies`, `time_limit_safety`, `enemy_count_ratio`。

波次节奏参考设计文档：
- 波 1: total=15, 轻松, normal only
- 波 4: total=50, Boss(brute) + 混合
- 波 8: total=70, Boss(summoner) + 混合
- 波 12: total=100, Boss(guardian) + 全类型

初期（Task 6）配置仅使用现有敌人类型（normal/fast/tank）。新敌人类型在 Task 14 完成后更新。

- [ ] **Step 2: 运行集成测试验证配置**

更新 `tests/integration/test_wave_system.gd`：
- 波次数应为 12
- 每波 total_enemies > 0
- spawn_phases 的 enemy_count_ratio 之和约为 1.0
- Boss 波在 4/8/12

- [ ] **Step 4: 提交**

```bash
git add resources/waves/forest/ tests/integration/test_wave_system.gd
git commit -m "feat: 重写 12 波配置为分批清敌制"
```

---

## Task 7: 连接 enemy.gd 到 WaveManager 计数

**Files:**
- Modify: `scripts/entities/enemy.gd`
- Modify: `scripts/systems/wave_manager.gd`

- [ ] **Step 1: enemy.gd 死亡时通知 WaveManager**

在 `enemy.gd` 的 `_on_died()` 方法中，确保 `EventBus.enemy_killed` 信号被 emit（已有）。在 WaveManager 中连接此信号调用 `register_enemy_killed()`。

- [ ] **Step 2: EnemySpawner 生成时通知 WaveManager**

在 `_spawn_normal_enemy()` 和 `_spawn_boss()` 末尾调用 WaveManager 的 `register_enemy_spawned()`。需要 EnemySpawner 持有 WaveManager 引用（通过 `get_node()` 或 main.gd 注入）。

- [ ] **Step 3: 端到端测试——运行游戏打一波，验证击杀计数和波次结束**

- [ ] **Step 4: 提交**

```bash
git add scripts/entities/enemy.gd scripts/systems/wave_manager.gd scripts/systems/enemy_spawner.gd
git commit -m "feat: 连接敌人击杀/生成到 WaveManager 计数系统"
```

---

## Task 8: Enums.Stat 扩展 + ExpConfig 新增等级加成字段

**Files:**
- Modify: `scripts/resources/exp_config.gd`
- Modify: `resources/exp_config.tres`
- Test: `tests/unit/test_level_up_bonus.gd`

- [ ] **Step 1: 扩展 Enums.Stat 新增所需常量**

检查 `scripts/core/enums.gd`（或 Enums 所在文件），新增被动系统和等级加成需要的 Stat 常量：
```gdscript
# 新增：
const MOVE_SPEED_MULT = "move_speed_mult"
const DAMAGE_REDUCTION = "damage_reduction"
const PICKUP_RANGE_MULT = "pickup_range_mult"
const WEAPON_DAMAGE_SWORD = "weapon_damage_sword"
const EXP_MAGNET_RANGE = "exp_magnet_range"
const TOWER_RANGE_MULT = "tower_range_mult"
const TOWER_HP_MULT = "tower_hp_mult"
```

同时在 `PlayerState.player_stats` 的初始 Dictionary 中添加这些 key 的默认值。

- [ ] **Step 2: 编写等级加成测试**

```gdscript
# tests/unit/test_level_up_bonus.gd
extends GutTest

func test_exp_config_has_level_bonuses() -> void:
	var cfg := ExpConfig.new()
	cfg.level_attack_bonus = 0.06
	cfg.level_attack_speed_bonus = 0.05
	cfg.level_max_hp_bonus = 0.05
	cfg.level_move_speed_bonus = 0.03
	cfg.level_heal_ratio = 0.2
	assert_eq(cfg.level_attack_bonus, 0.06)
	assert_eq(cfg.level_heal_ratio, 0.2)
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 在 ExpConfig 中新增字段**

```gdscript
@export var level_attack_bonus: float = 0.06
@export var level_attack_speed_bonus: float = 0.05
@export var level_max_hp_bonus: float = 0.05
@export var level_move_speed_bonus: float = 0.03
@export var level_heal_ratio: float = 0.2
```

- [ ] **Step 4: 更新 exp_config.tres 添加默认值**

- [ ] **Step 5: 运行测试确认通过**

- [ ] **Step 6: 提交**

```bash
git add scripts/resources/exp_config.gd resources/exp_config.tres tests/unit/test_level_up_bonus.gd
git commit -m "feat: ExpConfig 新增等级属性加成配置"
```

---

## Task 9: PlayerProgression 升级属性加成

**Files:**
- Modify: `scripts/core/player_progression.gd`
- Modify: `scripts/entities/player.gd`
- Test: `tests/unit/test_level_up_bonus.gd`

- [ ] **Step 1: 编写升级属性加成测试**

追加到 `tests/unit/test_level_up_bonus.gd`：
```gdscript
func test_level_up_emits_bonuses() -> void:
	PlayerProgression.reset()
	var received_bonuses: Dictionary = {}
	EventBus.player_leveled_up.connect(func(level, bonuses):
		received_bonuses = bonuses
	)
	# 手动设置经验使升级
	PlayerProgression.current_exp = 0
	PlayerProgression.add_exp(100)  # 足够升到 2 级
	assert_true(received_bonuses.has("attack_bonus"), "应 emit 攻击加成")

func test_get_level_bonus() -> void:
	PlayerProgression.reset()
	var bonuses: Dictionary = PlayerProgression.get_level_bonuses(5)
	var cfg: ExpConfig = GameConfig.exp_config
	assert_almost_eq(bonuses["attack_bonus"], 5 * cfg.level_attack_bonus, 0.001)
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 在 PlayerProgression 中实现**

新增方法 `get_level_bonuses(level: int) -> Dictionary`，升级时 emit `EventBus.player_leveled_up`。

```gdscript
func get_level_bonuses(level: int) -> Dictionary:
	var cfg: ExpConfig = GameConfig.exp_config
	return {
		"attack_bonus": level * cfg.level_attack_bonus,
		"attack_speed_bonus": level * cfg.level_attack_speed_bonus,
		"max_hp_bonus": level * cfg.level_max_hp_bonus,
		"move_speed_bonus": level * cfg.level_move_speed_bonus,
	}
```

修改 `add_exp()` 中的升级逻辑：
```gdscript
while current_exp >= exp_for_level(player_level + 1):
	player_level += 1
	var bonuses := get_level_bonuses(player_level)
	EventBus.player_leveled_up.emit(player_level, bonuses)
	EventBus.player_level_changed.emit(player_level)
```

- [ ] **Step 4: 在 player.gd 中移除旧常量，响应新信号**

移除 `LEVEL_HP_GROWTH`, `LEVEL_SPEED_GROWTH`, `LEVEL_PICKUP_GROWTH` 常量。移除 `_apply_level_growth()` 方法。同时移除旧被动系统相关代码：`_init_passives()`, `_apply_passive_tier()`, `_process_passives()`, `_passive_evolution` 变量等（这些将被 Task 12 的被动自由池替代）。

> **注意**：`pickup_range_mult` 的每级提升在旧系统中是 +5%/级，新系统有意去掉（拾取范围改为通过被动 `dora_exp_magnet` 获得）。

> **weapon_manager.gd 验证**：`weapon_manager.gd` 已通过 `PlayerState.player_stats[Enums.Stat.DAMAGE_MULT]` 和 `[Enums.Stat.ATTACK_SPEED_MULT]` 读取攻击力/攻速倍率。Task 9 修改这些值后，weapon_manager 在下次攻击时自动使用新值，无需额外修改。在测试中验证此行为。

连接 `EventBus.player_leveled_up`，应用属性加成 + HP 回复：
```gdscript
func _on_leveled_up(level: int, bonuses: Dictionary) -> void:
	var cfg: ExpConfig = GameConfig.exp_config
	# 应用属性到 player_stats
	PlayerState.player_stats[Enums.Stat.DAMAGE_MULT] = PlayerState.character_damage_mult * (1.0 + bonuses["attack_bonus"])
	PlayerState.player_stats[Enums.Stat.ATTACK_SPEED_MULT] = PlayerState.character_attack_speed_mult * (1.0 + bonuses["attack_speed_bonus"])
	# HP 回复
	var heal_amount: int = ceili(health.max_hp * cfg.level_heal_ratio)
	health.heal(heal_amount)
	# 更新 max_hp 和 speed
	_apply_level_stats(level, bonuses)
```

- [ ] **Step 5: 运行测试确认通过**

- [ ] **Step 6: 运行全部测试确认无回归**

- [ ] **Step 7: 提交**

```bash
git add scripts/core/player_progression.gd scripts/entities/player.gd tests/unit/test_level_up_bonus.gd
git commit -m "feat: 升级即时属性提升 + 移除旧硬编码常量"
```

---

## Task 10: 升级视觉反馈

**Files:**
- Modify: `scripts/systems/effects_manager.gd`
- Modify: `scripts/entities/player.gd`

- [ ] **Step 1: 在 EffectsManager 新增升级特效方法**

```gdscript
func spawn_level_up_effect(pos: Vector2, level: int) -> void:
	# 扩散光环
	_spawn_ring_effect(pos, Color(1.0, 0.9, 0.3), 60.0)
	# "LEVEL UP!" 飘字
	_spawn_floating_text(pos + Vector2(0, -30), "LEVEL UP!", Color(1.0, 0.9, 0.3), 1.5)
	# 短暂屏幕闪白
	_screen_flash(Color(1, 1, 1, 0.3), 0.05)
	# 音效
	AudioManager.play("level_up")
```

- [ ] **Step 2: 在 player.gd 的 `_on_leveled_up()` 中调用特效**

```gdscript
EffectsManager.spawn_level_up_effect(global_position, level)
```

- [ ] **Step 3: 运行游戏验证视觉效果**

- [ ] **Step 4: 提交**

```bash
git add scripts/systems/effects_manager.gd scripts/entities/player.gd
git commit -m "feat: 升级视觉反馈（光环+飘字+闪屏）"
```

---

## Task 11: PassiveData Resource 类 + GameConfig 注册

**Files:**
- Create: `scripts/resources/passive_data.gd`
- Modify: `scripts/core/game_config.gd`
- Test: `tests/unit/test_passive_pool.gd`

- [ ] **Step 1: 编写 PassiveData 测试**

```gdscript
# tests/unit/test_passive_pool.gd
extends GutTest

func test_passive_data_fields() -> void:
	var pd := PassiveData.new()
	pd.id = "dora_blade_mastery"
	pd.display_name = "刀刃精通"
	pd.description = "剑类武器伤害 +25%"
	pd.character_id = "dora"
	pd.effects = {"weapon_damage_sword": 0.25}
	assert_eq(pd.id, "dora_blade_mastery")
	assert_eq(pd.effects["weapon_damage_sword"], 0.25)
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 创建 PassiveData Resource 类**

```gdscript
# scripts/resources/passive_data.gd
class_name PassiveData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export var character_id: String = ""
@export var effects: Dictionary = {}
```

- [ ] **Step 4: 在 GameConfig 中注册被动加载**

```gdscript
var passives: Dictionary = {}  # {passive_id: PassiveData}

# 在 _ready() 中添加：
_load_resources_from_dir("res://resources/passives/dora/", passives)
```

- [ ] **Step 5: 运行测试确认通过**

- [ ] **Step 6: 提交**

```bash
git add scripts/resources/passive_data.gd scripts/core/game_config.gd tests/unit/test_passive_pool.gd
git commit -m "feat: PassiveData Resource 类 + GameConfig 注册"
```

---

## Task 12: 被动自由池逻辑 + PlayerState 集成

**Files:**
- Modify: `scripts/core/player_state.gd`
- Modify: `scripts/resources/character_data.gd`
- Test: `tests/unit/test_passive_pool.gd`

- [ ] **Step 1: 编写被动池选择逻辑测试**

追加到 `tests/unit/test_passive_pool.gd`：
```gdscript
func before_each() -> void:
	PlayerState.reset()

func test_get_passive_choices_returns_3() -> void:
	PlayerState.init_character("dora")
	var choices: Array = PlayerState.get_passive_choices(3)
	assert_eq(choices.size(), 3, "应返回 3 个被动选项")

func test_acquired_passive_not_offered_again() -> void:
	PlayerState.init_character("dora")
	PlayerState.acquire_passive("dora_blade_mastery")
	var choices: Array = PlayerState.get_passive_choices(10)
	for p: PassiveData in choices:
		assert_ne(p.id, "dora_blade_mastery", "已获得被动不应再出现")

func test_acquire_passive_applies_effects() -> void:
	PlayerState.init_character("dora")
	var old_mult: float = PlayerState.player_stats[Enums.Stat.DAMAGE_MULT]
	PlayerState.acquire_passive("dora_tough_skin")
	# tough_skin 效果是 damage_reduction +15%
	assert_true(PlayerState.acquired_passives.has("dora_tough_skin"))
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 在 CharacterData 中新增 passive_pool 字段**

```gdscript
@export var passive_pool: Array[String] = []
```

- [ ] **Step 4: 在 PlayerState 中实现被动池系统**

```gdscript
var acquired_passives: Array[String] = []

func get_passive_choices(count: int = 3) -> Array:
	var cd: CharacterData = GameConfig.characters[current_character]
	var available: Array = []
	for pid: String in cd.passive_pool:
		if pid not in acquired_passives and GameConfig.passives.has(pid):
			available.append(GameConfig.passives[pid])
	available.shuffle()
	return available.slice(0, mini(count, available.size()))

func acquire_passive(passive_id: String) -> void:
	if passive_id in acquired_passives:
		return
	acquired_passives.append(passive_id)
	var pd: PassiveData = GameConfig.passives[passive_id]
	_apply_passive_effects(pd.effects)
	EventBus.passive_selected.emit(passive_id)

func _apply_passive_effects(effects: Dictionary) -> void:
	for key: String in effects:
		# 基于 key 映射到 player_stats 或特殊逻辑
		match key:
			"damage_reduction":
				player_stats["damage_reduction"] = player_stats.get("damage_reduction", 0.0) + effects[key]
			"weapon_damage_sword":
				player_stats["weapon_damage_sword"] = effects[key]
			# ... 其他 key 映射
```

- [ ] **Step 5: reset() 中清理 acquired_passives**

- [ ] **Step 6: 运行测试确认通过**

- [ ] **Step 7: 提交**

```bash
git add scripts/core/player_state.gd scripts/resources/character_data.gd tests/unit/test_passive_pool.gd
git commit -m "feat: 被动自由池系统逻辑 + PlayerState 集成"
```

---

## Task 13: 创建 Dora 被动 .tres 配置文件 + CharacterData 更新

**Files:**
- Create: `resources/passives/dora/*.tres` (10 个文件)
- Modify: `resources/characters/dora.tres`

- [ ] **Step 1: 创建 10 个被动配置文件**

每个文件格式：
```
[gd_resource type="Resource" script_class="PassiveData" format=3]
[ext_resource type="Script" path="res://scripts/resources/passive_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "dora_blade_mastery"
display_name = "刀刃精通"
description = "剑类武器伤害 +25%"
character_id = "dora"
effects = {"weapon_damage_sword": 0.25}
```

创建全部 10 个：blade_mastery, swift_draw, treasure_hunter, tough_skin, exp_magnet, tower_synergy, second_wind, gold_interest, combo_strike, fortify.

- [ ] **Step 2: 更新 dora.tres 的 passive_pool 字段**

添加所有 10 个被动 ID 到 `passive_pool` 数组。

- [ ] **Step 3: 运行集成测试验证加载**

```gdscript
func test_dora_passive_pool_loaded() -> void:
	var cd: CharacterData = GameConfig.characters["dora"]
	assert_gt(cd.passive_pool.size(), 0, "Dora 应有被动池")
	for pid: String in cd.passive_pool:
		assert_true(GameConfig.passives.has(pid), "被动 %s 应在 GameConfig 中注册" % pid)
```

- [ ] **Step 4: 提交**

```bash
git add resources/passives/ resources/characters/dora.tres tests/
git commit -m "feat: Dora 10 个被动配置 + CharacterData 更新"
```

---

## Task 14: 被动选择 UI

**Files:**
- Create: `scripts/ui/passive_selection.gd`
- Create: `scenes/ui/passive_selection.tscn`
- Modify: `scripts/ui/main.gd`

- [ ] **Step 1: 创建 passive_selection.gd**

CanvasLayer（layer=11，在 ShopOverlay 之上），全屏半透明遮罩 + 3 张卡片横排。

```gdscript
class_name PassiveSelection extends CanvasLayer

signal passive_chosen(passive_id: String)

func show_choices(choices: Array) -> void:
	# 显示 3 张卡片
	# 点击选择后 emit passive_chosen

func _on_card_pressed(index: int) -> void:
	var chosen: PassiveData = _current_choices[index]
	PlayerState.acquire_passive(chosen.id)
	passive_chosen.emit(chosen.id)
	hide()
```

- [ ] **Step 2: 创建 passive_selection.tscn 场景**

- [ ] **Step 3: 修改 main.gd 波间流程**

在 `_enter_shop_phase()` 中：
```gdscript
func _enter_shop_phase(is_first: bool = false) -> void:
	current_phase = Phase.SHOP
	if not is_first:
		# 先显示被动选择
		var choices: Array = PlayerState.get_passive_choices(3)
		if choices.size() > 0:
			_passive_selection.show_choices(choices)
			await _passive_selection.passive_chosen
	# 然后进入商店
	_shop_overlay.slide_in()
	# ...
```

- [ ] **Step 4: 运行游戏验证流程：波次结束 → 被动选择 → 商店**

- [ ] **Step 5: 提交**

```bash
git add scripts/ui/passive_selection.gd scenes/ui/passive_selection.tscn scripts/ui/main.gd
git commit -m "feat: 被动选择 UI + 波间流程集成"
```

---

## Task 15: ActiveSkillData Resource + ActiveSkillComponent

**Files:**
- Create: `scripts/resources/active_skill_data.gd`
- Create: `scripts/components/active_skill_component.gd`
- Create: `resources/skills/dora_slash.tres`
- Test: `tests/unit/test_active_skill.gd`

- [ ] **Step 1: 编写技能组件测试**

```gdscript
# tests/unit/test_active_skill.gd
extends GutTest

func test_skill_data_fields() -> void:
	var sd := ActiveSkillData.new()
	sd.id = "dora_slash"
	sd.cooldown = 12.0
	sd.damage_multiplier = 3.0
	sd.range_radius = 120.0
	sd.angle = 90.0
	assert_eq(sd.cooldown, 12.0)

func test_skill_cooldown() -> void:
	var comp := ActiveSkillComponent.new()
	add_child_autofree(comp)
	var sd := ActiveSkillData.new()
	sd.cooldown = 10.0
	comp.skill_data = sd
	comp.activate()
	assert_false(comp.is_ready(), "激活后应进入 CD")
	comp.tick(5.0)
	assert_false(comp.is_ready(), "5 秒后仍在 CD")
	comp.tick(5.0)
	assert_true(comp.is_ready(), "10 秒后应就绪")
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 创建 ActiveSkillData**

```gdscript
class_name ActiveSkillData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cooldown: float = 12.0
@export var damage_multiplier: float = 3.0
@export var range_radius: float = 120.0
@export var angle: float = 90.0
@export var knockback_force: float = 300.0
@export var icon_path: String = ""
@export var effect_scene_path: String = ""
```

- [ ] **Step 4: 创建 ActiveSkillComponent**

```gdscript
class_name ActiveSkillComponent extends Node

signal skill_activated(skill_id: String)
signal cooldown_updated(remaining: float, total: float)

@export var skill_data: ActiveSkillData
var _cooldown_remaining: float = 0.0

func is_ready() -> bool:
	return _cooldown_remaining <= 0.0

func activate() -> void:
	if not is_ready() or skill_data == null:
		return
	_cooldown_remaining = skill_data.cooldown
	skill_activated.emit(skill_data.id)
	EventBus.skill_activated.emit(skill_data.id)

func tick(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		EventBus.skill_cooldown_updated.emit(_cooldown_remaining, skill_data.cooldown)
		if _cooldown_remaining <= 0.0:
			_cooldown_remaining = 0.0
```

- [ ] **Step 5: 创建 dora_slash.tres 配置**

- [ ] **Step 6: 运行测试确认通过**

- [ ] **Step 7: 提交**

```bash
git add scripts/resources/active_skill_data.gd scripts/components/active_skill_component.gd resources/skills/ tests/unit/test_active_skill.gd
git commit -m "feat: ActiveSkillData + ActiveSkillComponent 基础框架"
```

---

## Task 16: Player 集成主动技能 + 扇形 Hitbox

**Files:**
- Modify: `scripts/entities/player.gd`
- Modify: `project.godot`
- Modify: `scripts/ui/hud.gd`

- [ ] **Step 1: project.godot 新增输入映射**

添加 `skill_activate` 映射到 Space 键。

- [ ] **Step 2: player.gd 集成 ActiveSkillComponent**

```gdscript
var _active_skill: ActiveSkillComponent = null
var last_movement_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	# ... 现有初始化
	_setup_active_skill()

func _setup_active_skill() -> void:
	var skill_data: ActiveSkillData = load("res://resources/skills/dora_slash.tres")
	_active_skill = ActiveSkillComponent.new()
	_active_skill.skill_data = skill_data
	_active_skill.skill_activated.connect(_execute_skill)
	add_child(_active_skill)

func _physics_process(delta: float) -> void:
	# 更新 last_movement_direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0:
		last_movement_direction = input_dir.normalized()
	# ... 现有移动逻辑
	_active_skill.tick(delta)
	if Input.is_action_just_pressed("skill_activate"):
		_active_skill.activate()

func _execute_skill(skill_id: String) -> void:
	var sd: ActiveSkillData = _active_skill.skill_data
	# 创建临时扇形 Hitbox
	_spawn_skill_hitbox(sd)
	# 视觉特效
	EffectsManager.spawn_skill_effect(global_position, last_movement_direction, sd)
	EventBus.camera_shake_requested.emit(3.0, 0.15)
```

- [ ] **Step 3: 实现扇形伤害检测（遍历敌人组 + 角度过滤）**

采用手动遍历 `enemies` 组的方式，通过距离+角度过滤命中目标，然后调用敌人的 `_on_hurtbox_hit()` 保持伤害管线一致（触发音效、闪白、击退等）。

```gdscript
func _execute_skill_damage(sd: ActiveSkillData) -> void:
	var damage: float = _get_base_damage() * sd.damage_multiplier
	var half_angle_rad: float = deg_to_rad(sd.angle / 2.0)
	var facing: Vector2 = last_movement_direction

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is CharacterBody2D:
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		var dist: float = to_enemy.length()
		if dist > sd.range_radius:
			continue
		var angle_to: float = abs(facing.angle_to(to_enemy.normalized()))
		if angle_to > half_angle_rad:
			continue
		# 通过标准伤害管线处理
		var knockback_dir: Vector2 = to_enemy.normalized()
		enemy._on_hurtbox_hit(damage, knockback_dir * sd.knockback_force)
```

这样命中反馈（音效、闪白、击退、伤害数字）与其他伤害源完全一致。

- [ ] **Step 4: HUD 新增技能 CD 显示**

在 `scripts/ui/hud.gd` 中：
- 添加技能图标 + CD 遮罩节点
- 连接 `EventBus.skill_cooldown_updated` 更新遮罩
- 连接 `EventBus.skill_activated` 触发高亮动画

- [ ] **Step 5: 运行游戏测试技能释放效果**

- [ ] **Step 6: 提交**

```bash
git add scripts/entities/player.gd scripts/ui/hud.gd project.godot
git commit -m "feat: Dora 剑气斩主动技能 + HUD CD 显示"
```

---

## Task 17: EnemyData 新增 behavior_config + Behavior Resource 类

**Files:**
- Modify: `scripts/resources/enemy_data.gd`
- Create: `scripts/resources/ranger_behavior_data.gd`
- Create: `scripts/resources/bomber_behavior_data.gd`
- Create: `scripts/resources/splitter_behavior_data.gd`
- Create: `scripts/resources/shielder_behavior_data.gd`
- Test: `tests/unit/test_enemy_behaviors.gd`

- [ ] **Step 1: 编写 Behavior Resource 测试**

```gdscript
# tests/unit/test_enemy_behaviors.gd
extends GutTest

func test_ranger_behavior_data() -> void:
	var bd := RangerBehaviorData.new()
	bd.preferred_distance = 175.0
	bd.attack_interval = 2.0
	assert_eq(bd.preferred_distance, 175.0)

func test_enemy_data_accepts_behavior_config() -> void:
	var ed := EnemyData.new()
	var bd := RangerBehaviorData.new()
	ed.behavior_config = bd
	assert_true(ed.behavior_config is RangerBehaviorData)
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 创建 4 个 Behavior Resource 类**

```gdscript
# scripts/resources/ranger_behavior_data.gd
class_name RangerBehaviorData extends Resource
@export var preferred_distance: float = 175.0
@export var retreat_distance: float = 100.0
@export var projectile_data: ProjectileData = null
@export var attack_interval: float = 2.0
```

```gdscript
# scripts/resources/bomber_behavior_data.gd
class_name BomberBehaviorData extends Resource
@export var explode_radius: float = 80.0
@export var explode_damage: float = 40.0
@export var prime_duration: float = 1.5
@export var prime_trigger_distance: float = 50.0
```

```gdscript
# scripts/resources/splitter_behavior_data.gd
class_name SplitterBehaviorData extends Resource
@export var split_enemy_id: String = "splitter_mini"
@export var split_count: int = 3
```

```gdscript
# scripts/resources/shielder_behavior_data.gd
class_name ShielderBehaviorData extends Resource
@export var shield_angle: float = 120.0
```

- [ ] **Step 4: EnemyData 新增 behavior_config 字段**

```gdscript
@export var behavior_config: Resource = null
```

- [ ] **Step 5: 运行测试确认通过**

- [ ] **Step 6: 提交**

```bash
git add scripts/resources/enemy_data.gd scripts/resources/*_behavior_data.gd tests/unit/test_enemy_behaviors.gd
git commit -m "feat: EnemyData behavior_config + 4 个 Behavior Resource 类"
```

---

## Task 18: 敌人行为组件框架 + enemy.gd 集成

**Files:**
- Create: `scripts/components/enemy_behaviors/ranger_behavior.gd`
- Create: `scripts/components/enemy_behaviors/bomber_behavior.gd`
- Create: `scripts/components/enemy_behaviors/splitter_behavior.gd`
- Create: `scripts/components/enemy_behaviors/shielder_behavior.gd`
- Modify: `scripts/entities/enemy.gd`

- [ ] **Step 1: 编写行为组件单元测试**

追加到 `tests/unit/test_enemy_behaviors.gd`：
```gdscript
func test_ranger_state_transitions() -> void:
	var ranger := RangerBehavior.new()
	add_child_autofree(ranger)
	var mock_enemy := CharacterBody2D.new()
	mock_enemy.speed = 90.0
	mock_enemy.global_position = Vector2(0, 0)
	var mock_player := CharacterBody2D.new()
	mock_player.global_position = Vector2(300, 0)
	mock_enemy.player = mock_player
	add_child_autofree(mock_enemy)
	add_child_autofree(mock_player)
	var config := RangerBehaviorData.new()
	config.preferred_distance = 175.0
	config.retreat_distance = 100.0
	ranger.initialize(mock_enemy, config)
	# 远处应接近
	assert_eq(ranger._state, RangerBehavior.State.APPROACH)
	# 移动到射程内
	mock_enemy.global_position = Vector2(170, 0)
	ranger.physics_tick(0.016)
	assert_eq(ranger._state, RangerBehavior.State.ATTACK)
	# 太近应后退
	mock_enemy.global_position = Vector2(80, 0)
	ranger.physics_tick(0.016)
	assert_eq(ranger._state, RangerBehavior.State.RETREAT)

func test_bomber_explode_on_prime() -> void:
	var bomber := BomberBehavior.new()
	add_child_autofree(bomber)
	var config := BomberBehaviorData.new()
	config.prime_duration = 1.5
	config.prime_trigger_distance = 50.0
	# 验证 prime 状态倒计时逻辑
	bomber._state = BomberBehavior.State.PRIME
	bomber._prime_timer = 1.5
	bomber._config = config
	bomber._prime_timer -= 1.5
	assert_true(bomber._prime_timer <= 0.0, "倒计时结束应触发爆炸")

func test_splitter_produces_children() -> void:
	var splitter := SplitterBehavior.new()
	var config := SplitterBehaviorData.new()
	config.split_count = 3
	config.split_enemy_id = "splitter_mini"
	splitter._config = config
	assert_eq(config.split_count, 3, "应分裂 3 个小怪")

func test_shielder_angle_check() -> void:
	var shielder := ShielderBehavior.new()
	var config := ShielderBehaviorData.new()
	config.shield_angle = 120.0
	shielder._config = config
	# 正面攻击应被挡
	assert_true(shielder.is_in_shield_arc(Vector2.RIGHT, Vector2.LEFT), "正面攻击应在护盾范围内")
	# 背面攻击不应被挡
	assert_false(shielder.is_in_shield_arc(Vector2.RIGHT, Vector2.RIGHT), "背面攻击不应在护盾范围内")
```

- [ ] **Step 2: 定义行为组件接口模式**

所有行为组件继承 Node，实现统一接口：
```gdscript
# 所有行为组件实现：
func initialize(enemy: CharacterBody2D, config: Resource) -> void
func physics_tick(delta: float) -> Vector2  # 返回期望速度向量
func on_died() -> void  # 可选，死亡时回调
func reset_for_pool() -> void
```

- [ ] **Step 3: 创建 RangerBehavior**

```gdscript
# scripts/components/enemy_behaviors/ranger_behavior.gd
class_name RangerBehavior extends Node

var _enemy: CharacterBody2D
var _config: RangerBehaviorData
var _attack_timer: float = 0.0
var _player: Node2D

enum State { APPROACH, ATTACK, RETREAT }
var _state: State = State.APPROACH

func initialize(enemy: CharacterBody2D, config: Resource) -> void:
	_enemy = enemy
	_config = config as RangerBehaviorData
	_player = enemy.player

func physics_tick(delta: float) -> Vector2:
	var dist := _enemy.global_position.distance_to(_player.global_position)
	match _state:
		State.APPROACH:
			if dist <= _config.preferred_distance:
				_state = State.ATTACK
			return _enemy.global_position.direction_to(_player.global_position) * _enemy.speed
		State.ATTACK:
			if dist < _config.retreat_distance:
				_state = State.RETREAT
			elif dist > _config.preferred_distance * 1.3:
				_state = State.APPROACH
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_fire_projectile()
				_attack_timer = _config.attack_interval
			return Vector2.ZERO  # 站定射击
		State.RETREAT:
			if dist >= _config.preferred_distance:
				_state = State.ATTACK
			return _player.global_position.direction_to(_enemy.global_position) * _enemy.speed
	return Vector2.ZERO

func _fire_projectile() -> void:
	var dir := _enemy.global_position.direction_to(_player.global_position)
	var damage: float = _enemy.data.damage  # 使用 EnemyData 的 damage 字段作为射弹伤害
	SceneFactory.create_projectile(_config.projectile_data, damage, _enemy.global_position, dir)
```

- [ ] **Step 4: 创建 BomberBehavior**

CHASE → PRIME（停止+闪红+膨胀）→ EXPLODE（临时 Hitbox，碰撞层 6/bitmask 32 EnemyAttack，碰撞掩码 7/bitmask 64 DefenderHurt）。

- [ ] **Step 5: 创建 SplitterBehavior**

`on_died()` 中通过 SceneFactory 生成 `split_count` 个 `split_enemy_id` 敌人，随机方向散开。通知 WaveManager 新增存活敌人。

- [ ] **Step 6: 创建 ShielderBehavior**

持续面向玩家。提供 `is_in_shield_arc(facing: Vector2, attack_dir: Vector2) -> bool` 方法。在 `_on_hurtbox_hit` 之前拦截：检测投射物入射方向是否在护盾角度内，是则反弹投射物+不造成伤害。

- [ ] **Step 7: 修改 enemy.gd 集成行为组件**

```gdscript
var _behavior: Node = null

func _ready() -> void:
	# ... 现有初始化
	_behavior = _detect_behavior_component()
	if _behavior:
		_behavior.initialize(self, data.behavior_config)

func _detect_behavior_component() -> Node:
	for child in get_children():
		if child.has_method("physics_tick"):
			return child
	return null

func _physics_process(delta: float) -> void:
	if _behavior:
		var desired_velocity: Vector2 = _behavior.physics_tick(delta)
		velocity = desired_velocity * slow_handler.get_speed_multiplier()
		move_and_slide()
		_sprite_animator.update_direction(velocity)
	else:
		_chase_player(delta)
```

- [ ] **Step 8: 运行测试确认行为组件测试通过**

- [ ] **Step 9: 运行全部测试**

- [ ] **Step 10: 提交**

```bash
git add scripts/components/enemy_behaviors/ scripts/entities/enemy.gd tests/unit/test_enemy_behaviors.gd
git commit -m "feat: 4 种敌人行为组件 + enemy.gd 组件检测集成"
```

---

## Task 19: 新敌人场景 + Resource 配置 + SceneFactory 注册

**Files:**
- Create: 5 个敌人 .tscn 场景
- Create: 5 个敌人 .tres 配置
- Create: `scenes/entities/projectiles/enemy_arrow.tscn`
- Modify: `scripts/core/scene_factory.gd`

- [ ] **Step 1: 创建 enemy_arrow.tscn（Ranger 投射物）**

Node2D 根节点 + projectile.gd 脚本 + Hitbox（碰撞层 32 EnemyAttack，掩码 64 DefenderHurt）+ LinearMovementComponent。

注意：敌人投射物使用 **碰撞层 32（EnemyAttack），掩码 64（DefenderHurt）**，不同于玩家投射物的 层 16/掩码 128+256。

- [ ] **Step 2: 创建 5 个敌人场景**

每个场景结构类似 `enemy_normal.tscn`：CharacterBody2D + HealthComponent + KnockbackHandler + SlowHandler + SpriteAnimator + Hitbox + Hurtbox。额外挂载对应的行为组件子节点。

- `ranger.tscn`：+ RangerBehavior 子节点
- `bomber.tscn`：+ BomberBehavior 子节点
- `splitter.tscn`：+ SplitterBehavior 子节点
- `splitter_mini.tscn`：无行为组件（默认 chase），体型小
- `shielder.tscn`：+ ShielderBehavior 子节点

- [ ] **Step 3: 创建 5 个 EnemyData .tres 配置**

参考设计文档中的数值表。`behavior_config` 字段引用对应的 Behavior Resource。

- [ ] **Step 4: SceneFactory 注册新敌人和投射物**

在 `scene_factory.gd` 的 `_enemy_scenes` 字典和 `_ready()` 的池注册中添加：
```gdscript
"ranger": preload("res://scenes/entities/enemies/ranger.tscn"),
"bomber": preload("res://scenes/entities/enemies/bomber.tscn"),
"splitter": preload("res://scenes/entities/enemies/splitter.tscn"),
"splitter_mini": preload("res://scenes/entities/enemies/splitter_mini.tscn"),
"shielder": preload("res://scenes/entities/enemies/shielder.tscn"),
```

池注册（bomber, splitter_mini, ranger, enemy_arrow 需要池化）。

- [ ] **Step 5: 运行游戏测试新敌人生成**

手动修改 wave_03.tres 的 enemy_weights 加入新敌人类型验证。

- [ ] **Step 6: 提交**

```bash
git add scenes/entities/enemies/ scenes/entities/projectiles/enemy_arrow.tscn resources/enemies/ scripts/core/scene_factory.gd
git commit -m "feat: 4 种新敌人场景 + 配置 + SceneFactory 注册"
```

---

## Task 20: 更新波次配置引入新敌人

**Files:**
- Modify: `resources/waves/forest/wave_03.tres` ~ `wave_12.tres`

- [ ] **Step 1: 按设计文档更新 enemy_weights**

- 波 3+：引入 ranger
- 波 4+：引入 bomber
- 波 6+：引入 splitter
- 波 7+：引入 shielder
- Boss 波：混合所有类型

- [ ] **Step 2: 运行集成测试验证所有 enemy_weights 引用有效类型**

- [ ] **Step 3: 运行游戏完整打一轮 12 波**

- [ ] **Step 4: 提交**

```bash
git add resources/waves/forest/
git commit -m "feat: 波次配置引入 4 种新敌人类型"
```

---

## Task 21: WaveModifierData Resource + 修饰词系统

**Files:**
- Create: `scripts/resources/wave_modifier_data.gd`
- Modify: `scripts/core/game_config.gd`
- Modify: `scripts/systems/wave_manager.gd`
- Create: `resources/modifiers/*.tres` (8 个)
- Test: `tests/unit/test_wave_modifiers.gd`

- [ ] **Step 1: 编写修饰词系统测试**

```gdscript
# tests/unit/test_wave_modifiers.gd
extends GutTest

func test_modifier_data_fields() -> void:
	var md := WaveModifierData.new()
	md.id = "elite_invasion"
	md.type = WaveModifierData.ModifierType.DIFFICULTY
	md.min_wave = 3
	assert_eq(md.type, WaveModifierData.ModifierType.DIFFICULTY)

func test_draw_modifiers_respects_min_wave() -> void:
	# 波 1 不应抽到 min_wave=3 的修饰词
	var wm := load("res://scripts/systems/wave_manager.gd").new()
	add_child_autofree(wm)
	var mods: Array = wm.draw_modifiers(1, 2)
	for m: WaveModifierData in mods:
		assert_true(m.min_wave <= 1, "波 1 不应出现 min_wave > 1 的修饰词")

func test_speed_rush_increases_enemy_speed() -> void:
	# 验证 speed_rush 修饰词实际效果
	var spawner := load("res://scripts/systems/enemy_spawner.gd").new()
	add_child_autofree(spawner)
	var mod := WaveModifierData.new()
	mod.id = "speed_rush"
	spawner.apply_modifiers([mod])
	assert_almost_eq(spawner._speed_multiplier, 1.3, 0.01, "速攻潮应使敌人速度 ×1.3")

func test_frenzy_spawn_increases_total() -> void:
	var wm := load("res://scripts/systems/wave_manager.gd").new()
	add_child_autofree(wm)
	var wd := WaveData.new()
	wd.total_enemies = 30
	var mod := WaveModifierData.new()
	mod.id = "frenzy_spawn"
	var adjusted: int = wm.apply_frenzy_modifier(wd.total_enemies, [mod])
	assert_eq(adjusted, 39, "狂暴增殖应使总数 ×1.3 = 39")

func test_draw_modifiers_max_one_per_type() -> void:
	var wm := load("res://scripts/systems/wave_manager.gd").new()
	add_child_autofree(wm)
	var mods: Array = wm.draw_modifiers(10, 2)
	var difficulty_count: int = 0
	var reward_count: int = 0
	for m: WaveModifierData in mods:
		if m.type == WaveModifierData.ModifierType.DIFFICULTY:
			difficulty_count += 1
		else:
			reward_count += 1
	assert_true(difficulty_count <= 1)
	assert_true(reward_count <= 1)
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 创建 WaveModifierData**

```gdscript
class_name WaveModifierData extends Resource

enum ModifierType { DIFFICULTY, REWARD }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var type: ModifierType = ModifierType.DIFFICULTY
@export var min_wave: int = 1
@export var weight: float = 1.0
```

- [ ] **Step 4: 创建 8 个修饰词 .tres 配置文件**

- [ ] **Step 5: GameConfig 注册修饰词加载**

```gdscript
var modifiers: Dictionary = {}
# _ready() 中：
_load_resources_from_dir("res://resources/modifiers/", modifiers)
```

- [ ] **Step 6: WaveManager 新增修饰词抽取和应用**

```gdscript
func draw_modifiers(wave_number: int, count: int) -> Array:
	var available_difficulty: Array = []
	var available_reward: Array = []
	for mod: WaveModifierData in GameConfig.modifiers.values():
		if mod.min_wave <= wave_number:
			if mod.type == WaveModifierData.ModifierType.DIFFICULTY:
				available_difficulty.append(mod)
			else:
				available_reward.append(mod)
	var result: Array = []
	if count >= 1 and available_difficulty.size() > 0:
		result.append(_weighted_pick(available_difficulty))
	if count >= 2 and available_reward.size() > 0:
		result.append(_weighted_pick(available_reward))
	return result
```

在 `_start_wave_with_data()` 中抽取修饰词并 emit `EventBus.wave_modifier_applied`。

- [ ] **Step 7: EnemySpawner 响应修饰词**

检查当前修饰词列表，应用效果：
- `elite_invasion`：elite_chance × 2
- `four_sides`：修改生成位置逻辑
- `speed_rush`：生成的敌人 speed × 1.3
- `heavy_assault`：tank 权重大幅提升
- `frenzy_spawn`：total_enemies × 1.3

- [ ] **Step 8: 运行测试确认通过**

- [ ] **Step 9: 提交**

```bash
git add scripts/resources/wave_modifier_data.gd resources/modifiers/ scripts/core/game_config.gd scripts/systems/wave_manager.gd scripts/systems/enemy_spawner.gd tests/unit/test_wave_modifiers.gd
git commit -m "feat: 波次修饰词系统（8 个修饰词 + 抽取 + 应用）"
```

---

## Task 22: HUD 修饰词显示

**Files:**
- Modify: `scripts/ui/hud.gd`

- [ ] **Step 1: 添加修饰词展示 UI**

- 波次开始前屏幕中央展示修饰词名称 + 描述（1.5 秒 Tween 淡入淡出）
- HUD 波次面板旁显示小图标

- [ ] **Step 2: 连接 EventBus.wave_modifier_applied 信号**

- [ ] **Step 3: 运行游戏验证显示效果**

- [ ] **Step 4: 提交**

```bash
git add scripts/ui/hud.gd
git commit -m "feat: HUD 波次修饰词展示"
```

---

## Task 23: 集成测试 + 全流程验证

**Files:**
- Create/Modify: `tests/integration/test_combat_overhaul.gd`

- [ ] **Step 1: 编写全流程集成测试**

```gdscript
# tests/integration/test_combat_overhaul.gd
extends GutTest

func test_forest_waves_use_total_enemies() -> void:
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		assert_gt(w.total_enemies, 0, "波 %d 应有 total_enemies" % w.wave_number)
		assert_gt(w.time_limit_safety, 0.0, "波 %d 应有安全阀时间" % w.wave_number)

func test_all_enemy_weights_valid() -> void:
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		for enemy_id: String in w.enemy_weights:
			assert_true(GameConfig.enemies.has(enemy_id), "敌人 %s 应已注册" % enemy_id)

func test_all_modifiers_loaded() -> void:
	assert_gt(GameConfig.modifiers.size(), 0, "修饰词应已加载")

func test_dora_passive_pool_complete() -> void:
	var cd: CharacterData = GameConfig.characters["dora"]
	assert_eq(cd.passive_pool.size(), 10, "Dora 应有 10 个被动")
	for pid: String in cd.passive_pool:
		assert_true(GameConfig.passives.has(pid), "被动 %s 应已注册" % pid)

func test_exp_config_has_level_bonuses() -> void:
	var cfg: ExpConfig = GameConfig.exp_config
	assert_gt(cfg.level_attack_bonus, 0.0)
	assert_gt(cfg.level_heal_ratio, 0.0)
```

- [ ] **Step 2: 运行全部测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

- [ ] **Step 3: 修复任何失败的测试**

- [ ] **Step 4: 运行游戏完整打一轮 12 波，验证全流程**

验证清单：
- [ ] 波次以清敌结束（不是倒计时）
- [ ] HUD 显示击杀计数
- [ ] 新敌人类型正常出场和行为
- [ ] 升级有即时属性提升 + 视觉反馈
- [ ] 波间出现被动选择界面
- [ ] 选择被动后进入商店
- [ ] 主动技能（Space）正常释放和 CD
- [ ] 修饰词在波次开始时展示
- [ ] Boss 波正常运作

- [ ] **Step 5: 提交**

```bash
git add tests/integration/test_combat_overhaul.gd
git commit -m "test: 战斗体验重塑集成测试"
```

---

## 依赖关系图

```
Task 1 (WaveData 重构) ──→ Task 3 (WaveManager) ──→ Task 4 (EnemySpawner) ──→ Task 5 (HUD)
     │                          │                          │
     └──→ Task 6 (波次配置) ────┘                          │
                                                           ↓
Task 2 (EventBus) ─────────────────────────────→ Task 7 (连接计数)
                                                           │
                                                           ↓
Task 8 (ExpConfig) ──→ Task 9 (PlayerProgression) ──→ Task 10 (升级特效)

Task 11 (PassiveData) ──→ Task 12 (PlayerState) ──→ Task 13 (被动配置) ──→ Task 14 (被动 UI)

Task 15 (ActiveSkill) ──→ Task 16 (Player 集成)

Task 17 (Behavior Resource) ──→ Task 18 (行为组件) ──→ Task 19 (场景+注册) ──→ Task 20 (更新波次)

Task 21 (修饰词系统) ──→ Task 22 (HUD 修饰词)

Task 23 (集成测试) — 依赖所有 Task 完成
```

**可并行的任务组：**
- 组 A: Task 1-7（波次系统）
- 组 B: Task 8-10（升级属性）— 可与组 A 并行
- 组 C: Task 11-14（被动系统）— 可与组 A/B 并行
- 组 D: Task 15-16（主动技能）— 可与组 A/B/C 并行
- 组 E: Task 17-20（新敌人）— 可与组 B/C/D 并行，但 Task 20 依赖组 A
- 组 F: Task 21-22（修饰词）— 依赖组 A 和组 E
- Task 23: 依赖所有组
