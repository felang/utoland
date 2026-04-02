# 战斗体验重塑设计文档

**日期**: 2026-04-02
**目标**: 解决"全程无聊"的核心问题，让战斗有决策、有节奏、有反馈

## 问题诊断

当前游戏存在三个导致"无聊"的根本原因：

1. **战斗中玩家几乎没有决策** — 武器全自动瞄准开火，玩家只有 WASD 移动，最优策略是"跑圈耗时间"
2. **商店缺乏真正的选择** — 统一定价、人口是唯一约束、刷新无意义、合成永远正确
3. **反馈系统有骨架缺肌肉** — 连杀有追踪但无可视化、击中感弱、Boss 和普通敌人死亡特效几乎一样

本文档聚焦**战斗体验重塑**（问题 1），商店经济重做和打击感升级将在后续独立文档中设计。

## 设计概览

六个模块协同解决"战斗无聊"：

| 模块 | 解决的问题 | 核心改动 |
|------|-----------|---------|
| 波次系统改为分批清敌制 | 跑圈耗时间是最优策略 | 击杀推进进度，积极战斗被奖励 |
| 波次修饰词系统 | 每波都一样，缺乏变化 | 随机修饰词让每波有独特规则 |
| 升级即时属性提升 | 升级无即时爽感 | 每级自动获得数值提升 + 强视觉反馈 |
| 被动自由池系统 | 波间决策深度不足 | 每次商店前 3 选 1 角色专属被动 |
| 角色主动技能 | 战斗中无主动操作 | CD 制技能，"关键时刻"按钮 |
| 新增 4 种敌人 | 敌人行为单一 | 远程/自爆/分裂/护盾，各考验不同能力 |

## 模块一：波次系统 — 分批清敌制

### 现状问题

当前为纯时间制（`time_limit` 倒计时），波次结束与玩家战斗表现无关。玩家可以完全不战斗，跑圈等时间到即过关。这让塔的价值、商店决策、新敌人类型全部贬值。

### 设计方案

**核心规则**：每波有固定的敌人**总数**，分批生成，全部击杀即过关。

#### 生成机制

- 每波定义 `total_enemies`（敌人总数）和多个 `SpawnPhase`（生成阶段）
- 每个 SpawnPhase 定义：`enemy_count_ratio`（占总数的比例）、`spawn_interval`（生成间隔）、`enemy_weights`（可选覆盖敌人权重）
- 前一阶段的敌人不需要全部击杀，到达阶段时间后自动进入下一阶段
- 阶段时间 = `enemy_count_ratio * total_enemies * spawn_interval`（即该阶段敌人全部生成完毕的时间）
- `max_alive_enemies` 仍然保留，控制场上同时存在的上限，达到上限时暂停生成

#### 过关条件

- **主条件**：已生成敌人数 == total_enemies 且 场上存活敌人数 == 0（含分裂小怪等衍生敌人）
- **安全阀**：设置宽松的时间上限（约为正常通关时间的 2 倍），超时强制过关但减少波次奖励（`ShopConfig.wave_reward` × `timeout_reward_ratio`），Boss 赏金不受影响
- 安全阀目的：防止玩家卡死在某一波
- **击杀计数**：WaveManager 追踪 `enemies_killed`（含衍生敌人）和 `enemies_alive`（场上存活数），HUD 显示格式为 `enemies_killed / total_enemies`（分裂小怪不计入分母，因此击杀数可能暂时超过总数显示）

#### 清波加速机制

- 杀得快 → 当前阶段生成完毕后更快进入下一阶段（不需要等阶段时间用完）
- 具体实现：当阶段内所有已生成敌人被击杀 且 该阶段 `enemy_count` 已全部生成，立即进入下一阶段
- 这样积极战斗的玩家可以更快完成波次

#### 数据结构变更

**WaveData** 修改：
```
# 移除
time_limit: float

# 新增
total_enemies: int          # 本波敌人总数
time_limit_safety: float    # 安全阀时间上限（秒），超时强制过关
timeout_reward_ratio: float # 超时过关的奖励比例（默认 0.5）
```

