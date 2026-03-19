# 资源系统重设计

> 日期：2026-03-19
> 状态：设计中

## 1. 设计目标

1. **金币与战斗解耦** — 敌人数量可自由设计（支持后期怪海），不受经济平衡约束
2. **三资源各司其职** — 经验=战斗奖励→人口，金币=策略资源→装备，人口=部署约束
3. **升级即时有感** — 升级不只加人口，还有属性成长和角色被动进化
4. **角色差异化** — 不同角色的升级体验截然不同（本期只做 Dora）

## 2. 三资源模型

```
经验（击杀获得）
  └─→ 升级
       ├─→ +1 人口（策略层，在商店阶段使用）
       ├─→ 基础属性微涨（战斗层，即时感受）
       └─→ 角色被动进化 Lv4/Lv7（差异化的 power spike）

金币（波次奖励 + 向日葵 + Boss 赏金）
  ├─→ 买武器/塔（3 金/件）
  └─→ 刷新商店（2 金/次）

人口（仅来自经验等级）
  └─→ 限制武器 + 塔的总部署数
```

### 与当前系统的关键差异

| 项目 | 当前 | 调整后 |
|---|---|---|
| 敌人掉金币 | 代码存在但未启用 | **删除**（敌人只掉经验球） |
| 金币买升级 | 有（`buy_level_up`） | **删除**（人口只来自经验升级） |
| 升级奖励 | 仅 +1 人口 | +1 人口 + 基础属性 + 被动进化 |
| 初始金币 | 100 + 角色 bonus | **40** + 角色 bonus（缩小） |
| 波次奖励 | 固定 10 金 | **分段递增**（5/8/10） |
| 向日葵产出 | 5金/10s ~ 12金/6s | **适度削弱** |
| 经验曲线 | n^2.0 | **n^1.6**（缓和后期） |

## 3. 金币经济

### 3.1 收入来源

#### 波次奖励（主要稳定收入）

| 波次 | 每波奖励 | 小计 |
|---|---|---|
| 1-5 | 5 金 | 25 金 |
| 6-10 | 8 金 | 40 金 |
| 11-15 | 10 金 | 50 金 |
| **合计** | | **115 金** |

实现方式：`ShopConfig` 新增 `wave_reward_tiers: Array[Dictionary]`，或在 `main.gd` 中根据波次号分段计算。

#### Boss 赏金（唯一的击杀→金币通道）

| Boss | 波次 | 赏金 |
|---|---|---|
| boss_brute | 5 | 15 金 |
| boss_summoner | 10 | 20 金 |
| boss_guardian | 15 | 30 金 |

触发方式：监听 `EventBus.boss_killed` 信号，直接加金币（不是物理掉落）。Boss 未击杀（逃跑）则无赏金，这给 Boss 战增加经济动力。

三次 Boss 赏金合计：**65 金**（需要实际击杀才能拿到）。

#### 向日葵（投资型收入）

| 等级 | 当前 | 调整后 | 产出率 |
|---|---|---|---|
| Lv1 | 5金/10s | **3金/12s** | 0.25 金/s |
| Lv2 | 8金/8s | **5金/10s** | 0.5 金/s |
| Lv3 | 12金/6s | **8金/8s** | 1.0 金/s |

设计意图：
- Lv1 向日葵投入 3 金 + 1 人口，12s 产 3 金，**回本需 48s（约一整波）**
- 投资有真实风险（前期少一个战斗单位），但长期回报可观
- Lv3 向日葵 1金/s，90s 波次能产 90 金 — 依然强力，但需要投入 4 次购买(12金)+2次合成等待

#### 装备卖出（回收）

保持不变：Lv1=3金, Lv2=7金, Lv3=21金。

### 3.2 支出项目

| 支出 | 费用 | 备注 |
|---|---|---|
| 买武器/塔 | 3 金 | 统一价格，策略在于"买什么" |
| 刷新商店 | 2 金 | 寻找合成素材的主要金币 sink |
| ~~买升级~~ | ~~4+(n-1)×2~~ | **删除** |

### 3.3 初始金币

