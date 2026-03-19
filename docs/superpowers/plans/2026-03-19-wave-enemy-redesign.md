# 敌人与波次系统重设计 实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 15 波改为 12 波三幕制，难度缩放从指数改为线性（数量即难度），适配新资源体系

**Architecture:** 重写全部波次 .tres 配置文件（12 个），修改 EnemySpawner 难度缩放为线性公式，调整 ShopConfig 波次奖励阈值，更新所有引用旧波次数/Boss 位置的测试。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

**设计文档:** `docs/superpowers/specs/2026-03-19-wave-enemy-redesign.md`

---

## Chunk 1: 代码逻辑改动

### Task 1: EnemySpawner 难度缩放改为线性

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd:4-6,80-87,101-123`

- [ ] **Step 1: 修改缩放常量和公式**

替换 `scripts/systems/enemy_spawner.gd` 行 4-6 的常量：

当前：
```gdscript
const SCALING_START_WAVE := 11
const HP_SCALING_PER_WAVE := 1.06
const DAMAGE_SCALING_PER_WAVE := 1.04
```

改为：
```gdscript
const HP_SCALING_PER_WAVE: float = 0.055
const DAMAGE_SCALING_START_WAVE: int = 9
const DAMAGE_SCALING_PER_WAVE: float = 0.0375
```

- [ ] **Step 2: 替换 get_wave_scaling() 方法**

替换行 80-87 的方法体：

当前：
```gdscript
static func get_wave_scaling(wave_number: int) -> Dictionary:
	if wave_number < SCALING_START_WAVE:
		return {"hp_mult": 1.0, "damage_mult": 1.0}
	var waves_past: int = wave_number - SCALING_START_WAVE + 1
	return {
		"hp_mult": pow(HP_SCALING_PER_WAVE, waves_past),
		"damage_mult": pow(DAMAGE_SCALING_PER_WAVE, waves_past)
	}
```

改为：
```gdscript
static func get_wave_scaling(wave_number: int) -> Dictionary:
	var hp_mult: float = 1.0 + (wave_number - 1) * HP_SCALING_PER_WAVE
	var damage_mult: float = 1.0
	if wave_number >= DAMAGE_SCALING_START_WAVE:
		damage_mult = 1.0 + (wave_number - DAMAGE_SCALING_START_WAVE) * DAMAGE_SCALING_PER_WAVE
	return {"hp_mult": hp_mult, "damage_mult": damage_mult}
```

- [ ] **Step 3: 移除缩放的 wave 11+ 门槛**

在 `_spawn_normal_enemy()` 中（约行 101-123），找到：
```gdscript
if not enemy.data.is_boss:
	var scaling = get_wave_scaling(_current_wave_data.wave_number)
	if scaling.hp_mult > 1.0:
