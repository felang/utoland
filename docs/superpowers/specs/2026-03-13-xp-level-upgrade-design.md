# 经验值等级系统与升级弹窗重构设计

## 概述

为游戏添加经验值（XP）和角色等级系统，将塔的解锁/升级从布置阶段商店迁移到波次结束的升级弹窗中，与武器升级合并为统一的 3 选 1 选择池。布置阶段简化为纯塔布置。

## 设计目标

1. 增加战斗中的成长反馈（拾取金币 → 涨经验 → 升级）
2. 将武器和塔的成长统一到一个选择入口，降低玩家认知负担
3. 简化布置阶段，移除商店 Tab

---

## 一、经验值与角色等级系统

### GameData 新增字段

```gdscript
var current_level: int = 1
var current_xp: int = 0
var pending_upgrades: int = 0  # 本波累计的待选择升级次数
```

计算属性：
```gdscript
func get_xp_to_next_level() -> int:
    return 20 + (current_level - 1) * 15
```

### 升级经验曲线

公式：`xp_to_next_level = 20 + (current_level - 1) * 15`

| 等级 | 所需 XP | 累计 XP | 预计到达波次 |
|------|---------|---------|-------------|
| 1→2  | 20      | 20      | 第 1 波     |
| 2→3  | 35      | 55      | 第 2 波     |
| 3→4  | 50      | 105     | 第 3-4 波   |
| 4→5  | 65      | 170     | 第 5 波     |
| 5→6  | 80      | 250     | 第 6 波     |
| 6→7  | 95      | 345     | 第 7 波     |
| 7→8  | 110     | 455     | 第 8 波     |
| ...  | +15/级  | ...     | ...         |

设计依据：早期每波 20-50 金币，中期 125-280，后期 260-375。该曲线确保早期每波约升 1 次，中后期每波 1-2 次。

### XP 获取方式

金币与经验绑定：拾取 1 金币 = 获得 1 XP。不产生额外实体。

在现有的金币拾取流程中扩展：
1. `coin.gd` 的 `_on_body_entered()` 调用 `player.add_coins(value)` — 现有逻辑不变
2. `player.add_coins()` 中同步调用 `GameData.add_xp(amount)`
3. `GameData.add_xp()` 累加 XP，判断升级，可能连续升多级

### 升级触发流程

```
拾取金币 → GameData.add_xp(amount)
  → current_xp += amount
  → while current_xp >= get_xp_to_next_level():
      current_xp -= get_xp_to_next_level()
      current_level += 1
      pending_upgrades += 1
      emit EventBus.player_leveled_up(current_level)
  → emit EventBus.xp_changed(current_xp, get_xp_to_next_level())
```

### EventBus 新增信号

```gdscript
signal player_leveled_up(level: int)
signal xp_changed(current_xp: int, xp_to_next: int)
```

### reset() 扩展

`GameData.reset()` 中重置：
```gdscript
current_level = 1
current_xp = 0
pending_upgrades = 0
```

---

## 二、合并升级生成器（UpgradeGenerator）

### 取代

- 删除 `WeaponUpgradeGenerator`（`scripts/systems/weapon_upgrade_generator.gd`）
- 删除 `TowerShopGenerator`（`scripts/systems/tower_shop_generator.gd`）
- 新建 `UpgradeGenerator`（`scripts/systems/upgrade_generator.gd`，RefCounted）

### 核心接口

```gdscript
func generate_options(exclude: Array[Dictionary] = []) -> Array[Dictionary]
# 返回 3 个选项（或更少，若池子不足），每个格式：
# {
#   type: "weapon" | "tower",   # 类型
#   id: String,                  # 如 "rifle", "shooter"
#   target_level: int,           # 升级目标等级
#   is_new: bool,                # 是否新获取
#   current_level: int           # 当前等级，0 if is_new
# }

func get_refresh_cost(refresh_count: int) -> int
# 0 if refresh_count == 0 (免费)
# 5 * refresh_count otherwise (5, 10, 15, 20...)
```

### 池子构建与加权

```
1. 遍历 GameConfig.weapons:
   - 未拥有 → 加入池子（type="weapon", is_new=true, target_level=1）
   - 已拥有且 level < max_level → 加入（is_new=false, target_level=level+1）

2. 遍历 GameConfig.towers:
   - 同上规则

3. 加权抽取:
   - 基础权重 = 1.0
   - 若 owned_towers.size() < owned_weapons.size() → 塔类权重 x1.5
   - 若 owned_weapons.size() < owned_towers.size() → 武器类权重 x1.5
   - 新物品权重 x1.2（鼓励多样性）

4. 按权重随机抽取 3 个，排除 exclude 列表中的选项
```

### 刷新机制

- 每轮选择维护 `refresh_count: int`，初始 0
- 首次刷新免费（`refresh_count == 0`）
- 之后费用递增：`5 * refresh_count`（5, 10, 15...）
- 刷新时传入当前选项作为 `exclude`，避免刷出相同选项
- 每轮选择完成后 `refresh_count` 重置为 0

---

## 三、升级弹窗 UI 改造

### 文件变更

- `weapon_select_popup.gd` → 重命名为 `upgrade_popup.gd`
- `weapon_select_popup.tscn` → 重命名为 `upgrade_popup.tscn`

### 多轮选择流程