| 项目 | 当前 | 调整后 |
|---|---|---|
| 基础 | 100 | **40** |
| Dora bonus | +30 | **+10** |
| Dora 合计 | 130 | **50**（+ 自带一把剑） |

50 金足够：买 2 件物品(6金) + 3 次刷新(6金) 后还剩 38 金应对前几波。其他角色 bonus 待后续设计时调整。

### 3.4 经济模拟（Dora 典型路线）

假设中等操作水平，15 波全程：

| 阶段 | 波次奖励 | Boss 赏金 | 向日葵(1个Lv1,Wave3起) | 合计收入 |
|---|---|---|---|---|
| 初始 | — | — | — | 50 金 |
| W1-5 | 25 | 15 | ~15 (3波×3金×~1.5次) | ~105 |
| W6-10 | 40 | 20 | ~40 (5波×avg 8金) | ~205 |
| W11-15 | 50 | 30 | ~55 (5波×avg 11金) | ~340 |

**总收入约 340 金**。

典型支出：
- 升级到 Lv7 的装备：~12 次购买 = 36 金
- 刷新寻找合成素材：~15 次 = 30 金
- 总核心支出：~66 金

剩余 ~274 金看起来很多，但实际消耗在：
- 更多刷新（追求 Lv3 合成需要精确匹配，可能刷 30+ 次 = 60 金）
- 更多购买（尝试不同阵容、买了卖掉换方向）
- 向日葵本身的购买成本（3金 + 1人口）

**关键：金币 sink 主要是"刷新"**。与自走棋一致——你知道收入多少，纠结的是花在哪里。

## 4. 经验系统

### 4.1 经验曲线调整

| 参数 | 当前 | 调整后 |
|---|---|---|
| `base_exp` | 5.0 | **5.0**（不变） |
| `exp_exponent` | 2.0 | **1.6** |

升级所需经验对比：

| 等级 | 当前 (n^2) | 调整后 (n^1.6) | 累计(调整后) |
|---|---|---|---|
| Lv2 | 20 | 15 | 15 |
| Lv3 | 45 | 27 | 42 |
| Lv4 | 80 | 42 | 84 |
| Lv5 | 125 | 60 | 144 |
| Lv6 | 180 | 80 | 224 |
| Lv7 | 245 | 103 | 327 |
| Lv8 | 320 | 128 | 455 |
| Lv9 | 405 | 155 | 610 |

### 4.2 经验来源

**仅**来自敌人掉落的经验球（拾取获得）。

敌人经验掉落值（调整后）：

| 敌人 | 经验球数量 | 每球经验值 | 备注 |
|---|---|---|---|
| normal | 1 | 1 | 基础来源 |
| fast | 1 | 1 | 量多补偿单价低 |
| tank | 1-2 | 1 | 高血量对应更多奖励 |
| elite | 基础 ×2 | 1 | 精英明显更值得打 |
| boss_brute | 8-10 | 1 | 经验大奖 |
| boss_summoner | 10-12 | 1 | |
| boss_guardian | 12-15 | 1 | |

> 经验球每球固定 1 点经验。数量由 `exp_drop_min/max` 控制。后续可引入经验球大小变体（大球=多点经验），但当前保持简单。

### 4.3 预期升级节奏

基于后续波次设计（此处粗估），典型游戏中玩家升级节奏：

| 波次 | 预期等级 | 人口上限 | 阵容规模 |
|---|---|---|---|
| 1-3 | Lv1→2 | 2→3 | 1-2 武器 + 1 塔 |
| 4-5 | Lv3→4 | 4→5 | 被动进化 Tier 2 |
| 6-9 | Lv4→6 | 5→7 | 2-3 武器 + 3-4 塔 |
| 10-12 | Lv6→7 | 7→8 | 被动进化 Tier 3 |
| 13-15 | Lv7→9 | 8→10 | 满配，多个 Lv3 |

具体经验掉落数值将在波次系统设计时精确调整，确保上述节奏。

## 5. 升级奖励

### 5.1 每级通用成长

所有角色升级时获得：