```

`if scaling.hp_mult > 1.0:` 这个条件可以保留（Wave 1 的 hp_mult 刚好是 1.0 不会进入）。但确保不再有 `SCALING_START_WAVE` 的旧引用。

- [ ] **Step 4: 提交**

```bash
git add scripts/systems/enemy_spawner.gd
git commit -m "refactor: 敌人难度缩放从指数改为线性（数量即难度）"
```

---

### Task 2: ShopConfig 波次奖励阈值调整

**Files:**
- Modify: `scripts/resources/shop_config.gd:12`

- [ ] **Step 1: 修改阈值**

`scripts/resources/shop_config.gd` 行 12，将：
```gdscript
@export var wave_reward_tier_thresholds: PackedInt32Array = [1, 6, 11]
```
改为：
```gdscript
@export var wave_reward_tier_thresholds: PackedInt32Array = [1, 5, 9]
```

- [ ] **Step 2: 提交**

```bash
git add scripts/resources/shop_config.gd
git commit -m "chore: 波次奖励阈值适配12波结构（1/5/9替代1/6/11）"
```

---

### Task 3: 更新地图 wave_count

**Files:**
- Modify: `resources/maps/forest.tres`

- [ ] **Step 1: 修改 forest.tres**

读取 `resources/maps/forest.tres`，将 `wave_count = 18`（或当前值）改为 `wave_count = 12`。

- [ ] **Step 2: 提交**

```bash
git add resources/maps/forest.tres
git commit -m "chore: forest 地图 wave_count 改为 12"
```

---

## Chunk 2: 波次数据文件重写

### Task 4: 重写全部 12 个波次 .tres 文件

**Files:**
- Delete: `resources/waves/forest/wave_13.tres`, `wave_14.tres`, `wave_15.tres`
- Rewrite: `resources/waves/forest/wave_01.tres` 到 `wave_12.tres`

这是最大的任务。每个 .tres 文件需要包含 WaveData 和内嵌的 SpawnPhaseData 子资源。

- [ ] **Step 1: 删除多余的波次文件**

```bash
rm resources/waves/forest/wave_13.tres resources/waves/forest/wave_14.tres resources/waves/forest/wave_15.tres
```

- [ ] **Step 2: 读取一个现有波次文件作为模板**

读取 `resources/waves/forest/wave_05.tres` 了解 .tres 格式（含内嵌 SpawnPhaseData 子资源的写法）。

- [ ] **Step 3: 重写 Wave 1-4（序幕）**

**wave_01.tres:**
- wave_number=1, time_limit=40.0, max_alive_enemies=15
- enemy_weights={"normal":100}
- elite_chance=0.0, is_boss_wave=false
- 3 个 SpawnPhaseData: (0.3, 2.5s), (0.5, 1.5s), (0.2, 0.8s)

**wave_02.tres:**
- wave_number=2, time_limit=42.0, max_alive_enemies=20
- enemy_weights={"normal":80, "fast":20}
- elite_chance=0.0
- 3 个 SpawnPhaseData: (0.3, 2.2s), (0.5, 1.3s), (0.2, 0.7s)

**wave_03.tres:**
- wave_number=3, time_limit=45.0, max_alive_enemies=30
- enemy_weights={"normal":60, "fast":30, "tank":10}
- elite_chance=0.03
- 3 个 SpawnPhaseData: (0.3, 2.0s), (0.5, 1.2s), (0.2, 0.6s)

**wave_04.tres (Boss):**
- wave_number=4, time_limit=55.0, max_alive_enemies=40
- enemy_weights={"normal":50, "fast":30, "tank":20}
- elite_chance=0.05, is_boss_wave=true, boss_id="boss_brute"
- 3 个 SpawnPhaseData: (0.3, 2.0s), (0.5, 1.0s), (0.2, 0.6s)

- [ ] **Step 4: 重写 Wave 5-8（中盘）**

**wave_05.tres:**
- wave_number=5, time_limit=55.0, max_alive_enemies=50
- enemy_weights={"normal":40, "fast":40, "tank":20}
- elite_chance=0.05
- 2 个 SpawnPhaseData: (0.4, 1.0s), (0.6, 0.5s)

**wave_06.tres:**
- wave_number=6, time_limit=60.0, max_alive_enemies=65
- enemy_weights={"normal":35, "fast":45, "tank":20}
- elite_chance=0.07
- 2 个 SpawnPhaseData: (0.4, 0.9s), (0.6, 0.4s)

**wave_07.tres:**
- wave_number=7, time_limit=65.0, max_alive_enemies=80
- enemy_weights={"normal":30, "fast":50, "tank":20}
- elite_chance=0.08
- 2 个 SpawnPhaseData: (0.4, 0.8s), (0.6, 0.3s)

**wave_08.tres (Boss):**
- wave_number=8, time_limit=70.0, max_alive_enemies=100
- enemy_weights={"normal":30, "fast":40, "tank":30}
- elite_chance=0.10, is_boss_wave=true, boss_id="boss_summoner"
- 2 个 SpawnPhaseData: (0.4, 0.8s), (0.6, 0.3s)

- [ ] **Step 5: 重写 Wave 9-12（怪海）**

**wave_09.tres:**
- wave_number=9, time_limit=75.0, max_alive_enemies=130
- enemy_weights={"normal":40, "fast":50, "tank":10}
- elite_chance=0.10
- 2 个 SpawnPhaseData: (0.3, 0.5s), (0.7, 0.2s)

**wave_10.tres:**
- wave_number=10, time_limit=80.0, max_alive_enemies=160
- enemy_weights={"normal":45, "fast":50, "tank":5}
- elite_chance=0.12
- 2 个 SpawnPhaseData: (0.3, 0.4s), (0.7, 0.15s)

**wave_11.tres:**
- wave_number=11, time_limit=85.0, max_alive_enemies=200
- enemy_weights={"normal":50, "fast":45, "tank":5}
- elite_chance=0.12
- 2 个 SpawnPhaseData: (0.3, 0.3s), (0.7, 0.1s)

**wave_12.tres (Boss):**
- wave_number=12, time_limit=90.0, max_alive_enemies=250
- enemy_weights={"normal":40, "fast":50, "tank":10}
- elite_chance=0.15, is_boss_wave=true, boss_id="boss_guardian"
- 2 个 SpawnPhaseData: (0.3, 0.3s), (0.7, 0.1s)

- [ ] **Step 6: 提交**

```bash
git add resources/waves/forest/
git commit -m "feat: 重写12波三幕制波次配置（序幕/中盘/怪海）"
```

---

## Chunk 3: 测试更新与验证

### Task 5: 更新所有受影响的测试

**Files:**
- Modify: `tests/unit/test_wave_balance.gd`
- Modify: `tests/unit/test_wave_scaling.gd`
- Modify: `tests/unit/test_wave_reward.gd`
- Modify: `tests/unit/test_wave_manager.gd`
- Modify: `tests/unit/test_boss_wave_spawner.gd`
- Modify: `tests/integration/test_wave_system.gd`
- Modify: `tests/integration/test_enemy_spawning.gd`

- [ ] **Step 1: 更新 `test_wave_balance.gd`**

先读取完整文件。关键修改：
- `test_forest_has_15_waves()` → `test_forest_has_12_waves()`：断言 `waves.size() == 12`
- `test_boss_waves_at_5_10_15()` → `test_boss_waves_at_4_8_12()`：改为检查 waves[3], waves[7], waves[11]
- `test_boss_ids()`：boss_brute 在 waves[3]，boss_summoner 在 waves[7]，boss_guardian 在 waves[11]
- 其他引用旧索引的断言全部更新

- [ ] **Step 2: 更新 `test_wave_scaling.gd`**

先读取完整文件。关键修改：
- 现在缩放从 Wave 1 就开始（HP），不再是 Wave 11+
- Wave 1 的 hp_mult = 1.0（(1-1)*0.055=0.0，所以1.0+0.0=1.0）
- Wave 6 的 hp_mult = 1.0 + 5*0.055 = 1.275
- Wave 12 的 hp_mult = 1.0 + 11*0.055 = 1.605
- 伤害缩放从 Wave 9 开始：Wave 9 = 1.0, Wave 12 = 1.0 + 3*0.0375 = 1.1125
- 更新所有断言和测试用例

- [ ] **Step 3: 更新 `test_wave_reward.gd`**

先读取完整文件。修改波次奖励阈值相关断言：
- Wave 1-4: 5 金
- Wave 5-8: 8 金
- Wave 9-12: 10 金
- 具体：`get_wave_reward(5)` 应返回 8（不再是 5）
- `get_wave_reward(6)` 返回 8（不变）
- `get_wave_reward(9)` 返回 10（原来是 8）

- [ ] **Step 4: 更新 `test_wave_manager.gd` 和 `test_boss_wave_spawner.gd`**

读取文件，修改所有引用旧波次数或旧 Boss 位置的断言。

- [ ] **Step 5: 更新集成测试**

`tests/integration/test_wave_system.gd`：
- 波次数从 15 改为 12
- Boss 位置从 5/10/15 改为 4/8/12
- 波次索引引用全部更新（如 [14] → [11]）

`tests/integration/test_enemy_spawning.gd`：
- 检查是否有引用旧波次数或缩放逻辑的测试

- [ ] **Step 6: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

修复所有失败的测试。

- [ ] **Step 7: 提交**

```bash
git add tests/
git commit -m "test: 更新所有测试适配12波三幕制"
```

---

### Task 6: 最终验证

- [ ] **Step 1: 运行完整测试套件**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 2: 提交最终修复（如有）**

```bash
git add -A
git commit -m "fix: 波次系统重设计最终修复"
```