```
弹窗接收 pending_upgrades 数量
  → 显示 "选择升级 (1/N)"
  → 玩家选择一张卡片
  → 应用升级（GameData.upgrade_weapon 或 upgrade_tower）
  → 若还有剩余轮次:
      refresh_count = 0
      生成新选项
      显示 "选择升级 (2/N)"
  → 全部选完:
      emit all_upgrades_completed
      恢复游戏 (get_tree().paused = false)
      跳转布置阶段
```

### 卡片样式

**武器卡：**
- 边框：`#4fc3f7`（蓝色）
- 背景底色：`#1a1a3a`（深蓝）
- 顶部标识："⚔ 武器"（蓝色文字）

**塔卡：**
- 边框：`#66bb6a`（绿色）
- 背景底色：`#1a2a1a`（深绿）
- 顶部标识："🏗 塔"（绿色文字）

**卡片内容：**
- 名称（白色，加粗）
- 等级信息：新获取 → 绿色 "新武器! Lv1" / "新塔! Lv1"；升级 → 黄色 "Lv2 → Lv3"
- 属性预览（灰色小字）：伤害、射速、范围等

### 刷新按钮

- 位于 3 张卡片下方居中
- 免费时："🔄 刷新 (免费)"
- 收费时："🔄 刷新 (N金币)"
- 金币不足时变灰不可点击

### 信号

```gdscript
signal upgrade_selected(type: String, id: String)  # 每次选择
signal all_upgrades_completed                        # 全部轮次结束
signal skipped                                       # 池子为空
```

---

## 四、布置阶段简化

### 删除内容

- 删除 `shop_panel.gd`（`scripts/ui/shop_panel.gd`）
- 删除 `TowerShopGenerator`（已在第二节处理）
- 从 `placement.tscn` 中移除：`TabBar`（含 `PlacementTab`、`ShopTab`）、`ShopContent`（含 `ShopScroll`、`ShopItemList`、`RefreshButton`）

### placement.gd 改动

- 移除 `_switch_tab()` 方法及相关引用
- 移除 `ShopTab`/`PlacementTab` 按钮的 `@onready` 和信号连接
- `PlacementContent` 始终可见，无需显隐切换
- 首波（`current_wave == 0`）不再需要特殊处理（隐藏商店），所有波次布局一致

### 侧栏最终结构

```
SidePanel (VBoxContainer, 120px)
├── CoinsLabel — "金币: {N}"
├── PlacementScroll (ScrollContainer)
│   └── TowerList (VBoxContainer) — 已拥有塔的卡片
└── StartBattleButton — "开始战斗"
```

### placement_panel.gd

逻辑不变：仍从 `GameData.owned_towers` 生成卡片，监听 `EventBus.tower_purchased`/`tower_upgraded` 刷新卡片列表。

---

## 五、HUD 经验条

### UI 结构

在现有 HUD 血条下方添加：
- 等级数字："Lv.3"（血条左侧或经验条左侧）
- 经验进度条：高度约为血条的 1/3，浅蓝/紫色填充

### 信号连接

- `EventBus.xp_changed(current_xp, xp_to_next)` → 更新经验条进度
- `EventBus.player_leveled_up(level)` → 更新等级数字 + 经验条闪白（0.3s tween）

### 升级反馈

- 经验条闪白：0.3s tween 动画
- 浮动文字："Level Up!"，复用 `EffectsManager.spawn_damage_number` 的模式，使用不同颜色（蓝/紫色）

---

## 六、游戏流程变更

### 改造前

```
波次战斗 → wave_transition_ready
  → weapon_select_popup（1 次 3 选 1 武器）
  → placement（布置 Tab + 塔商店 Tab）
  → 下一波
```

### 改造后

```
波次战斗（拾取金币获得 XP，可能升多级）
  → wave_transition_ready
  → upgrade_popup（N 次 3 选 1 武器+塔混合，N = pending_upgrades）
  → placement（纯塔布置，无商店）
  → 下一波
```

### 边界情况

- `pending_upgrades == 0`（本波没升级）→ 跳过弹窗，直接进布置
- 池子为空（所有武器和塔都满级）→ 弹窗 skipped，直接进布置
- 某轮选择中池子不足 3 个 → 显示实际可用数量（1-2 个）

---

## 七、文件变更清单

### 新增

- `scripts/systems/upgrade_generator.gd` — 合并升级选项生成器

### 重命名

- `scripts/ui/weapon_select_popup.gd` → `scripts/ui/upgrade_popup.gd`
- `scenes/ui/weapon_select_popup.tscn` → `scenes/ui/upgrade_popup.tscn`

### 修改

- `scripts/core/game_data.gd` — 新增 XP/等级字段和方法
- `scripts/core/event_bus.gd` — 新增 `player_leveled_up`、`xp_changed` 信号
- `scripts/entities/player.gd` — `add_coins()` 中调用 `GameData.add_xp()`
- `scripts/ui/main.gd` — 引用 `upgrade_popup` 替代 `weapon_select_popup`，处理多轮逻辑
- `scripts/ui/placement.gd` — 移除 Tab 切换和商店相关逻辑
- `scenes/levels/placement.tscn` — 移除商店 UI 节点
- `scripts/ui/hud.gd` + `scenes/ui/hud.tscn` — 新增经验条和等级显示

### 删除

- `scripts/systems/weapon_upgrade_generator.gd`
- `scripts/systems/tower_shop_generator.gd`
- `scripts/ui/shop_panel.gd`

### 测试更新

- 现有 `weapon_upgrade_generator` 和 `tower_shop_generator` 的测试需迁移到 `upgrade_generator`
- 新增 XP/等级系统测试
- 更新 `placement` 相关测试（移除商店引用）
