# 自走棋式经济系统重构设计

## 概述

将现有的"升级弹窗 + 布置分离"系统重构为自走棋（金铲铲）式的"商店 + 背包 + 地图布置一体化"系统。核心变更：去除金币与经验绑定，引入商店购买机制、背包系统、三合一合成、人口等级系统。

## 1. 游戏流程变更

### 新流程

```
start_menu → character_selection → map_select → shop（首次，用初始金币购买）
    ↓ 点击"开始战斗"
  main（战斗，拾取金币积累） → 波次结束 → shop（自动刷新商店）
    ↓ 点击"开始战斗"
  main（下一波战斗） → ... → result
```

### 删除的系统

- `upgrade_popup` — 升级弹窗场景和脚本
- `upgrade_generator.gd` — 升级选项生成器
- `placement.tscn` + `placement.gd` + `placement_panel.gd` — 布置场景（功能合并到 shop）
- XP/经验值与金币绑定机制
- `pending_upgrades` 概念

### 新增的系统

- `shop.tscn` + `shop.gd` — 商店场景（商店 + 背包 + 装备 + 地图布置一体化）
- `ShopConfig` Resource — 商店配置数据
- `ShopManager` — 商店逻辑（物品池生成、刷新、购买、卖出）
- 合成系统（自动三合一）
- 人口等级系统

## 2. 人口等级系统

### 等级进度表

| 等级 | 人口上限 | 升级费用 | 累计投入 |
|------|---------|---------|---------|
| Lv1（初始） | 2 | — | 0 |
| Lv2 | 3 | 4 | 4 |
| Lv3 | 4 | 8 | 12 |
| Lv4 | 5 | 12 | 24 |
| Lv5 | 6 | 20 | 44 |
| Lv6 | 7 | 28 | 72 |
| Lv7（满级） | 8 | 36 | 108 |

### 规则

- 武器和塔各占 **1 人口**，不区分类型
- 纯人口限制，无独立武器栏上限，玩家可自由搭配武器/塔比例（理论上可全武器 0 塔，或全塔 0 武器）
- 背包中的物品**不占人口**，只有已装备（deployed）的才占人口
- 合成释放人口：3 个占 3 人口 → 合成后 1 个占 1 人口（净释放 2）
- 角色不自带默认武器/塔，初始 2 人口，第一波前在商店用初始金币购买

### 角色推荐机制

- `CharacterData.default_weapon` 和 `default_tower` 改为 `recommended_weapon` 和 `recommended_tower`
- 第一次进入商店时，4 个栏位中保证包含角色推荐的武器和塔（剩余 2 个随机）
- 后续刷新不再保证

## 3. 商店系统

### 基本参数

- 商店栏位数：4
- 刷新费用：固定 2 金币
- 波次结束自动免费刷新一次
- 背包容量：固定 10 格

### 物品池与定价

| 稀有度 | 购买价格 | 物品 |
|--------|---------|------|
| 普通 (0) | 3 金币 | 武器：rifle, shotgun, blade；塔：pea_shooter, stump, ice_flower, sunflower |
| 稀有 (1) | 5 金币 | 武器：boomerang, minigun, ice_gun, laser；塔：cactus, rose, mushroom, vine, dandelion, thorn, oak |
| 史诗 (2) | 8 金币 | 武器：rocket, lightning, flamethrower；塔：pitcher, mint, heal_flower, bamboo |

### 稀有度出现权重（按人口等级门控）

| 人口等级 | 普通% | 稀有% | 史诗% |
|---------|-------|-------|-------|
| Lv1-2 | 100% | 0% | 0% |
| Lv3 | 70% | 30% | 0% |
| Lv4 | 55% | 40% | 5% |
| Lv5 | 40% | 40% | 20% |
| Lv6 | 30% | 40% | 30% |
| Lv7 | 20% | 40% | 40% |

### 卖出规则

- **Lv1**：原价返还（全额）
- **Lv2+**：按投入成本的 **80%** 返还，向下取整（floor）
- 卖出价由 `sell_price_per_level` 字段定义（硬编码在各物品 Resource 中，而非运行时计算）

| 稀有度 | 买入价 | Lv1 卖出 | Lv2 投入 | Lv2 卖出 | Lv3 投入 | Lv3 卖出 |
|--------|-------|---------|---------|---------|---------|---------|
| 普通 | 3 | 3 | 9 | 7 | 27 | 21 |
| 稀有 | 5 | 5 | 15 | 12 | 45 | 36 |
| 史诗 | 8 | 8 | 24 | 19 | 72 | 57 |

### 商店操作

- **购买物品**：点击商店栏位 → 扣金币 → 物品进背包 → 自动检测合成 → 背包满不可购买
- **刷新商店**：波次结束自动免费刷新；手动刷新固定 2 金币
- **升本**：花金币提升人口等级 → 人口上限 +1，解锁高稀有度
- **卖出**：Lv1 原价，Lv2+ 按 80% 投入成本返还