**SpawnPhaseData** 修改：
```
# 保留
spawn_interval: float
enemy_weights: Dictionary   # 可选

# 修改
enemy_count_ratio: float    # 替代 duration_ratio，该阶段占总数的比例
```

#### 波次数量变更

原设计为 15 波（Boss 在 5/10/15），改为 **12 波**（Boss 在 4/8/12）。理由：15 波对试玩版过长（约 25-30 分钟），12 波控制在 15-20 分钟。此变更仅影响 forest 地图配置，其他地图可有不同波次数量。

#### 12 波节奏设计

```
波 1:  total=15,  节奏=轻松    — 纯 normal，入门
波 2:  total=25,  节奏=轻松    — normal + fast 混合
波 3:  total=35,  节奏=中等    — 引入新敌人类型
波 4:  total=50,  节奏=高潮    — Boss(brute) + 小怪混合
波 5:  total=30,  节奏=喘息    — 较少敌人，节奏放缓
波 6:  total=45,  节奏=中等    — 多种敌人混合
波 7:  total=60,  节奏=紧张    — 密集生成，压力波
波 8:  total=70,  节奏=高潮    — Boss(summoner) + 小怪混合
波 9:  total=40,  节奏=喘息    — 喘息波
波 10: total=65,  节奏=紧张    — 高强度混合
波 11: total=80,  节奏=极限    — 密集 + 精英
波 12: total=100, 节奏=终极高潮 — Boss(guardian) + 大量小怪
```

节奏曲线：轻松 → 轻松 → 中等 → **高潮** → 喘息 → 中等 → 紧张 → **高潮** → 喘息 → 紧张 → 极限 → **终极高潮**

#### HUD 变更

- 波次面板：从"倒计时（分:秒）"改为"剩余敌人数（已击杀/总数）"
- 安全阀倒计时：仅在剩余时间 < 30 秒时显示警告

### 受影响文件

- `scripts/resources/wave_data.gd` — 字段修改
- `scripts/resources/spawn_phase_data.gd` — 字段修改
- `scripts/systems/wave_manager.gd` — 结束条件逻辑
- `scripts/systems/enemy_spawner.gd` — 分批生成 + 清波加速
- `scripts/ui/hud.gd` — 显示改为击杀计数
- `resources/waves/forest/*.tres` — 所有 12 个波次配置重写

---

## 模块二：波次修饰词系统

### 设计目标

让每波有独特的"个性"，打破"每波都一样"的感觉。

### 修饰词列表

**难度修饰词**（增加挑战）：
| 修饰词 | 效果 | 出现条件 |
|--------|------|---------|
| 精英入侵 | 本波精英概率翻倍 | 波 3+ |
| 四面围攻 | 敌人从地图四边同时生成（而非随机边） | 波 4+ |
| 速攻潮 | 所有敌人速度 +30% | 波 3+ |
| 重装来袭 | tank 类敌人权重大幅提升 | 波 5+ |
| 狂暴增殖 | 本波敌人生成总数 +30% | 波 6+ |

**奖励修饰词**（增加收益）：
| 修饰词 | 效果 | 出现条件 |
|--------|------|---------|
| 双倍经验 | 本波经验球价值 ×2 | 任意波 |
| 金币雨 | 本波额外掉落金币 | 任意波 |
| 宝箱波 | 本波出现宝箱怪，击杀掉大量金币 | 波 3+ |

### 规则

- 每波随机附加 1-2 个修饰词（从可用池中按权重抽取）
- 同一波不能同时出现两个难度修饰词和两个奖励修饰词（最多各一个）
- Boss 波使用固定修饰词（不随机）：Boss 波自带"精英入侵"
- 波 1 无修饰词（纯净入门体验）

### 数据结构

新增 `WaveModifierData` Resource：
```
enum ModifierType { DIFFICULTY, REWARD }

@export var id: String                    # "elite_invasion"
@export var display_name: String          # "精英入侵"
@export var description: String           # "精英出现概率翻倍"
@export var type: ModifierType            # DIFFICULTY / REWARD
@export var min_wave: int                 # 最早出现的波次
@export var weight: float                 # 抽取权重
```

