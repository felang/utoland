# Shop 阶段重构设计

## 概述

重构商店阶段的 UI 布局和交互模式：左侧竖条面板改为底部横条面板，新增武器装备栏和塔点击菜单，合成机制从三合一改为二合一，移除相机缩放/移动，移除回收区和拖拽卖出，新增金币买升级功能。

## 变更范围

### 1. 移除相机缩放/移动

**当前状态**：`main.gd` 在 SHOP/BATTLE 阶段切换时 tween 相机的 zoom 和 position（`SHOP_ZOOM=0.56`、`SHOP_CAMERA_POS=(-196,0)`、`CAMERA_TRANSITION_DURATION=0.5`）。

**目标**：移除所有商店相关的相机操控。相机始终跟随玩家，SHOP/BATTLE 切换时只控制面板弹出/弹入。

**影响文件**：`scripts/ui/main.gd`

**具体移除**：
- 常量 `CAMERA_TRANSITION_DURATION`、`SHOP_ZOOM`、`SHOP_CAMERA_POS`
- `_enter_shop_phase()` 中的 camera top_level 设置、zoom/position tween、limit 扩展
- `_enter_battle_phase()` 中的 camera tween 和 `_restore_battle_camera()` 调用
- `_restore_battle_camera()` 方法
- `_get_clamped_camera_pos()` 方法
- `wm.set_weapon_drag_callback(...)` 回调设置（武器拖拽已移除）

### 2. 底部面板布局

**当前状态**：ShopOverlay 是左侧竖条（169px 宽，CanvasLayer layer=10），从左侧滑入/滑出。

**目标**：改为底部横条面板，从下方弹出/弹入。

#### 布局结构

```
┌──────────────────────────────────────────────────┐
│ $100  Lv.3  人口3/5  第2波              [开战]   │  ← 信息栏
├──────────┬────────────────────────┬───────────────┤
│  武器     │  商店                  │               │
│ [🏹][⚔][ ] │ [弓箭$3][塔$3][剑$3][🌻$3] │ [刷新 $2]     │  ← 主行
│ [ ][ ][ ] │                        │ [升级 $X]     │
│  ~30%    │  ~55%                  │  ~15%         │
└──────────┴────────────────────────┴───────────────┘
```

#### 信息栏（上行）
- 左侧：金币、等级、人口（当前/上限）、波次
- 右侧：开战按钮

#### 主行（下行）
- **武器区**（~30%）：3 列网格，28px 图标。显示已装备的武器（`InventoryManager.deployed_weapons`）。空槽用虚线边框。点击图标弹出菜单。武器数量超出 3x2 格子时自动扩展行数
- **商店卡片区**（~55%）：4 张卡片水平排列，每张显示图标+名称+价格。点击购买
- **操作区**（~15%）：刷新按钮和买升级按钮竖向排列

#### 动画
- 弹出：面板从屏幕下方 tween `position.y` 上升到目标位置（0.3s）
- 弹入：面板 tween `position.y` 下降到屏幕外（0.3s）
- 方向从水平（`position.x`）改为垂直（`position.y`），时长不变

**影响文件**：`scripts/ui/shop_overlay.gd`、`scenes/ui/shop_overlay.tscn`

### 3. 武器装备栏点击菜单

**新增功能**：点击武器区中的装备图标，弹出小菜单。

#### 菜单选项
- **合成**：仅当 `deployed_weapons` 中有 2 个同 `id` 同 `level` 时显示。点击后调用 `InventoryManager.merge_weapon(weapon_index)` 合成为 `level+1`
- **卖出 $X**：显示返还金额（`sell_price_per_level[level-1]`）。点击后卖出，金币返还

#### 交互
- 点击图标弹出菜单，点击其他区域关闭菜单
- 菜单出现在图标上方
- 一次只能打开一个菜单

**影响文件**：`scripts/ui/shop_overlay.gd`（新增菜单逻辑）

### 4. 塔点击菜单（地图上）

**当前状态**：DragManager 中点击地图上的塔进入 `MAP_TOWER` 拖拽模式，拖到回收区卖出。

**目标**：点击地图上的塔弹出小菜单，替代拖拽操作。菜单由 DragManager 管理（它已持有塔节点引用 `_tower_nodes`）。

