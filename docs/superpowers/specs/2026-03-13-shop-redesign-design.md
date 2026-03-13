# 商店系统重构：武器选择 + 塔商店

## 概述

将商店从"道具属性商店"重构为两条独立成长线：
- **武器线**：吸血鬼幸存者式，波次结束 3 选 1 免费升级
- **塔线**：土豆兄弟式，布置阶段金币商店购买/升级

## 设计动机

原道具系统（37 个道具、24 种效果）扩充需要大量美术和数值工作。武器/塔升级系统更直观，数据集中在现有 Resource 文件中，扩展只需加等级数值。

## 武器成长线（选择驱动）

### 核心机制
- 每波结束弹出 3 个选项，玩家选 1 个，免费
- 选项从混合池随机抽取：新武器 + 已有武器的升级
- 武器最高 5 级，满级武器不再出现在选项中
- 多武器同时装备，WeaponManager 自动管理开火
- 角色自带 1 把 Lv1 初始武器

### 选项生成规则
- 池中包含：所有未拥有武器（作为"Lv1 新武器"）+ 所有已拥有且未满级武器（作为"升级到 Lv N+1"）
- 从池中随机抽 3 个（不重复）
- 若池中不足 3 个，则只显示剩余数量
- 若池为空（所有武器满级），跳过选择直接进入布置阶段

### 武器等级数据（方案 C：等级曲线 + 里程碑）

在 WeaponData 中新增字段：

```
@export var max_level: int = 5
@export var damage_per_level: Array[float]        # [10, 15, 22, 30, 40]
@export var fire_rate_per_level: Array[float]      # [0.3, 0.28, 0.25, 0.22, 0.18]
@export var weapon_range_per_level: Array[float]   # [200, 220, 240, 260, 300]
@export var milestones: Dictionary = {}            # {3: "pierce_1", 5: "multishot"}
```

- `damage_per_level[level - 1]` 获取当前等级伤害
- 现有平面字段 `damage`, `fire_rate`, `weapon_range` 移除，全部改为 per_level 数组
- 其他武器特有属性（`bullet_speed`, `knockback_force`, `boomerang_speed` 等）暂保持平面字段，后续按需迁移
- `milestones` 键为等级，值为效果 ID，达到对应等级时解锁质变效果
- 初期可以只做纯数值升级，milestones 留空，后续逐步补充

### 里程碑效果类型（初期可选子集）
- `pierce_N`：子弹穿透 N 个敌人
- `multishot`：一次射出 3 发（伤害按系数衰减）
- `split`：子弹命中后分裂
- `bullet_speed`：弹速提升
- 后续可按需扩展，每种效果对应武器脚本中的具体实现

## 塔成长线（经济驱动）

### 核心机制
- 布置阶段侧栏商店 Tab，3 格 + 可花金币刷新
- 选项从混合池随机抽取：新塔类型 + 已有塔的升级
- 塔最高 5 级，满级塔不再出现在商店中
- 金币用途：购买/升级塔 + 放置塔到地图 + 刷新商店
- 角色自带 1 种 Lv1 初始塔
- 升级全局生效：商店升级后所有已放置的同类型塔立即升级

### 商店生成规则
- 池中包含：所有未拥有塔（作为"Lv1 新塔"）+ 所有已拥有且未满级塔（作为"升级到 Lv N+1"）
- 从池中随机抽 3 个（不重复），各自有对应价格
- 若池中不足 3 个，剩余格子留空
- 刷新费用保持现有阶梯：按波次递增
- 首波（wave 0）：商店 Tab 不可见，仅布置 Tab

### 塔等级数据

在 TowerData 中新增字段：

```
@export var max_level: int = 5
@export var hp_per_level: Array[float]            # [100, 130, 170, 220, 280]
@export var damage_per_level: Array[float]        # [15, 22, 30, 40, 55]（射手塔）
@export var fire_rate_per_level: Array[float]     # 射手塔专用
@export var attack_range_per_level: Array[float]  # 射手塔专用
@export var slow_ratio_per_level: Array[float]    # 减速塔专用
@export var shop_price_per_level: Array[int]      # [0, 20, 35, 55, 80]（Lv1=购买价，Lv2+=升级价）
@export var milestones: Dictionary = {}
```

### 塔放置费用

在 TowerData 中新增字段：
```
@export var place_cost_per_level: Array[int]     # [10, 15, 20, 28, 38]
```
- 放置塔的费用取决于塔的当前全局等级，`place_cost_per_level[level - 1]`
- 移除现有 `shop_price_min/max` 字段（被 `shop_price_per_level` 和 `place_cost_per_level` 替代）

## 游戏流程

