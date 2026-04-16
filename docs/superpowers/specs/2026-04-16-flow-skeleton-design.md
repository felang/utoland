# utoland 战斗体验重塑 — #1 流程骨架重构 设计文档

- **日期**: 2026-04-16
- **状态**: 已批准,待写实施计划
- **子项目顺位**: 大重构 7 个子项目中的 #1

---

## 1. 背景与目标

utoland 正在从"射击 + 自走棋商店"融合模式,重构为"类幸存者 + 塔防"融合玩法(参见 `/Users/langtao/uto-wiki/game_design.md`)。

整体重构规模极大,按依赖关系分 7 个子项目依次落地:

1. **流程骨架**(本文档)
2. 英雄系统(游侠切片)
3. 塔耐久 + 拆塔者
4. 地图改造
5. 5 种敌人 + 20 波
6. 羁绊系统 + 塔池扩展
7. 其它 5 英雄

**#1 的目标**:打通新的核心玩法循环,使游戏可以用新流程跑通 15 波,为后续子项目搭好基础架构。

**#1 明确不做的事**(下沉到后续子项目):

- 武器系统改造为英雄技能(留给 #2)
- 塔耐久 / 拆塔者(留给 #3)
- 新地图 / 新敌人 / 20 波(留给 #4/#5)
- 羁绊系统 / 塔池扩展到 30-40 座(留给 #6)
- 其它英雄(留给 #7)

---

## 2. 保留 / 改 / 新增 总览

| 模块 | 处置 |
|---|---|
| 武器系统(bow/shuriken/sword) | 保留架构,仅追加 perk 加成字段读取 |
| 武器 2 合 1 合成 | 保留 |
| 敌人、15 波配置、难度缩放 | 保留 |
| 32px 网格、地图、渲染分层 | 保留 |
| 金币 / 经验 / 人口系统 | 保留底层 |
| Phase 状态机(SHOP / BATTLE) | **移除**,常态 BATTLE |
| ShopOverlay 商店卡片 + 刷新 / 开战 / 回收区 | **移除** |
| 武器装备栏 + 金币 / 等级 / 人口 / 波次 信息栏 | **保留**,从 ShopOverlay 迁入战斗 HUD 常驻 |
| 波次固定奖励 10g | **移除**,金币全靠敌人掉 + 塔生成 |
| 4 张塔商店卡片 | **移除**,改为 Roll 按钮 + 待建造栏 |
| 升级(自动升人口) | **改造**,升级时弹 3 选 1 暂停面板 |
| Roll 塔机制 | **新增** |
| 塔池 Tier 分层 + 动态权重 | **新增**(#1 阶段仅搭框架) |
| 通用占位 perk 池 | **新增**(6-8 个) |

---

## 3. 核心玩法流程

### 3.1 单局流程

```
start_menu → character_selection → map_select → main (BATTLE 常态)
  战斗中,玩家随时:移动 / 自动攻击 / Roll 塔 / 拖拽放置 / 点塔菜单 / 升级 3 选 1
  每波:敌人刷新 → 时间到 → 清场 → N 秒缓冲(不刷怪,其它正常) → 下一波
  15 波通关 或 英雄阵亡 → result
```

### 3.2 关键交互节拍

- **Roll 塔**:战斗中随时触发,花 3 金币,不中断战斗
- **放置塔**:从待建造栏拖到地图,不中断战斗
- **点击已部署塔**:弹浮窗(卖出 / 移动),不中断战斗
- **升级 3 选 1**:英雄升级瞬间**暂停游戏**,选完后继续 —— 整个单局**唯一**的暂停点
- **波次间缓冲**:不暂停,N 秒不刷怪,所有玩家操作继续可用

---

## 4. Roll 塔机制

### 4.1 交互

- Roll 按钮位于战斗 HUD 底部中央,显示当前费用 `(3g)`
- 点击 Roll:扣 3 金币 → 弹 3 选 1 塔卡片面板(不暂停)→ 玩家点一张 → 卡片进入待建造栏 → 面板关闭
- **取消** 3 选 1 面板:退还 3 金币(避免误点锁死体验)
- **待建造栏**:3 槽,满时 Roll 按钮禁用并提示"栏满"
- **放置**:拖拽栏中卡片到地图,松手落下为塔;复用 `DragManager.PLACE_TOWER` 模式,放置来源从商店卡片改为待建造栏

### 4.2 塔池与抽卡逻辑

**数据结构**:

- `TowerData.tier: int` 字段(取值 1–4)
- #1 阶段 3 座塔(pea_shooter / ice_flower / sunflower)均填 `tier = 1`

**抽卡流程**(每次 Roll 抽 3 张):

1. 根据**英雄当前等级**查 Tier 概率表,确定抽每张卡时各 Tier 的权重
2. 在选定 Tier 内,按 `基础权重 × 动态权重` 抽出一座塔
3. 3 张可重复(同一次 Roll 可以 3 张同塔,便于合成)

**动态权重**(对抗"池子大难合成"问题):

- 玩家已部署塔中,若存在同 `id` 且同 `level` 的**非满级**塔,则抽卡时该塔的权重 `× dynamic_weight_multiplier`(默认 1.5)
- Lv3(满级)塔不再加权
- #1 阶段 3 座塔均 Tier 1 / 均匀基础权重,动态加权的实际效果要到 #6 塔池扩展后才真正显现,但代码框架要到位

**Tier 概率表(#1 默认值,存于 `resources/shop/tier_weight_table.tres`)**:

| 英雄等级 | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---|---|---|---|
| 1–2 | 100% | 0% | 0% | 0% |
| 3–5 | 75% | 25% | 0% | 0% |
| 6–9 | 50% | 35% | 15% | 0% |
| 10+ | 30% | 40% | 20% | 10% |

(#1 阶段全部塔都 Tier 1,表写好但实际只命中 Tier 1 行;#6 扩塔池后真正激活)

### 4.3 合成

- 沿用现有 `InventoryManager._check_merge` 的 2 合 1 合成(同 id + 同 level → level + 1)
- 最高 Lv3
- 递归合成(Lv1 合到 Lv2 后,若再凑两个 Lv2 立刻合 Lv3)

---

## 5. 升级 3 选 1 Perk 系统

### 5.1 触发时机与交互

- `PlayerProgression.add_exp()` 导致等级提升 → `EventBus.player_level_up(new_level)` 信号
- `PerkManager` 监听信号,从通用 perk 池随机抽 3 个(不重复)
- 弹出 `PerkSelectionOverlay`,设置 `get_tree().paused = true`
- 面板 `process_mode = ALWAYS`,不受暂停影响
- 玩家点选一张 → 应用效果 → 关闭面板 → `paused = false`

### 5.2 通用 Perk 池(#1 阶段 6-8 个)

| id | 显示名 | 效果 |
|---|---|---|
| vitality | 强健 | 最大生命 +10% |
| swift | 疾行 | 移速 +10% |
| power | 强攻 | 武器伤害 +10% |
| rapid | 迅疾 | 武器攻速 +10% |
| reach | 磁石 | 拾取范围 +30% |
| greed | 贪婪 | 金币掉落 +10% |
| study | 领悟 | 经验获取 +10% |
| expansion | 扩张 | 人口上限 +1 |

Perk 效果**永久**生效到本局结束。

### 5.3 效果应用方式

**决定**:通过 `PlayerState.player_stats` 字典作为 source of truth,perk 效果在选中时累加到对应字段,各消费方(WeaponManager / Player / Enemy / ExpOrb 拾取)读取该字段。

**不使用**信号广播式应用(避免散落的副作用和时序问题)。

### 5.4 多次升级排队

极端情况下(升级瞬间另一个敌人死亡再触发升级)可能出现叠升。`PerkManager` 内部队列化,面板关闭时检查队列,若有待处理升级立刻再弹一次。

---

## 6. UI 改造

### 6.1 战斗 HUD 新布局

```
顶部信息栏:金币 | 等级 + 经验条 | 人口 x/y | 波次 N + 倒计时
左侧:武器装备栏(3 槽,点击弹菜单:合成/卖出)    ←  从 ShopOverlay 迁入
底部中央:Roll 按钮 (3g) + 待建造栏 3 槽
中心弹窗(仅升级时):3 选 1 perk 面板(暂停游戏)
塔身浮窗(仅点塔时):卖出 / 移动
```

### 6.2 ShopOverlay 拆解策略

**决定**:不做渐进式迁移,直接**整块重写**为新组件 `BattleHUD`(或扩展现有 `HUD`)。

理由:ShopOverlay 当前耦合了商店卡片、刷新、开战、装备栏、回收区、信息栏等多重职责,去掉"商店"部分后剩下的职责和 HUD 高度重合,渐进式迁移反而会留下历史代码负担。

**迁入 HUD 常驻**:

- 武器装备栏(含点击菜单合成 / 卖出)
- 金币 / 等级 / 人口 / 波次 信息栏

**移除**:

- 4 张塔商店卡片
- 刷新按钮
- 开战按钮
- 回收拖拽区

**新增(常驻 HUD 元素)**:

- Roll 按钮 + 待建造栏(底部中央)
- 3 选 1 perk 暂停弹窗
- 塔身浮窗菜单

### 6.3 点击已部署塔浮窗

- 鼠标点击塔 → 浮动菜单(定位到塔上方):
  - **卖出**:返还总投入的 70%(Lv1 = 1 张卡,Lv2 = 2 张卡价值,Lv3 = 4 张卡价值)
  - **移动**:进入 MOVE_TOWER 模式
- 合成为自动触发,**无**独立升级按钮

---

## 7. 经济调整

- `ShopConfig.wave_reward` 逻辑删除(字段保留置 0 以防数据文件不兼容,但不使用)
- 金币来源:敌人死亡掉落(`EnemyData.coin_drop`)+ 向日葵塔生成
- Roll 费用:固定 3 金币 / 次
- 卖出返还:**70%**(文档数值,调整现有 `sell_price_per_level` 或新增卖出公式)
- 初始金币:不变(100 + 角色 bonus)

---

## 8. 模块改动清单

### 8.1 需改的现有文件

| 文件 | 改动 |
|---|---|
| `scripts/ui/main.gd` | 移除 `Phase` 状态机,常态 BATTLE |
| `scripts/ui/shop_overlay.gd` + `.tscn` | 整块重写为新 HUD 组件(见 §6.2) |
| `scripts/systems/shop_manager.gd` | 整块重写为新 `TowerRollManager`(RefCounted),职责:塔池加载、Tier 抽卡、动态权重、pending 队列 |
| `scripts/core/inventory_manager.gd` | 新增 `pending_towers: Array` + `roll_tower()` / `consume_pending(idx)` / `cancel_pending()` API |
| `scripts/ui/hud.gd` | 接管信息栏 + 挂装备栏 + Roll 按钮 + 待建造栏 UI |
| `scripts/systems/wave_manager.gd` | 删除波次固定奖励发放 |
| `scripts/systems/drag_manager.gd` | `PLACE_TOWER` 放置来源改为待建造栏 |
| `scripts/core/player_progression.gd` | 升级时触发 `EventBus.player_level_up(level)`;`get_population_cap()` 加上 `population_bonus`;`add_exp()` 乘 `exp_gain_bonus_percent` |
| `scripts/entities/player.gd` | 最大生命应用 `hp_bonus_percent`;移速应用 `move_speed_bonus_percent`;拾取半径应用 `pickup_radius_bonus_percent` |
| `scripts/entities/enemy.gd` | 掉金币时乘 `(1 + coin_drop_bonus_percent)` |
| `scripts/components/ranged_attack_component.gd` | 伤害/攻速时读 `damage_bonus_percent` / `attack_speed_bonus_percent` |
| `scripts/components/melee_attack_component.gd` | 伤害/攻速时读 `damage_bonus_percent` / `attack_speed_bonus_percent` |
| `scripts/resources/tower_data.gd` | 新增 `tier: int = 1` 字段 |
| `resources/towers/*.tres` | 所有塔配置填 `tier = 1` |
| `scripts/resources/shop_config.gd` | 字段精简:删除 `slot_count` / `refresh_cost` / `level_up_*` / `wave_reward`(或置 0);新增 `roll_cost: int = 3` / `pending_queue_size: int = 3` / `dynamic_weight_multiplier: float = 1.5` / `sell_return_ratio: float = 0.7` |
| `scripts/core/event_bus.gd` | 新增信号(见 §8.4) |
| `project.godot` | 新增 Autoload `PerkManager` |

### 8.2 新增文件

| 文件 | 用途 |
|---|---|
| `scripts/resources/perk_data.gd` | Perk Resource 类 |
| `resources/perks/*.tres` × 6-8 | 通用 perk 配置 |
| `scripts/core/perk_manager.gd`(Autoload) | perk 池加载、随机抽取、效果应用、状态持有 |
| `scripts/ui/perk_selection_overlay.gd` + `.tscn` | 升级 3 选 1 暂停弹窗 |
| `scripts/ui/tower_roll_overlay.gd` + `.tscn` | Roll 时弹出的 3 选 1 塔卡片面板 |
| `scripts/ui/pending_queue_panel.gd` + `.tscn` | 待建造栏 UI |
| `scripts/ui/tower_popup_menu.gd` + `.tscn` | 点击已部署塔的浮窗菜单 |
| `scripts/systems/tower_roll_manager.gd` | Roll 核心逻辑(替代 ShopManager) |
| `scripts/resources/tier_weight_table.gd` + `resources/shop/tier_weight_table.tres` | Tier 概率表 |

### 8.3 Autoload 变更

**新增** `PerkManager`,加载顺序紧随 `SceneManager`:

```
GameConfig → PlayerState → PlayerProgression → InventoryManager → StatsTracker
  → SceneFactory → EffectsManager → AudioManager → EventBus → SceneManager
  → PerkManager
```

### 8.4 EventBus 新增信号

```gdscript
signal player_level_up(new_level: int)
signal perk_offered(perks: Array)          # 3 个 PerkData
signal perk_selected(perk_id: String)
signal tower_rolled(candidates: Array)     # 3 个候选塔 id
signal tower_added_to_queue(tower_id: String)
signal tower_consumed_from_queue(index: int)
signal tower_roll_canceled()
```

### 8.5 现有信号沿用

- `item_merged` / `tower_moved` / `coins_changed` / `enemy_killed` / `wave_started/completed` 等继续使用
- `item_purchased` / `item_sold` 保留(武器合成 / 卖出仍走这里)

---

## 9. 数据模型变更

### 9.1 TowerData 扩展

```gdscript
@export var id: String
@export var display_name: String
@export var tier: int = 1                  # 新增
# ... 其它字段不变
```

### 9.2 PlayerState.player_stats 新增键

perk 效果累加到如下字段(百分比字段为小数,`0.1` 表示 10%):

```
hp_bonus_percent: float = 0.0
move_speed_bonus_percent: float = 0.0
damage_bonus_percent: float = 0.0
attack_speed_bonus_percent: float = 0.0
pickup_radius_bonus_percent: float = 0.0
coin_drop_bonus_percent: float = 0.0
exp_gain_bonus_percent: float = 0.0
population_bonus: int = 0
```

消费方示例:

- `Player` 读取 `move_speed_bonus_percent` 计算最终 `move_speed`
- `WeaponManager` 读取 `damage_bonus_percent` / `attack_speed_bonus_percent`
- `PlayerProgression.get_population_cap()` 加上 `population_bonus`
- 金币 / 经验掉落由 `EnemyData` 的基础值 × 对应 bonus 系数

### 9.3 PerkData

```gdscript
class_name PerkData extends Resource

enum EffectType {
    HP_PERCENT,
    MOVE_SPEED_PERCENT,
    DAMAGE_PERCENT,
    ATTACK_SPEED_PERCENT,
    PICKUP_RADIUS_PERCENT,
    COIN_DROP_PERCENT,
    EXP_GAIN_PERCENT,
    POPULATION_FLAT,
}

@export var id: String
@export var display_name: String
@export var description: String
@export_file("*.png") var icon_path: String
@export var effect_type: EffectType
@export var effect_value: float
```

### 9.4 TierWeightTable

```gdscript
class_name TierWeightTable extends Resource

# Array[Dictionary],索引为等级区间配置
# { "level_min": int, "level_max": int, "weights": Array[float] (长度 4) }
@export var entries: Array = []
```

---

## 10. 错误与边界处理

- **Roll 金币不足**:按钮禁用,不响应点击
- **待建造栏已满**:按钮禁用,提示"栏满"
- **取消 3 选 1 塔卡片**:退还 3 金币
- **升级 3 选 1 面板打开时切场景或结束游戏**:#1 简化 —— 不持久化选择进度,下次开局重置
- **多次升级同时触发**:PerkManager 队列化,依次弹窗
- **放置塔时地图没有合法位置**:松手到非法位视为取消,卡片返回待建造栏(复用现有 DragManager 逻辑)
- **Perk id 找不到**:记录 warning,不崩溃

---

## 11. 测试策略

### 11.1 单元测试(`tests/unit`)

- `test_tower_roll_manager.gd`:Tier 概率分布、动态权重加成、3 张可重复、pending 队列
- `test_perk_manager.gd`:随机抽 3 个不重复、perk 效果累加到 player_stats、队列化多次升级
- `test_inventory_manager.gd` 扩展:pending_towers 满 / 消费 / 取消 场景
- `test_player_progression.gd` 扩展:升级时发射 `player_level_up` 信号

### 11.2 集成测试(`tests/integration`)

- battle 开始 → 拾取经验球升级 → perk 面板弹出 → 选择后效果生效(验证 hp / 移速等字段被修改)→ 游戏继续
- Roll 3 次 → 栏满 → 按钮禁用 → 放置一个 → 可再 Roll
- 点击已部署塔 → 卖出 → 金币返还 70%,塔消失
- 波次间:不暂停、不刷怪、可正常 Roll / 放置 / 卖出

### 11.3 手工验证(Godot 编辑器)

- 完整 15 波跑通(现有 3 座塔 + 现有武器)
- 升级暂停面板 UI 表现(布局、焦点、暂停恢复无 bug)
- 拖拽放置无回归(PLACE_TOWER 原交互不破)
- 战斗流畅度感受(无 SHOP 模式切换的节奏感)

---

## 12. 风险与后续衔接

### 12.1 风险

- **经济重平衡**:去掉 10g 固定奖励 + 新 Roll 成本,前期金币可能极度紧缺。首次可玩版本需要多轮调参(敌人掉落量 / 向日葵速率 / Roll 成本)
- **ShopOverlay 拆解工作量**:当前文件耦合商店、装备栏、信息栏三块职责,整块重写工程量中等偏大
- **DragManager 变更**:放置来源切换到待建造栏,要保证 MOVE_TOWER 依然工作(pending 卡片拖拽 vs 已部署塔拖拽的状态区分)
- **InventoryManager 职责膨胀**:加 pending_towers 可能让这个类继续变胖;实施计划中若觉得超重,可拆出 `TowerInventory` 专管,但非必须

### 12.2 与后续子项目的衔接点

- **#2 游侠切片**:WeaponManager 将在 #2 替换为英雄三技能(疾风箭 / 箭雨 / 猎杀标记),perk 池扩为游侠专属选项池。本子项目保持武器系统原封不动以降低风险
- **#3 塔耐久 + 拆塔者**:点塔浮窗在 #3 增加"修复"按钮;本子项目的浮窗 UI 需为后续扩展留出接口;拆塔者 AI 重新接回 `ATTACK_TOWER` 状态
- **#6 羁绊 + 塔池扩展**:本文档定义的 Tier 概率表 + 动态权重系统正是为 #6 准备,届时扩到 30-40 座塔,Tier 1–4 各档位真正生效;每座塔配两个羁绊标签的字段在 #6 新增