#### 菜单选项
- **合成**：仅当 `deployed_towers` 中有另一个同 `id` 同 `level` 的塔时显示。点击后调用 `InventoryManager.merge_tower(deploy_id)` 合成，保留在被点击塔的位置，另一个塔节点移除
- **卖出 $X**：显示返还金额，调用 `InventoryManager.sell_from_deployed_tower(deploy_id)` 移除塔
- **移动**：进入 `MOVE_TOWER` 模式——塔跟随鼠标，点击空位放置，右键取消恢复原位。复用现有网格验证和范围指示器

#### 阶段限制
- `main.gd` 在 `_enter_shop_phase()` 时调用 `drag_manager.set_shop_mode(true)`，`_enter_battle_phase()` 时调用 `set_shop_mode(false)`
- DragManager 内部检查 `_is_shop_mode`，仅在 SHOP 阶段响应塔点击

#### 交互
- SHOP 阶段点击塔弹出菜单
- 选择"移动"后进入 `MOVE_TOWER` 模式（原 `MAP_TOWER` 重命名，由菜单触发）
- `_is_grid_available()` 在 `MOVE_TOWER` 模式下仍排除被移动塔自身的格子位置
- 菜单出现在塔上方

**影响文件**：`scripts/systems/drag_manager.gd`（塔菜单 + MOVE_TOWER 模式）

### 5. 合成机制改为二合一

**当前状态**：`InventoryManager._check_merge()` 检查 3 个同 id 同 level 物品，合成为 1 个 level+1。`can_buy_item()` 在人口满时检查 ≥2 同类允许购买。

**目标**：
- 合成阈值从 3 改为 2
- 最高等级 Lv3 不变（2 个 Lv2 → 1 个 Lv3）
- 移除 `can_buy_item()` 的智能人口判断——人口满就不能买
- 合成改为手动触发，不再在购买时自动触发

#### `_check_merge()` 变更
- 候选数量检查：`< 3` → `< 2`
- 消耗数量：消耗 2 个（含触发项自身），生成 1 个 level+1
- 递归合成保留（合成后如果又满足 2 个同类则继续合成）

#### 移除购买时自动合成
- `buy_and_equip_weapon()` 中移除 `_check_merge(weapon_id, 1)` 调用
- `buy_and_place_tower()` 中移除 `_check_merge(tower_id, 1)` 调用

#### 新增手动合成 API
- `merge_weapon(weapon_index: int) -> bool`：合成指定索引的武器与另一个同 id 同 level 的武器。保留 `weapon_index` 位置的武器并升级，移除另一个。返回是否成功。合成后调用 `_check_merge()` 检查递归合成
- `merge_tower(deploy_id: int) -> bool`：合成指定 deploy_id 的塔与另一个同 id 同 level 的塔。保留被点击塔的 grid_pos 和 deploy_id，移除另一个塔。返回是否成功。合成后调用 `_check_merge()` 检查递归合成

#### `can_buy_item()` 变更
- 简化为：`get_current_population() < PlayerProgression.get_population_cap()`
- 移除合成可行性检查

**影响文件**：`scripts/core/inventory_manager.gd`

### 6. 买升级功能

**新增功能**：商店操作区"升级"按钮，花金币提升玩家等级。

#### 效果
- `player_level += 1`，直接修改等级，不影响 `current_exp`
- 人口上限 +1（`population_per_level`）
- 触发 `EventBus.player_level_changed` 信号

#### 价格
- 采用公式化配置：`ShopConfig.level_up_base_cost: int` + `ShopConfig.level_up_cost_increment: int`
- 当前等级升级费用：`level_up_base_cost + (player_level - 1) * level_up_cost_increment`
- 具体数值后续调整，先用占位值（如 base=4, increment=2）

#### API
- `PlayerProgression.buy_level_up() -> void`：`player_level += 1`，emit `EventBus.player_level_changed`。不修改 exp
- `ShopManager.buy_level_up() -> bool`：检查金币是否足够，扣除金币，调用 `PlayerProgression.buy_level_up()`，返回是否成功
- `ShopConfig.get_level_up_cost(current_level: int) -> int`：返回升级费用

#### 交互
- 按钮显示当前升级价格（如"升级 $6"）
- 金币不足时按钮置灰
- 点击扣除金币，触发升级