**WaveData** 新增：
```
@export var fixed_modifiers: Array[String]      # Boss 波的固定修饰词 ID
@export var modifier_count: int = 1             # 本波随机修饰词数量（0-2）
```

### UI 表现

- 波次开始前，屏幕中央展示修饰词名称 + 图标 + 简短描述（1.5 秒）
- HUD 波次面板旁显示当前修饰词小图标

### 受影响文件

- 新增 `scripts/resources/wave_modifier_data.gd`
- 新增 `resources/modifiers/*.tres`（8 个修饰词配置）
- `scripts/systems/wave_manager.gd` — 修饰词抽取 + 应用逻辑
- `scripts/systems/enemy_spawner.gd` — 响应修饰词（速度/权重/生成方向等）
- `scripts/ui/hud.gd` — 修饰词展示 UI
- `scripts/core/game_config.gd` — 注册加载修饰词配置

---

## 模块三：升级即时属性提升

### 现状问题

当前升级只增加人口上限，战斗中升级没有即时体感。玩家拼命收经验球，升了级却感觉不到变化。

### 设计方案

每次升级自动获得一组属性提升，不暂停游戏，配合强视觉反馈。

#### 属性提升公式

每级提升为**百分比加成**，叠加到 `PlayerState.player_stats` 上：

| 属性 | 每级提升 | 10 级总提升 |
|------|---------|------------|
| 攻击力 | +6% | +60% |
| 攻速 | +5% | +50% |
| 最大 HP | +5% | +50% |
| 移动速度 | +3% | +30% |

- 提升为乘法叠加：`base_value * (1 + level_bonus_ratio)`
- `level_bonus_ratio = level * per_level_ratio`（如攻击力：`level * 0.06`）
- 人口上限仍然保留：`initial_population + (level - 1) * population_per_level`

> **迁移注意**：`player.gd` 中现有的 `LEVEL_HP_GROWTH`(0.03)、`LEVEL_SPEED_GROWTH`(0.02)、`LEVEL_PICKUP_GROWTH`(0.05) 硬编码常量将被移除，统一由 `ExpConfig` 中的新字段驱动。新增攻击力和攻速加成（原本没有）。

#### 升级时回复

- 升级时回复 20% 最大 HP（向上取整）
- 为升级增加即时生存价值

#### 配置

在 `ExpConfig` 中新增：
```
@export var level_attack_bonus: float = 0.06       # 每级攻击力加成
@export var level_attack_speed_bonus: float = 0.05  # 每级攻速加成
@export var level_max_hp_bonus: float = 0.05        # 每级最大 HP 加成
@export var level_move_speed_bonus: float = 0.03    # 每级移动速度加成
@export var level_heal_ratio: float = 0.2           # 升级回复比例
```

#### 视觉反馈

升级瞬间：
- 玩家周围扩散一圈光环（金色/白色）
- "LEVEL UP!" 飘字 + 等级数字
- 短暂屏幕闪白（50ms）
- 升级音效
- 属性提升数值飘字（"+6% ATK", "+5% SPD" 等）

#### 经验曲线调整

确保 12 波内大约可以升 8-12 级：
- 当前公式：`floor(base_exp * n^exp_exponent)`，base=5, exponent=1.6
- 需要根据新的 total_enemies 和经验球掉落量重新调试
- 目标：每波平均升 0.7-1 级，Boss 波可能升 1-2 级

### 受影响文件

- `scripts/resources/exp_config.gd` — 新增属性加成配置
- `scripts/core/player_progression.gd` — 升级时计算并应用属性加成 + 回复
- `scripts/core/player_state.gd` — `player_stats` 支持等级加成叠加
- `scripts/entities/player.gd` — 响应属性变化
- `scripts/entities/weapons/weapon_manager.gd` — 响应攻击力/攻速变化
- `scripts/systems/effects_manager.gd` — 新增升级特效
- `scripts/core/event_bus.gd` — 可能新增 `player_leveled_up` 信号（带属性变化详情）

---

## 模块四：被动自由池系统

### 设计目标

给波间商店增加构建深度。每次进商店前，先从角色专属被动池中 3 选 1。

### 流程

