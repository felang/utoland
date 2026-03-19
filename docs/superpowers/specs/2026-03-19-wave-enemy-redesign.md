# 敌人与波次系统重设计

> 日期：2026-03-19
> 状态：设计中
> 前置：资源系统重设计（同日完成）

## 1. 设计目标

1. **怪海体验** — 后期同屏 200+ 敌人，VS 级视觉密度
2. **数量即难度** — 压力来自怪潮而非单体硬度，玩家武器能"割草"但敌人源源不断
3. **紧凑节奏** — 12 波三幕制，~20 分钟一局，每波都有事发生
4. **经济适配** — 与新资源体系（金币/经验/人口三分离）自然衔接

## 2. 波次结构：12 波三幕制

### 2.1 从 15 波改为 12 波

- 总时长 ~20 分钟（每波 40-90s 战斗 + ~30s 商店）
- 15 波的问题：前 5 波节奏拖沓，玩家在"等游戏开始"
- 12 波更紧凑，每波都有可感知的密度提升
- Boss 每 4 波出现（Wave 4/8/12），节奏均匀

### 2.2 三幕结构

| 幕 | 波次 | 时长范围 | max_alive | 体验 |
|---|---|---|---|---|
| **序幕** | 1-4 | 40-55s | 15→40 | 学习、成长、初见 Boss |
| **中盘** | 5-8 | 55-70s | 50→100 | 加速、压力、阵容成型 |
| **怪海** | 9-12 | 70-90s | 130→250 | 爆发、割草、终极 Boss |

## 3. 逐波配置

### 3.1 完整波次表

| 波次 | 时长 | max_alive | enemy_weights | elite_chance | Boss |
|---|---|---|---|---|---|
| 1 | 40s | 15 | normal:100 | 0% | — |
| 2 | 42s | 20 | normal:80, fast:20 | 0% | — |
| 3 | 45s | 30 | normal:60, fast:30, tank:10 | 3% | — |
| 4 | 55s | 40 | normal:50, fast:30, tank:20 | 5% | boss_brute |
| 5 | 55s | 50 | normal:40, fast:40, tank:20 | 5% | — |
| 6 | 60s | 65 | normal:35, fast:45, tank:20 | 7% | — |
| 7 | 65s | 80 | normal:30, fast:50, tank:20 | 8% | — |
| 8 | 70s | 100 | normal:30, fast:40, tank:30 | 10% | boss_summoner |
| 9 | 75s | 130 | normal:40, fast:50, tank:10 | 10% | — |
| 10 | 80s | 160 | normal:45, fast:50, tank:5 | 12% | — |
| 11 | 85s | 200 | normal:50, fast:45, tank:5 | 12% | — |
| 12 | 90s | 250 | normal:40, fast:50, tank:10 | 15% | boss_guardian |

### 3.2 生成节奏（SpawnPhaseData）

每波分 2-3 个阶段，前慢后快，营造"涨潮"感。

**序幕 (W1-4)** — 3 阶段

| 阶段 | duration_ratio | spawn_interval | 说明 |
|---|---|---|---|
| Phase 1 | 0.3 | 2.0-2.5s | 慢热，玩家熟悉节奏 |
| Phase 2 | 0.5 | 1.0-1.5s | 加速，开始有压力 |
| Phase 3 | 0.2 | 0.6-0.8s | 冲刺，Boss 在此阶段生成 |

**中盘 (W5-8)** — 2 阶段

| 阶段 | duration_ratio | spawn_interval | 说明 |
|---|---|---|---|
| Phase 1 | 0.4 | 0.8-1.0s | 开场即有压力 |
| Phase 2 | 0.6 | 0.3-0.5s | 怪潮涌起，Boss 在此阶段生成 |

**怪海 (W9-12)** — 2 阶段

| 阶段 | duration_ratio | spawn_interval | 说明 |
|---|---|---|---|
| Phase 1 | 0.3 | 0.4-0.6s | 开场就是潮 |
| Phase 2 | 0.7 | 0.1-0.3s | 满屏都是怪，Boss 在此阶段生成 |

### 3.3 怪海的视觉构成（Wave 12 为例）

一屏 250 个敌人的大致比例：
- ~100 个 normal（中速、基础 HP，构成怪海主体）
- ~125 个 fast（高速穿插，制造混乱感）
- ~25 个 tank（大体型缓慢推进，视觉锚点）
- boss_guardian（最大，独特行为）

玩家的 Lv3 武器在怪群中效果：
- sword：扇形 AoE 一扫一片
- shuriken：弹射连锁击杀
- arrow：击退+穿透清出通道
- 塔：持续输出消耗怪潮

## 4. 难度缩放

### 4.1 核心原则：数量即难度

替换当前 Wave 11+ 的指数增长（HP ×1.06^n, DMG ×1.04^n），改为**全程温和线性增长**。

难度来源从"单体变硬"转为"数量压制"：
- 后期小怪 HP 只温和增长，确保玩家 Lv2-3 武器能快速清掉
- 压力来自生成速率（0.1-0.3s 一个）和同屏上限（200-250）
- 伤害几乎不涨，避免"一碰就死"的挫败感

### 4.2 HP 缩放（线性）

| 波次 | HP 乘数 | normal HP | fast HP | tank HP |
|---|---|---|---|---|
| 1-4 | 1.0 | 50 | 35 | 200 |
| 5-6 | 1.15 | 57 | 40 | 230 |
| 7-8 | 1.3 | 65 | 45 | 260 |
| 9-10 | 1.45 | 72 | 51 | 290 |
| 11-12 | 1.6 | 80 | 56 | 320 |

实现方式：`EnemySpawner` 中按波次号计算线性乘数，替换当前的指数缩放：
```
hp_mult = 1.0 + (wave_number - 1) * 0.055  # Wave 1=1.0, Wave 12=1.6
```