## 4. 合成系统

### 规则

- **3 个同 id + 同 level** 自动合成为 level+1
- 最高等级 Lv3（★★★），不再合成
- 检查范围：**背包 + 已装备武器 + 已布置塔**（全部位置）
- 合成时已上场的单位**自动回收**，合成品放入背包
- **递归触发**：Lv1→Lv2 后如果有 3 个 Lv2 同类，继续合成 Lv3
- 合成释放人口：3 占用 → 1 占用（净释放 2）

### 触发时机

- 购买物品进入背包时
- 只要 bag + deployed 中存在 ≥3 个同 id 同 level 的物品即触发

### 已部署物品被合成时的处理

合成只在商店阶段触发（战斗中不购买），状态变更如下：

1. **已装备武器被合成**：武器从角色装备栏移除（undeploy），人口释放
2. **已布置塔被合成**：塔从地图上移除，网格位置释放，人口释放
3. **合成品**：始终放入背包，不自动部署
4. **人口变化**：立即重算（3 个占用 → 1 个在背包不占用，净释放 3 人口）

> 注意：背包中的物品不占人口，只有 deployed（装备/布置）才占人口。

## 5. 商店场景 UI 布局

### 整体布局

```
┌─────────────────────────────────────────────────────────┐
│ 顶栏：💰金币 | ⬆Lv等级 人口X/Y | 🌊波次 | [升本按钮] [开始战斗] │
├─────────────────────────────────────────────────────────┤
│ 商店栏：[物品1][物品2][物品3][物品4] [🔄刷新2💰]         │
├──────┬──────────────────────────────────────────────────┤
│ 角色  │                                                  │
│ 装备栏│              地图布置区                            │
│      │           （拖拽塔到网格）                          │
│ 🧙头像│                                                  │
│ [武器] │                                                  │
│ [武器] │                                                  │
│ [武器] │                                                  │
├──────┴──────────────────────────────────────────────────┤
│ 背包：[物品][物品][物品][ ][ ][ ][ ][ ][ ][ ] 3/10  [🗑卖出]│
└─────────────────────────────────────────────────────────┘
```

### 交互方式

- **购买**：点击商店栏位 → 物品进入背包
- **装备武器**：从背包拖拽武器到左侧角色装备栏 → 占 1 人口；拖回背包可卸下
- **布置塔**：从背包拖拽塔到中间地图网格 → 占 1 人口（免费放置）；从地图拖回背包可回收
- **卖出**：从背包/装备栏/地图拖拽到卖出区，或右键点击快速卖出

## 6. Resource 数据改造

### WeaponData 变更

```gdscript
# 修改
@export var max_level: int = 3  # 原 5 → 3
@export var damage_per_level: PackedFloat32Array  # 缩减为 3 元素
@export var fire_rate_per_level: PackedFloat32Array  # 缩减为 3 元素
@export var weapon_range_per_level: PackedFloat32Array  # 缩减为 3 元素
# ... 其他 per_level 字段同理

# 新增
@export var sell_price_per_level: PackedInt32Array  # 各级卖出价，硬编码

# 删除
# shop_price_per_level — 由 ShopConfig.cost_by_rarity 统一管理
```

### TowerData 变更

```gdscript
# 修改
@export var max_level: int = 3  # 原 5 → 3
@export var hp_per_level: PackedFloat32Array  # 缩减为 3 元素
@export var damage_per_level: PackedFloat32Array  # 缩减为 3 元素
# ... 其他 per_level 字段同理

# 删除
# place_cost_per_level — 免费放置，不再需要
# shop_price_per_level — 由 ShopConfig.cost_by_rarity 统一管理

# 新增
@export var sell_price_per_level: PackedInt32Array  # 各级卖出价，硬编码
```

### per_level 数值映射策略

取原 Lv1 / Lv3 / Lv5 的值，保持起步和满级数值体验一致：

| 示例：射手塔 damage | 原 Lv1 | 原 Lv3 | 原 Lv5 |
|---|---|---|---|
| 旧值 | 15 | 30 | 55 |
| 新映射 | ★ Lv1 = 15 | ★★ Lv2 = 30 | ★★★ Lv3 = 55 |

### 新增 Resource: ShopConfig

```gdscript
# scripts/resources/shop_config.gd
class_name ShopConfig
extends Resource

@export var slot_count: int = 4
@export var refresh_cost: int = 2
@export var bag_capacity: int = 10
@export var cost_by_rarity: PackedInt32Array = [3, 5, 8]  # index = rarity
@export var level_up_costs: PackedInt32Array = [4, 8, 12, 20, 28, 36]
@export var population_per_level: PackedInt32Array = [2, 3, 4, 5, 6, 7, 8]
@export var rarity_weights: Array[PackedFloat32Array]  # index = level-1, 内部 [普通%, 稀有%, 史诗%]
```