```
波次结束
  → 吸引剩余经验球/金币
  → 被动选择界面（3 选 1，全屏半透明遮罩）
  → 进入商店（ShopOverlay 弹出）
  → 点击"开战"进入下一波
```

### 被动池设计

每个角色有 8-10 个专属被动，每次提供 3 个选项，已选不再出现。12 波约进 11 次商店，理论上可以选满整个池。

#### 试玩版被动列表（仅 Dora）

Dora 定位为平衡型剑士，被动围绕"全面强化 + 金币收益"：

| 被动 ID | 名称 | 效果 |
|---------|------|------|
| dora_blade_mastery | 刀刃精通 | 剑类武器伤害 +25% |
| dora_swift_draw | 快速拔刀 | 所有武器攻速 +15% |
| dora_treasure_hunter | 寻宝猎人 | 击杀敌人有 15% 概率额外掉落金币 |
| dora_tough_skin | 厚皮 | 受到伤害减少 15% |
| dora_exp_magnet | 经验磁铁 | 经验球吸引范围 +100% |
| dora_tower_synergy | 塔协同 | 塔攻击范围 +20% |
| dora_second_wind | 再起之风 | HP 低于 30% 时移动速度 +30% |
| dora_gold_interest | 金币利息 | 每波结束时，每持有 10 金币额外 +1 金币 |
| dora_combo_strike | 连击打击 | 连续击杀 5 个敌人后，下次攻击伤害 ×2 |
| dora_fortify | 坚固防线 | 塔最大 HP +30% |

> 注意：其他角色的被动池将在内容扩充阶段设计。被动应与角色定位和被动特性（Dora 的 `coin_bonus`）协同。

### 数据结构

新增 `PassiveData` Resource：
```
@export var id: String                # "dora_blade_mastery"
@export var display_name: String      # "刀刃精通"
@export var description: String       # "剑类武器伤害 +25%"
@export var icon_path: String         # 图标路径
@export var character_id: String      # 所属角色 "dora"
@export var effects: Dictionary       # {"weapon_damage_sword": 0.25} 效果键值对
```

`CharacterData` 新增：
```
@export var passive_pool: Array[String]  # 被动 ID 列表
```

`PlayerState` 新增：
```
var acquired_passives: Array[String] = []  # 已获得的被动 ID
```

### 与现有被动系统的关系

当前代码中存在两套被动系统：
1. `CharacterData.new_passive_id` / `new_passive_value` / `new_passive_value_2`（角色初始被动）
2. `CharacterData.passive_evolution: PassiveEvolutionData`（被动进化链）

**迁移方案**：被动自由池**替代**以上两套系统。现有角色初始被动（如 Dora 的 `coin_bonus`）转为被动池中的第一个被动，在游戏开始时自动获得（不占选择次数）。`passive_evolution` 系统废弃。

### 被动效果应用

- 被动效果通过 `PlayerState.player_stats` 叠加
- 部分被动需要特殊逻辑（如 `treasure_hunter` 的概率掉落、`gold_interest` 的波间结算）
- 特殊逻辑通过 EventBus 信号触发

### UI 设计

- 全屏半透明遮罩（类似卡牌选择界面）
- 3 张被动卡片横排展示（图标 + 名称 + 描述）
- 点击选择后卡片飞入角色头像，过渡动画后进入商店
- 若被动池已选完，跳过此步骤直接进商店

### 受影响文件

- 新增 `scripts/resources/passive_data.gd`
- 新增 `resources/passives/dora/*.tres`（10 个被动配置）
- `scripts/resources/character_data.gd` — 新增 passive_pool
- `scripts/core/player_state.gd` — 新增 acquired_passives + 被动效果叠加
- `scripts/core/game_config.gd` — 注册加载被动配置
- 新增 `scripts/ui/passive_selection.gd` — 被动选择 UI
- 新增 `scenes/ui/passive_selection.tscn`
- `scripts/ui/main.gd` — 波间流程增加被动选择步骤

---

## 模块五：角色主动技能（试玩版仅 Dora）

### 设计目标

给战斗增加一个主动操作维度。定位是"关键时刻"按钮 — CD 较长，使用时机是决策。

### Dora — 剑气斩