### 4.3 伤害缩放（微涨）

| 波次 | 伤害乘数 | normal DMG | fast DMG | tank DMG |
|---|---|---|---|---|
| 1-8 | 1.0 | 10 | 8 | 25 |
| 9-10 | 1.05 | 10.5 | 8.4 | 26 |
| 11-12 | 1.15 | 11.5 | 9.2 | 29 |

实现方式：
```
damage_mult = 1.0 if wave_number <= 8 else 1.0 + (wave_number - 8) * 0.0375
```

### 4.4 精英怪缩放

精英乘数保持不变（HP ×1.5, DMG ×1.3, Scale ×1.2, EXP ×2.0），只通过 `elite_chance` 逐波递增控制出现频率。

## 5. 经验平衡

### 5.1 经验曲线参数不变

`base_exp = 5.0`, `exp_exponent = 1.6`（资源系统重设计中已调整）。

### 5.2 敌人经验掉落不变

| 敌人 | exp_drop_min | exp_drop_max |
|---|---|---|
| normal | 1 | 1 |
| fast | 1 | 1 |
| tank | 1 | 2 |
| boss_brute | 8 | 10 |
| boss_summoner | 10 | 12 |
| boss_guardian | 12 | 15 |

### 5.3 预期升级节奏

12 波中，后期怪虽多但经验球散布广泛、玩家忙于生存来不及全捡。拾取范围成长 (+5%/级) 部分补偿但不完全弥补。

| 阶段 | 每波有效 exp（估） | 累计 | 预期等级 | 人口 |
|---|---|---|---|---|
| W1-2 | ~12-15 | ~27 | Lv2-3 | 3 |
| W3-4 | ~20-30 | ~70 | Lv4 | 5 |
| W5-6 | ~25-30 | ~125 | Lv5-6 | 6-7 |
| W7-8 | ~20-25 | ~170 | Lv7 | 8 |
| W9-10 | ~15-20 | ~205 | Lv7-8 | 8-9 |
| W11-12 | ~15 | ~235 | Lv8-9 | 9-10 |

Tier 2 被动进化（Lv4）大约在 W3-4 触发，Tier 3（Lv7）在 W7-8 触发，与三幕节奏吻合。

## 6. 金币经济适配

### 6.1 波次奖励阈值调整

从 `[1, 6, 11]` 改为 `[1, 5, 9]`，匹配 12 波三幕结构：

| 波次 | 奖励 |
|---|---|
| 1-4 | 5 金 |
| 5-8 | 8 金 |
| 9-12 | 10 金 |

总波次奖励：4×5 + 4×8 + 4×10 = 92 金（原 15 波 115 金）。

### 6.2 Boss 赏金重新分配

| Boss | 波次 | 赏金 |
|---|---|---|
| boss_brute | 4 | 15 金 |
| boss_summoner | 8 | 20 金 |
| boss_guardian | 12 | 30 金 |

赏金数值不变，只是 Boss 出现波次从 5/10/15 改为 4/8/12。

## 7. 需要的代码改动

### 7.1 WaveData .tres 文件

- 删除 `resources/waves/<map_id>/` 下的 wave_06 到 wave_15 中多余的 3 个文件（保留 12 个）
- 重新配置所有 12 个波次的数值（time_limit, max_alive_enemies, spawn_phases, enemy_weights, elite_chance, is_boss_wave, boss_id）
- 注意：波次文件按地图组织，当前只有一张地图

### 7.2 EnemySpawner 难度缩放

`scripts/systems/enemy_spawner.gd`：
- 删除当前的指数缩放常量和逻辑（`SCALING_START_WAVE`, `HP_SCALING_PER_WAVE`, `DAMAGE_SCALING_PER_WAVE`）
- 替换为线性缩放：
```gdscript
const HP_SCALING_PER_WAVE: float = 0.055      # Wave 1=1.0, Wave 12=1.6
const DAMAGE_SCALING_START_WAVE: int = 9
const DAMAGE_SCALING_PER_WAVE: float = 0.0375  # Wave 9=1.0, Wave 12=1.15

func get_wave_scaling(wave_number: int) -> Dictionary:
    var hp_mult: float = 1.0 + (wave_number - 1) * HP_SCALING_PER_WAVE
    var damage_mult: float = 1.0
    if wave_number >= DAMAGE_SCALING_START_WAVE:
        damage_mult = 1.0 + (wave_number - DAMAGE_SCALING_START_WAVE) * DAMAGE_SCALING_PER_WAVE
    return {"hp_mult": hp_mult, "damage_mult": damage_mult}
```
- 缩放应用于所有非 Boss 敌人（所有波次，不再限制 Wave 11+）

### 7.3 ShopConfig 波次奖励阈值

`resources/shop/shop_config.tres` 或 `scripts/resources/shop_config.gd`：
- `wave_reward_tier_thresholds` 从 `[1, 6, 11]` 改为 `[1, 5, 9]`

### 7.4 GameConfig / WaveManager

- 波次数据加载逻辑不变（已按地图从 `resources/waves/<map_id>/` 加载）
- `total_waves` 由加载的波次数据数量决定，不需要硬编码
- 确认 WaveManager 没有硬编码 15 的地方

### 7.5 HUD 显示

- 确认 HUD 的波次显示（"第 X 波"）能正确适配 12 波
- 倒计时逻辑不变

## 8. 不在本次范围内

- 性能优化（轻量级敌人架构、渲染优化等）— 后续单独处理
- 新增敌人类型 — 保持现有 3 种普通敌人 + 3 种 Boss
- Boss 机制改进 — 保持现有行为
- 新地图的波次配置 — 当前只处理一张地图