### CharacterData 变更

```gdscript
# 重命名
@export var recommended_weapon: String  # 原 default_weapon
@export var recommended_tower: String   # 原 default_tower
```

## 7. GameData 改造

### 新状态

```gdscript
var coins: int
var player_level: int = 1
var bag: Array[Dictionary] = []          # [{id, type, level}] 最多 10 个
var deployed_weapons: Array[Dictionary] = []  # [{id, level}]
var deployed_towers: Array[Dictionary] = []   # [{id, level, grid_pos}]
var shop_slots: Array[Dictionary] = []   # [{id, type, rarity, cost}] x4
```

### 新 API

```gdscript
# 计算属性
func get_population_cap() -> int
func get_population_used() -> int
func get_bag_count() -> int
func can_deploy() -> bool
func can_buy() -> bool

# 商店操作
func buy_item(slot_index: int) -> bool
func sell_item(item: Dictionary) -> int  # 返回金币数
func refresh_shop() -> bool
func buy_level_up() -> bool

# 部署操作
func deploy_weapon(bag_index: int) -> bool
func undeploy_weapon(deploy_index: int) -> void
func deploy_tower(bag_index: int, grid_pos: Vector2i) -> bool
func undeploy_tower(deploy_index: int) -> void

# 合成（内部）
func _check_merge(item_id: String, item_level: int) -> void
func _collect_all_items() -> Array[Dictionary]
```

### 删除的 API

- `var owned_weapons / owned_towers`
- `var current_xp / current_level / pending_upgrades`
- `var tower_inventory` — 已布置塔列表（由 `deployed_towers` 取代）
- `func add_xp() / upgrade_weapon() / upgrade_tower()`
- 里程碑相关字段（`pierce_count`, `multishot_active`, `split_count`, `bullet_speed_mult`, `weapon_range_mult`, `crit_chance`, `crit_damage_mult` 等）暂时保留，后续评估是否需要通过其他机制（如装备词条）替代

## 8. 战斗系统对接

### main.gd 改动

**删除：**
- 升级弹窗相关逻辑（`_show_upgrade_popup`、`pending_upgrades` 检查）
- XP/经验值 HUD 显示

**修改：**
- 玩家武器初始化：从 `GameData.deployed_weapons` 读取
- 塔生成：从 `GameData.deployed_towers` 读取 id + level + grid_pos
- 波次结束：`wave_transition_ready` → 直接 `SceneManager.go_to("shop")`
- 金币拾取：`add_coins()` 只加金币，不再调用 `add_xp()`

**不变：**
- 战斗核心（敌人生成、碰撞、伤害）
- WaveManager、EnemySpawner
- 塔的战斗行为
- HUD 金币显示

### player.gd 改动

- `_weapon_manager.initialize()` 从 `GameData.deployed_weapons` 读取（只加载已装备武器）
- `add_coins()` 删除 `add_xp()` 调用

### EventBus 信号变更

**删除：**
- `player_leveled_up` — XP 升级不再存在
- `xp_changed` — XP 系统移除
- `tower_purchased` — 由 shop 内部处理
- `tower_upgraded` — 合成替代升级

**新增：**
- `item_purchased(item: Dictionary)` — 商店购买物品
- `item_sold(item: Dictionary, refund: int)` — 卖出物品
- `item_merged(item_id: String, new_level: int)` — 合成触发
- `item_deployed(item: Dictionary)` — 装备武器/布置塔
- `item_undeployed(item: Dictionary)` — 卸下武器/回收塔
- `player_level_changed(new_level: int)` — 升本

**保留：**
- `coins_changed`
- `coin_collected`（金币拾取动画）
- `coins_generated`（向日葵产金）
- `wave_transition_ready`（触发跳转 shop 场景）
- `wave_completed`、`enemy_killed`、`boss_killed` 等战斗信号

### SceneManager 路由变更

- **新增：** `"shop": "res://scenes/ui/shop.tscn"`
- **删除：** `"placement": "res://scenes/levels/placement.tscn"`
- **BGM：** shop 场景复用原 placement BGM

## 9. 不受影响的系统

- WaveManager — 波次管理完全不变
- EnemySpawner — 敌人生成完全不变
- enemy.gd — 掉金币逻辑不变（去掉 XP 部分）
- 所有塔子类战斗逻辑（tower.gd 及子类）
- EffectsManager — 特效系统不变
- AudioManager — 音效系统不变
- SceneFactory — 工厂方法保留，`create_tower(tower_id, level)` 签名调整为接受 level 参数（不再从 owned_towers 读取），`get_tower_cost()` 删除

### 初始金币约束

角色的 `starting_gold` + `GameConfig.PLAYER.initial_coins` 必须 >= 6（至少能购买 2 个普通物品：1 武器 + 1 塔）。实现时在 GameData.reset() 中 assert 校验。