| 属性 | 值 |
|------|-----|
| 按键 | Space（空格键） |
| CD | 12 秒 |
| 伤害 | 基础攻击力 × 3 |
| 范围 | 面朝方向 90° 扇形，半径 120px（约 3.75 格） |
| 特殊 | 击退范围内所有敌人 |

### 技能系统架构

在 Player 上新增 `ActiveSkillComponent`：

```
class_name ActiveSkillComponent extends Node

signal skill_activated(skill_id: String)
signal skill_ready(skill_id: String)
signal cooldown_updated(remaining: float, total: float)

@export var skill_data: ActiveSkillData
var _cooldown_timer: float = 0.0
var _is_ready: bool = true
```

新增 `ActiveSkillData` Resource：
```
@export var id: String              # "dora_slash"
@export var display_name: String    # "剑气斩"
@export var description: String     # "向前方释放扇形斩击"
@export var cooldown: float         # 12.0
@export var damage_multiplier: float # 3.0
@export var range_radius: float     # 120.0
@export var angle: float            # 90.0（扇形角度，度）
@export var knockback_force: float  # 300.0
@export var icon_path: String
@export var effect_scene_path: String # 斩击特效场景路径
```

### 技能效果实现

1. 玩家按 Space 触发
2. 以玩家面朝方向为中心，90° 扇形区域内的所有敌人受到伤害 + 击退
3. **检测方式**：创建临时扇形 Hitbox Area2D（碰撞层 5 PlayerAttack，掩码层 8 EnemyHurt），存在 1 个物理帧后移除。伤害通过标准 Hitbox/Hurtbox 管线触发，保证命中反馈（音效、闪白、击退）与其他伤害源一致
4. **面朝方向**：使用 `last_movement_direction`（最后一次非零移动方向），静止时保留上一次方向。player.gd 需新增此变量

### 视觉表现

- 释放瞬间：扇形斩击特效（弧形光刃）
- 短暂 hitstop（30ms）
- 屏幕震动（intensity=3.0, duration=0.15s）
- 被击中敌人闪白 + 击退
- 释放音效

### HUD 显示

- 技能图标显示在 HUD 上（屏幕下方或角色旁）
- CD 中显示倒计时遮罩（扇形冷却动画）
- 技能就绪时图标高亮 + 短暂脉冲提示

### 受影响文件

- 新增 `scripts/components/active_skill_component.gd`
- 新增 `scripts/resources/active_skill_data.gd`
- 新增 `resources/skills/dora_slash.tres`
- `scripts/entities/player.gd` — 集成 ActiveSkillComponent，处理 Space 输入
- `scripts/ui/hud.gd` — 新增技能图标 + CD 显示
- `scripts/systems/effects_manager.gd` — 新增斩击特效
- `project.godot` — 新增 "skill_activate" 输入映射（Space）

---

## 模块六：新增 4 种敌人

### 设计目标

让战斗中有策略思考："这种敌人需要用什么方式应对？"

### 敌人设计

#### 远程射手（Ranger）

| 属性 | 值 |
|------|-----|
| HP | 60（比 normal 低） |
| 速度 | 90（较慢） |
| 行为 | 保持距离（150-200px），向玩家射弹 |
| 射弹伤害 | 12 |
| 射弹速度 | 250 |
| 攻击间隔 | 2.0s |
| 经验掉落 | 2 |
| 策略要求 | 玩家需要主动接近消灭，不能一直跑 |

**行为状态机**：
- APPROACH：距离 > 200px 时接近玩家
- ATTACK：距离 150-200px 时停下射击
- RETREAT：距离 < 100px 时后退拉开距离

#### 自爆怪（Bomber）

| 属性 | 值 |
|------|-----|
| HP | 45（脆皮） |
| 速度 | 140（比 normal 快） |
| 行为 | 冲向玩家，靠近后倒计时 1.5 秒爆炸 |
| 爆炸伤害 | 40（高伤害） |
| 爆炸范围 | 80px |
| 经验掉落 | 2 |
| 策略要求 | 倒计时内击杀或拉开距离，考验反应和走位 |