| 奖励 | 数值 | 说明 |
|---|---|---|
| +1 人口 | 固定 | 策略层核心 |
| +3% 最大生命 | 复利 | Lv9 时 +27% HP |
| +2% 移动速度 | 复利 | Lv9 时 +17% 移速 |
| +5% 拾取范围 | 复利 | Lv9 时 +48% 范围 |

通用成长幅度刻意偏小——真正的差异化来自角色被动进化。

实现方式：`PlayerProgression` 升级时 emit 信号，`player.gd` 监听并应用属性修正。或在 `player_stats` 字典中维护等级加成。

### 5.2 角色被动进化（Dora）

#### Dora · 剑圣

**核心幻想**：以战养战的近战剑客，越打越强越能活。

当前被动 `fortify_regen`（2% HP/5s，3塔翻倍）→ **替换为三阶进化系统**。

| 阶段 | 触发 | 效果 | 体感 |
|---|---|---|---|
| **Tier 1** | Lv1（开局） | 自带一把剑；近战武器伤害 +10% | 开局即有战斗力，近战定位明确 |
| **Tier 2** | Lv4 | 近战伤害 +20%，近战攻速 +10% | 砍怪节奏明显加快，DPS 跃升 |
| **Tier 3** | Lv7 | 近战伤害 +30%，攻速 +20%，击杀敌人回复 1 HP | 冲入怪海以战养战 |

**数值说明**：
- 伤害/攻速加成作用于所有**近战类型武器**（目前只有 sword），通过 `player_stats` 传递给 `WeaponManager`/`MeleeAttackComponent`
- 击杀回复 1 HP：监听 `EventBus.enemy_killed`，每次击杀固定回复 1 点 HP（不受其他加成影响）
- Tier 之间是**替换**关系（Tier 2 的 +20% 包含 Tier 1 的 +10%），不是叠加

**"自带一把剑"保留**：Dora 的 `starting_weapon: "sword"` 不变，这把剑占 1 人口。

#### 其他角色（占位，待后续设计）

| 角色 | 定位 | Tier 1 方向 | 备注 |
|---|---|---|---|
| Kaze | 高机动拾取 | 移速加成 | 后期闪避 + 超大拾取范围 |
| Nemo | 前排坦克 | 生命/减伤 | 后期塔增益光环 |
| Gorg | 重装战士 | 高 HP，移速惩罚 | 后期惩罚消除 + 减伤 |
| Merlin | 资源大师 | 拾取范围 | 后期经验加成 + 向日葵增益 |

### 5.3 被动进化的数据结构

新增 Resource：`PassiveEvolutionData`

```gdscript
class_name PassiveEvolutionData
extends Resource

@export var passive_id: String = ""

# 三阶进化配置，每阶一个 Dictionary
# 键: "melee_damage_mult", "melee_attack_speed_mult", "kill_heal", 等
@export var tier_1: Dictionary = {}  # Lv1 生效
@export var tier_2: Dictionary = {}  # Lv4 生效（替换 tier_1）
@export var tier_3: Dictionary = {}  # Lv7 生效（替换 tier_2）

@export var tier_2_level: int = 4
@export var tier_3_level: int = 7

func get_tier_for_level(level: int) -> Dictionary:
    if level >= tier_3_level:
        return tier_3
    elif level >= tier_2_level:
        return tier_2
    else:
        return tier_1
```

Dora 的 `.tres` 示例值：

```
tier_1 = { "melee_damage_mult": 1.1 }
tier_2 = { "melee_damage_mult": 1.2, "melee_attack_speed_mult": 1.1 }
tier_3 = { "melee_damage_mult": 1.3, "melee_attack_speed_mult": 1.2, "kill_heal": 1.0 }
```

## 6. 人口系统

### 不变的部分

- 公式：`initial_population + (level - 1) * population_per_level`
- `initial_population = 2`，`population_per_level = 1`
- 武器和塔各占 1 人口

### 变化的部分

- **删除 `buy_level_up`**：人口只来自经验升级，金币不能买等级
- **删除 `ShopConfig` 中的 `level_up_base_cost` 和 `level_up_cost_increment`**
- **删除 `ShopManager.buy_level_up()` 方法**
- **删除 ShopOverlay 中的升级按钮 UI**