```
波次战斗结束（main.gd）
  ↓
武器选择弹窗（在战斗场景内弹出，CanvasLayer 覆盖）
  → main.gd 监听 wave_completed，暂停游戏，创建 weapon_select_popup
  → 玩家选择后，popup 发出 weapon_selected 信号
  → main.gd 收到信号，调用 SceneManager.go_to(PLACEMENT)
  ↓（选择后或无可选时自动跳过）
布置阶段
  ├── 布置 Tab：放置/移除已拥有的塔（花金币）
  └── 商店 Tab（wave > 0）：3格塔商店（买新塔/升级塔）
  ↓（点击开始战斗）
下一波战斗
```

### 首波特殊处理
- wave 0 进入布置阶段时，不弹武器选择（还没打过）
- 商店 Tab 不可见
- 玩家用初始塔和初始金币布置

### 武器选择弹窗场景
- `scenes/ui/weapon_select_popup.tscn` + `scripts/ui/weapon_select_popup.gd`
- 作为 CanvasLayer 添加到战斗场景（main.tscn），弹出时暂停游戏树
- 显示 3 张卡片（武器图标 + 名称 + 等级 + 属性变化预览）
- 玩家点击卡片后发出 `weapon_selected(weapon_id: String)` 信号
- main.gd 接收信号后执行升级逻辑并切换到布置场景

## GameData 变更

### 新增字段
```gdscript
var owned_weapons: Dictionary = {}    # {weapon_id: level}  如 {"rifle": 2, "shotgun": 1}
var owned_towers: Dictionary = {}     # {tower_id: level}   如 {"shooter": 3, "slow": 1}
```

### 移除字段
道具系统相关字段全部移除：
- purchased_items, purchased_item_list
- lifesteal_ratio, kill_stack_*, tower_link_*
- wave_gold_bonus, wave_tower_heal_ratio, tower_regen_*
- symbiosis_*, war_machine_*
- wave_shield_count, current_shield, wave_heal_ratio
- damage_reduction, dodge_chance, coin_magnet_mult
- slow_aura_*, auto_dash_*
- selected_weapon（被 owned_weapons 替代）
- purchased_towers（被 owned_towers 替代）

### 保留字段（里程碑效果可能复用）
- coins, current_wave, player_stats 等基础状态
- tower_inventory（已放置塔的位置信息）
- pierce_count — 武器里程碑 `pierce_N` 使用
- multishot_active, multishot_damage_mult — 武器里程碑 `multishot` 使用
- split_count, split_damage_mult — 武器里程碑 `split` 使用
- bullet_speed_mult — 武器里程碑 `bullet_speed` 使用
- weapon_range_mult — 武器里程碑 `weapon_range` 使用
- crit_chance — 武器里程碑 `crit` 使用

> 注意：初期若不实现 milestones，这些保留字段也可暂不使用但保留以备后续。

## 移除的文件/系统

| 文件 | 说明 |
|------|------|
| `resources/items/*.tres` (37个) | 全部道具数据文件 |
| `scripts/resources/shop_item_data.gd` | ShopItemData 资源类 |
| `scripts/systems/shop_effect_applier.gd` | 道具效果应用 |
| `scripts/systems/shop_item_generator.gd` | 道具生成逻辑 |
| `scripts/systems/item_effect_manager.gd` | 被动效果管理 |
| `CharacterData.affinity_tags/discount` | 角色亲和系统 |

## 新增/重构的文件

| 文件 | 说明 |
|------|------|
| `scripts/ui/weapon_select_popup.gd` | 武器选择弹窗 UI（波次结束 3 选 1） |
| `scripts/systems/weapon_upgrade_generator.gd` | 武器选项生成逻辑 |
| `scripts/systems/tower_shop_generator.gd` | 塔商店选项生成逻辑 |
| `scripts/ui/shop_panel.gd` | 重构为纯塔商店（3格） |
| `WeaponData` 新增字段 | max_level, *_per_level, milestones |
| `TowerData` 新增字段 | max_level, *_per_level, shop_price_per_level, milestones |

## 角色差异化

移除亲和折扣系统后，角色差异通过初始武器和初始塔区分：

| 角色 | 初始武器 | 初始塔 | 其他差异 |
|------|----------|--------|----------|
| Dora | rifle | shooter | 高 HP |
| Gorg | shotgun | wall | 高防御 |
| Kaze | boomerang | slow | 高速度 |
| Merlin | laser | shooter | 高伤害 |

（具体搭配待数值设计阶段确定）

### CharacterData 变更
- 移除：`affinity_tags: PackedStringArray`, `affinity_discount: float`
- 新增：`default_tower: String` — 角色初始塔类型 ID
- 保留：`default_weapon` (已有) — 角色初始武器 ID
- `GameData.reset()` 时根据 CharacterData 初始化 `owned_weapons = {default_weapon: 1}` 和 `owned_towers = {default_tower: 1}`

## 武器等级运行时应用机制

武器实例通过 `GameData.owned_weapons` 获取当前等级，从 WeaponData 的 per_level 数组读取属性：