**行为状态机**：
- CHASE：追向玩家
- PRIME：距离 < 50px 时进入倒计时（停止移动，身体闪红 + 膨胀动画）
- EXPLODE：1.5 秒后爆炸，范围伤害。爆炸创建临时 Hitbox Area2D（碰撞层 6 EnemyAttack，掩码层 7 DefenderHurt），自然命中玩家和塔，不命中敌人（碰撞矩阵保证）

#### 分裂怪（Splitter）

| 属性 | 值 |
|------|-----|
| HP | 120（较高） |
| 速度 | 80（慢） |
| 行为 | 直线追玩家，死后分裂成 3 个小怪 |
| 接触伤害 | 15 |
| 小怪 HP | 30 |
| 小怪速度 | 160（快） |
| 小怪伤害 | 8 |
| 经验掉落 | 母体 2 + 小怪各 1 |
| 策略要求 | 打破"先打大的"思维，需要预判分裂后的小怪 |

**实现**：
- 母体死亡时通过 SceneFactory 生成 3 个 `splitter_mini` 敌人
- 小怪向随机方向散开后追玩家
- 小怪是独立敌人实例，计入波次击杀数

> 注意：分裂产生的小怪计入场上存活数但不计入波次 total_enemies。波次过关条件为"所有已生成敌人（含分裂小怪）被击杀"。

#### 护盾怪（Shielder）

| 属性 | 值 |
|------|-----|
| HP | 100 |
| 速度 | 70（慢） |
| 行为 | 正面持盾朝向玩家，正面弹开投射物 |
| 护盾角度 | 面朝方向 120° |
| 接触伤害 | 20 |
| 经验掉落 | 3 |
| 策略要求 | 需要绕到背后攻击，或用近战（不受护盾影响）、击退让其转身 |

**护盾机制**：
- 护盾是视觉 + 逻辑组件（不是额外 HP）
- Hurtbox 上新增方向检测：投射物命中时判断入射方向是否在护盾角度内
- 护盾范围内的投射物被弹开（反弹方向 = 入射方向镜像）不造成伤害
- 近战攻击无视护盾（近战 Hitbox 不走投射物逻辑）
- 击退可以让护盾怪转身，短暂露出背部

### EnemyData 扩展

遵循项目组件化架构，行为相关配置使用**独立的 Behavior Resource**，不在 EnemyData 上堆叠字段：

**EnemyData** 仅新增一个字段：
```
@export var behavior_config: Resource = null  # 行为组件专用配置，null = 默认 chase
```

**各行为的独立配置 Resource**：
```
# RangerBehaviorData
@export var preferred_distance: float = 175.0
@export var retreat_distance: float = 100.0
@export var projectile_data: ProjectileData
@export var attack_interval: float = 2.0

# BomberBehaviorData
@export var explode_radius: float = 80.0
@export var explode_damage: float = 40.0
@export var prime_duration: float = 1.5
@export var prime_trigger_distance: float = 50.0

# SplitterBehaviorData
@export var split_enemy_id: String = "splitter_mini"
@export var split_count: int = 3

# ShielderBehaviorData
@export var shield_angle: float = 120.0
```

这与武器系统中 `AttackConfigData`、`ProjectileData`、`MeleeConfig` 各自独立的模式一致。

### Ranger 投射物碰撞系统

Ranger 的射弹是**敌人侧投射物**，这是一条新的碰撞路径：

- 新增场景 `scenes/entities/projectiles/enemy_arrow.tscn`
- Hitbox 碰撞层：**层 6 (EnemyAttack)**，掩码层：**层 7 (DefenderHurt)**
- 这意味着 Ranger 射弹可以命中玩家和塔（与敌人接触伤害的碰撞路径一致）
- 投射物通过 SceneFactory 创建，注册对象池（Ranger 为中频敌人）
- RangerBehavior 组件通过 `SceneFactory.create_projectile("enemy_arrow")` 创建射弹

### 敌人行为实现

当前 `enemy.gd` 只有单一的追玩家逻辑。需要重构为行为状态机：

- 基础 `enemy.gd` 保留通用逻辑（HP、移动、掉落）
- 行为通过 `behavior_type` 分发到不同的处理方法
- 或者用组件方式：新增 `RangerBehavior`、`BomberBehavior`、`SplitterBehavior`、`ShielderBehavior` 组件