这使得人口完全由战斗表现（经验拾取效率）决定，金币完全用于装备决策。两个资源的用途不再重叠。

## 7. 需要的代码改动

### 7.1 删除/修改

| 文件 | 改动 |
|---|---|
| `enemy.gd` | 删除 `_drop_coins()` 方法（确认不再需要） |
| `enemy_data.gd` | 删除 `coin_drop_min/max` 字段 |
| `resources/enemies/*.tres` | 删除 coin_drop 相关行 |
| `player_progression.gd` | 删除 `buy_level_up()` 方法 |
| `shop_manager.gd` | 删除 `buy_level_up()` 方法 |
| `shop_config.gd` | 删除 `level_up_base_cost`、`level_up_cost_increment`、`get_level_up_cost()` |
| `shop_overlay.gd` | 删除升级按钮及相关 UI |
| `game_config.gd` | `initial_coins` 从 100 改为 40 |
| `resources/shop/shop_config.tres` | `wave_reward` 改为基础值 5（分段逻辑在代码中） |

### 7.2 修改

| 文件 | 改动 |
|---|---|
| `exp_config.tres` | `exp_exponent` 从 2.0 改为 1.6 |
| `resources/characters/dora.tres` | `starting_gold` 从 30 改为 10 |
| `resources/towers/sunflower.tres` | GeneratorConfig 按新数值调整 |
| `main.gd` | 波次奖励改为分段计算（Wave 1-5: 5金, 6-10: 8金, 11-15: 10金） |
| `main.gd` | 新增监听 `EventBus.boss_killed` → 发放 Boss 赏金 |

### 7.3 新增

| 文件 | 说明 |
|---|---|
| `scripts/resources/passive_evolution_data.gd` | 被动进化 Resource 类 |
| `resources/passives/dora_sword_saint.tres` | Dora 被动进化数据 |
| `player.gd` 改造 | 升级时应用通用属性成长 + 被动进化阶段检查 |
| `player_progression.gd` 改造 | 升级时 emit 更详细的信号（携带新等级） |

### 7.4 波次奖励实现

在 `main.gd::_enter_shop_phase()` 中，将固定 `wave_reward` 替换为分段计算：

```gdscript
func _get_wave_reward() -> int:
    var wave: int = PlayerState.current_wave
    if wave <= 5:
        return 5
    elif wave <= 10:
        return 8
    else:
        return 10
```

### 7.5 Boss 赏金实现

在 `main.gd` 中监听 Boss 击杀信号：

```gdscript
# Boss 赏金表
const BOSS_BOUNTY: Dictionary = {
    "boss_brute": 15,
    "boss_summoner": 20,
    "boss_guardian": 30,
}

func _on_boss_killed(boss_id: String) -> void:
    var bounty: int = BOSS_BOUNTY.get(boss_id, 0)
    if bounty > 0:
        InventoryManager.coins += bounty
        EventBus.coins_changed.emit(bounty, InventoryManager.coins)
```

## 8. 调参杠杆

设计后如果测试中觉得太松或太紧，优先调以下参数：

| 杠杆 | 调松 | 调紧 | 影响范围 |
|---|---|---|---|
| 初始金币 | +10 | -10 | 前 1-2 波购买力 |
| 波次奖励 | 各段 +2 | 各段 -2 | 全局收入节奏 |
| Boss 赏金 | +5~10 | -5~10 | Boss 战动力 |
| 向日葵产出 | +1金/次 | -1金/次 | 投资路线强度 |
| 经验指数 | 降为 1.4 | 升为 1.8 | 升级速度/人口 |
| 通用成长幅度 | 各项 +1% | 各项 -1% | 后期角色强度 |
| 被动进化等级 | Tier2→Lv3 | Tier2→Lv5 | Power spike 节奏 |

## 9. 不在本次范围内

- 其他角色（Kaze/Nemo/Gorg/Merlin）的被动进化设计
- 敌人数值和波次系统重设计（将基于本文档另行设计）
- 合成系统调整（保持当前 2 合 1 机制不变）
- 新增物品定价差异化（保持统一 3 金）