**影响文件**：`scripts/resources/shop_config.gd`、`scripts/ui/shop_overlay.gd`、`scripts/systems/shop_manager.gd`、`scripts/core/player_progression.gd`

### 7. DragManager 简化

**当前状态**：三种拖拽模式 `PLACE_TOWER`、`MAP_TOWER`、`WEAPON`。

**目标**：
- **保留** `PLACE_TOWER`（购买塔后的网格放置）
- **新增** `MOVE_TOWER`（原 `MAP_TOWER` 重命名，由塔菜单"移动"触发而非直接点击拖拽）
- **移除** `MAP_TOWER`（直接点击拖拽入口）
- **移除** `WEAPON`（改为装备栏菜单卖出）
- **移除**回收区相关逻辑（`is_over_recycle_area()`、`_update_recycle_hint()`、`_get_drag_refund()`）
- **新增**塔点击菜单（PopupMenu 或自绘面板，显示在塔上方）
- **新增** `set_shop_mode(enabled: bool)` 控制是否响应塔点击
- **移除** `_check_tower_click()` 的直接拖拽触发，改为弹出菜单

`MOVE_TOWER` 模式复用原 `MAP_TOWER` 的网格验证、范围指示器、鼠标跟随逻辑，`_is_grid_available()` 仍排除被移动塔自身格子。

**影响文件**：`scripts/systems/drag_manager.gd`、`scripts/ui/shop_overlay.gd`（移除回收区）

### 8. 移除清单

| 功能 | 位置 |
|------|------|
| `SHOP_ZOOM`、`SHOP_CAMERA_POS`、`CAMERA_TRANSITION_DURATION` | `main.gd` |
| `_restore_battle_camera()`、`_get_clamped_camera_pos()` | `main.gd` |
| `wm.set_weapon_drag_callback(...)` 回调设置 | `main.gd` |
| `WeaponManager._weapon_drag_callback` 机制 | `weapon_manager.gd` |
| 回收区 UI（`_recycle_area`、`_recycle_label`） | `shop_overlay.gd` |
| `is_over_recycle_area()`、`_update_recycle_hint()`、`_get_drag_refund()` | `drag_manager.gd` |
| `DragSource.MAP_TOWER`、`DragSource.WEAPON` | `drag_manager.gd` |
| `_check_tower_click()` 直接拖拽触发逻辑 | `drag_manager.gd` |
| `can_buy_item()` 合成智能判断 | `inventory_manager.gd` |
| `buy_and_equip_weapon()` 中的 `_check_merge()` 调用 | `inventory_manager.gd` |
| `buy_and_place_tower()` 中的 `_check_merge()` 调用 | `inventory_manager.gd` |

### 影响的文件汇总

| 文件 | 变更类型 |
|------|----------|
| `scripts/ui/main.gd` | 移除相机操控、武器拖拽回调，简化阶段切换，新增 `set_shop_mode` 调用 |
| `scripts/ui/shop_overlay.gd` | 重写：底部布局、武器装备栏、点击菜单、买升级、移除回收区 |
| `scenes/ui/shop_overlay.tscn` | 重写：锚点改为底部 |
| `scripts/systems/drag_manager.gd` | 简化拖拽模式，新增塔点击菜单+MOVE_TOWER 模式+shop_mode 控制 |
| `scripts/core/inventory_manager.gd` | 合成 3→2，移除购买时自动合成，简化 can_buy_item，新增 merge_weapon/merge_tower API |
| `scripts/resources/shop_config.gd` | 新增 level_up_base_cost、level_up_cost_increment、get_level_up_cost() |
| `scripts/systems/shop_manager.gd` | 新增 buy_level_up 方法 |
| `scripts/core/player_progression.gd` | 新增 buy_level_up() 方法 |
| `scripts/entities/weapons/weapon_manager.gd` | 移除 _weapon_drag_callback 机制 |
| `tests/unit/test_weapon_config.gd` | 更新合成测试（3→2 阈值） |
| `tests/unit/test_drag_manager.gd` | 移除 WEAPON/MAP_TOWER/回收区测试，新增塔菜单和 MOVE_TOWER 测试 |
| `tests/unit/test_object_pool.gd` | 合成相关测试更新 |