```gdscript
# Weapon 基类新增方法
func get_current_level() -> int:
    return GameData.owned_weapons.get(weapon_data.id, 1)

func get_damage() -> float:
    var level := get_current_level()
    return weapon_data.damage_per_level[level - 1]

func get_fire_rate() -> float:
    var level := get_current_level()
    return weapon_data.fire_rate_per_level[level - 1]
```

- Weapon 不再直接读 `weapon_data.damage`，改为通过 `get_damage()` 读取等级化属性
- WeaponManager 中 `weapon_data.weapon_range` 改为从 per_level 数组读取
- 升级时无需通知已有武器实例，因为每帧都重新读取

## 塔等级运行时应用机制

塔升级全局生效的实现：

```gdscript
# Tower 基类新增方法
func get_current_level() -> int:
    return GameData.owned_towers.get(data.id, 1)

func get_max_hp() -> float:
    return data.hp_per_level[get_current_level() - 1]
```

- 商店升级塔时，通过 EventBus 发出 `tower_upgraded(tower_type: String)` 信号
- 所有已放置的同类型塔监听该信号，调用 `_apply_level_stats()` 重新读取属性
- `_apply_level_stats()` 更新 HealthComponent.max_hp、damage、fire_rate 等
- SceneFactory.create_tower() 创建塔时从 `GameData.owned_towers` 读取等级
- Tower._ready() 调用 `_apply_level_stats()` 初始化为当前等级属性
- 塔移除时全额退还 `place_cost_per_level[level-1]` 的放置费用

## placement_panel 变更

布置面板从"固定显示3种塔"改为"只显示已拥有的塔类型"：

- 读取 `GameData.owned_towers` 获取已拥有塔列表
- 每种塔的卡片显示：名称、等级、放置费用（`place_cost_per_level[level-1]`）
- 未拥有的塔类型不显示
- 新购买塔后刷新布置面板（监听 EventBus.tower_purchased 信号）

## 里程碑效果的实现策略

里程碑效果复用保留的 GameData 字段：
- 武器升级达到里程碑等级时，由升级逻辑写入 GameData 对应字段（如 pierce_count）
- 降级不会发生，所以只需在升级时写入，无需撤销
- 初期可不实现任何 milestone，纯数值升级即可运行

## 需修改的现有文件

除新增/移除文件外，以下现有文件需要修改：
- `scripts/core/game_data.gd` — 字段增删、reset() 初始化 owned_weapons/towers
- `scripts/resources/weapon_data.gd` — 新增 per_level 数组和 milestones
- `scripts/resources/tower_data.gd` — 新增 per_level 数组、shop_price_per_level、place_cost_per_level、milestones
- `scripts/resources/character_data.gd` — 移除 affinity_*，新增 default_tower
- `scripts/entities/weapons/weapon.gd` — get_damage()/get_fire_rate() 读取等级化属性
- `scripts/entities/weapons/weapon_manager.gd` — 移除 weapon_range_mult 引用，通过 weapon.get_weapon_range() 读取等级化射程
- `scripts/entities/player.gd` — `_weapon_manager.initialize([GameData.selected_weapon])` 改为 `_weapon_manager.initialize(GameData.owned_weapons.keys())`
- `scripts/entities/towers/tower.gd` — 新增 get_current_level()、_apply_level_stats()、监听 tower_upgraded
- `scripts/entities/towers/tower_shooter.gd` — 适配等级化属性
- `scripts/entities/towers/tower_slow.gd` — 适配等级化属性
- `scripts/ui/placement_panel.gd` — 只显示已拥有塔，显示等级和对应放置费用
- `scripts/ui/placement.gd` — 适配 shop_panel 3 格，移除旧商店初始化
- `scripts/core/scene_factory.gd` — create_tower() 适配等级，get_tower_cost() 改读 `data.place_cost_per_level[level-1]`
- `scripts/core/event_bus.gd` — 新增 tower_upgraded/tower_purchased 信号
- `scenes/levels/main.tscn` / `scripts/ui/main.gd` — 波次结束弹出武器选择弹窗
- `resources/weapons/*.tres` — 补充 per_level 数组数据
- `resources/towers/*.tres` — 补充 per_level 数组数据
- `resources/characters/*.tres` — 补充 default_tower，移除 affinity 字段

## 测试策略

### 单元测试
- **weapon_upgrade_generator**：验证池过滤（满级排除、未拥有武器包含、不重复抽取）
- **tower_shop_generator**：验证池过滤、价格从 shop_price_per_level 正确读取
- **武器等级属性**：验证 get_damage()/get_fire_rate() 按等级返回正确值
- **塔等级属性**：验证升级信号触发后 _apply_level_stats() 正确更新属性
- **边界情况**：所有武器满级时返回空池、商店池为空时格子留空

### 需更新的现有测试
- `test_shop_panel.gd` — 重写为塔商店 3 格测试
- `test_placement_panel.gd` — 适配"只显示已拥有塔"逻辑
- 涉及 GameData 道具字段的测试需移除或更新