**推荐组件方式**，与现有架构一致：
- 新增 `scripts/components/enemy_behaviors/` 目录
- 每种行为一个组件脚本
- enemy.gd 在 `_ready()` 中检测挂载的行为组件并初始化
- 默认无行为组件 = 原始的 chase 行为

### 新增场景

- `scenes/entities/enemies/ranger.tscn`
- `scenes/entities/enemies/bomber.tscn`
- `scenes/entities/enemies/splitter.tscn`
- `scenes/entities/enemies/splitter_mini.tscn`
- `scenes/entities/enemies/shielder.tscn`

### 新增 Resource 配置

- `resources/enemies/ranger.tres`
- `resources/enemies/bomber.tres`
- `resources/enemies/splitter.tres`
- `resources/enemies/splitter_mini.tres`
- `resources/enemies/shielder.tres`

### SceneFactory 注册

新增敌人类型注册，对象池策略：
- **bomber**：高频，注册对象池（自爆后需频繁重建）
- **splitter_mini**：高频，注册对象池（每个 splitter 产生 3 个）
- **ranger**：中频，注册对象池
- **splitter**：低频，不池化
- **shielder**：低频，不池化
- **enemy_arrow**（Ranger 投射物）：高频，注册对象池

### 波次配置集成

在 `enemy_weights` 中加入新敌人类型：
- 波 3+：引入 ranger
- 波 4+：引入 bomber
- 波 6+：引入 splitter
- 波 7+：引入 shielder
- Boss 波：混合所有类型

---

## 受影响的系统总览

| 系统 | 改动程度 | 说明 |
|------|---------|------|
| WaveData / SpawnPhaseData | **大改** | 字段重新设计 |
| WaveManager | **大改** | 结束条件、修饰词、被动选择流程 |
| EnemySpawner | **大改** | 分批生成、清波加速、修饰词响应 |
| enemy.gd | **中改** | 支持行为组件检测 |
| PlayerProgression | **中改** | 升级属性加成 |
| PlayerState | **中改** | 被动系统、属性叠加 |
| Player | **中改** | 主动技能集成 |
| HUD | **中改** | 击杀计数、技能 CD、修饰词显示 |
| main.gd | **小改** | 波间流程增加被动选择 |
| GameConfig | **小改** | 注册新 Resource 类型 |
| SceneFactory | **小改** | 注册新敌人 |
| EffectsManager | **小改** | 升级特效、技能特效 |
| EventBus | **小改** | 新增信号 |
| 波次 .tres 配置 | **重写** | 12 波全部重新配置 |

## 新增 EventBus 信号

| 信号 | 参数 | 用途 |
|------|------|------|
| `wave_modifier_applied` | `modifiers: Array[WaveModifierData]` | HUD 显示修饰词 |
| `enemy_count_updated` | `killed: int, total: int, alive: int` | HUD 更新击杀计数 |
| `player_leveled_up` | `level: int, bonuses: Dictionary` | 升级特效 + HUD 更新 |
| `passive_selected` | `passive_id: String` | main.gd 流程控制，被动选择完成后进入商店 |
| `skill_activated` | `skill_id: String` | HUD 技能 CD 显示 |
| `skill_cooldown_updated` | `remaining: float, total: float` | HUD 技能 CD 动画 |

## 不在本文档范围内

以下内容将在独立文档中设计：
- **商店/经济重做** — 差异化定价、构建路线、有意义的选择
- **打击感/Juice 升级** — hitstop、连杀可视化、音效层次、粒子特效
- **内容扩充** — 新武器、新塔、新角色
- **系统功能** — 存档、Steam SDK、新手引导

## 实现优先级建议

建议按以下顺序实现各模块（依赖关系）：

1. **波次系统改为分批清敌制**（基础，其他模块依赖波次结构）
2. **新增 4 种敌人**（丰富战斗内容，可与波次系统并行）
3. **升级即时属性提升**（独立模块，可并行）
4. **角色主动技能**（独立模块，可并行）
5. **被动自由池系统**（依赖波间流程改动）
6. **波次修饰词系统**（最后，依赖波次系统和新敌人都就绪）
