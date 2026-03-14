# 商店-战斗场景融合设计

## 概述

将独立的商店场景与战斗场景合并为一个统一场景，类似云顶之弈的体验。选择地图后直接进入战斗场景，通过底部面板覆盖层提供商店功能，塔的布置和移动直接在真实地图上进行。

## 场景流程

### 旧流程
```
map_select → shop → main → shop → main → ... → result
```

### 新流程
```
map_select → main（商店阶段）→ main（战斗阶段）→ main（商店阶段）→ ... → result
```

不再有独立的 shop 场景。SceneManager 移除 `"shop"` 路由。

## 阶段状态机

main.gd 新增阶段枚举：

```gdscript
enum Phase { SHOP, BATTLE }
var current_phase: Phase
```

### SHOP 阶段
- 显示底部商店面板
- 玩家可自由移动
- 塔可拖拽放置/移动/收回
- 武器可拖拽装备
- WaveManager 暂停，敌人不生成

### BATTLE 阶段
- 底部面板向下滑出隐藏
- WaveManager 运行，正常战斗逻辑
- 塔不可拖拽

### 状态切换
- **SHOP → BATTLE：** 玩家点击"开战"按钮
- **BATTLE → SHOP：** `EventBus.wave_transition_ready` 触发后，切换回 SHOP 阶段，自动刷新商店，面板滑入
- **BATTLE → result：** 最终波次结束后跳转 result 场景（保持不变）

### 首次进入
`map_select` 跳转到 `main` 后，`_ready()` 初始化为 `Phase.SHOP`，调用 `ShopManager.refresh_shop(true)` 刷新首次商店。

## 底部商店面板 UI

### 节点结构
```
ShopOverlay (CanvasLayer, layer=10)
└── ShopPanel (PanelContainer, anchored bottom, ~120px height)
    ├── TopRow (HBoxContainer)
    │   ├── InfoBar: 💰金币 | Lv.X | 人口 X/X | Wave X
    │   ├── Spacer
    │   ├── LevelUpButton
    │   ├── RefreshButton (🔄 $2)
    │   └── StartBattleButton (开战▶)
    ├── ShopRow (HBoxContainer) — 4个商店槽位
    │   ├── ShopSlot0~3 (显示物品名+费用+稀有度边框)
    │   └── (点击购买进背包)
    └── BagRow (HBoxContainer) — 10格背包
        ├── BagSlot0~9 (可拖拽出去)
        └── (拖拽武器到玩家=装备，拖拽塔到地图=放置)
```

### 面板动画
- **SHOP → BATTLE：** 面板通过 Tween 向下滑出屏幕（~0.3s），`mouse_filter = IGNORE`
- **BATTLE → SHOP：** 面板通过 Tween 向上滑入（~0.3s）

### 脚本职责
- `shop_overlay.gd` — 管理面板显示/隐藏动画、购买/刷新/升级逻辑（从现有 shop.gd 迁移核心逻辑）
- `main.gd` — 管理阶段状态机，协调 ShopOverlay 和 WaveManager

ShopManager（RefCounted）保持不变，继续作为商店逻辑的核心被 shop_overlay.gd 使用。

## 拖拽交互系统

### DragManager（Node，Main 场景子节点）

统一的拖拽管理器，监听全局输入事件，管理拖拽状态。

### 拖拽流程

| 来源 | 目标 | 操作 |
|------|------|------|
| 背包塔槽 | 地图区域 | 部署塔（`GameData.deploy_tower`） |
| 背包武器槽 | 玩家角色 | 装备武器（`GameData.deploy_weapon`） |
| 地图上已放置的塔 | 地图其他位置 | 移动塔（`GameData.move_tower`） |
| 地图上已放置的塔 | 底部面板区域 | 收回背包（`GameData.undeploy_tower`） |

### 塔放置预览

拖拽塔时的视觉反馈：
- 半透明塔精灵跟随鼠标，吸附到网格中心
- 攻击范围圈（圆形，半径 = `tower_data.attack_range_per_level[level-1]`）
- 网格合法性提示：绿色 = 可放置，红色 = 被占用或越界

### 地图上塔的交互

- SHOP 阶段：已放置的塔可被鼠标按住拖起
- 拖起时原位显示虚线轮廓（表示"从这里拿走"）
- 拖到新位置松开 = 移动，拖到底部面板松开 = 收回背包
- BATTLE 阶段：塔不可拖拽

### 碰撞检测

- 放置/移动塔时检查目标网格是否已有其他塔（遍历 `GameData.deployed_towers` 的 `grid_pos`）
- 不允许重叠放置

### 输入处理优先级

- 拖拽操作时屏蔽玩家移动输入
- 底部面板 UI 点击（购买、刷新、升级）不触发拖拽，只有按住背包槽/地图塔并移动才算拖拽

## 塔的实时同步

不再使用"进场景时一次性恢复"模式。SHOP 阶段每次 deploy/undeploy/move 塔时，立即在 TowerContainer 中增删/移动真实塔节点：

- **deploy_tower：** 调用 `SceneFactory.create_tower()` 创建真实塔节点，添加到 TowerContainer
- **undeploy_tower：** 从 TowerContainer 中移除对应塔节点（`queue_free`）
- **move_tower：** 更新塔节点的 `position`（grid_pos → world_pos 转换）

战斗开始时不再需要 `_restore_towers()`，塔已经在场景中了。

## 现有系统改动

### 需要修改的文件

**main.gd：**
- 新增 `Phase` 枚举和 `current_phase`
- `_ready()` 初始化为 `Phase.SHOP`，刷新首次商店
- 监听"开战"信号 → 切 BATTLE，启动 WaveManager
- 监听 `wave_transition_ready` → 切 SHOP，刷新商店，滑入面板
- 移除 `_restore_towers()`（改为实时同步）

**scene_manager.gd：**
- 删除 `SCENES` 中的 `"shop"` 条目

**GameData：**
- 新增 `_next_deploy_id: int` 自增计数器，`deploy_tower()` 时为新条目分配 `deploy_id`
- 修改 `deploy_tower()` 返回值：从 `bool` 改为 `int`，成功时返回新条目的 `deploy_id`，失败时返回 `-1`
- `reset()` 时重置 `_next_deploy_id = 0`
- 新增 `move_tower(deploy_id: int, new_grid_pos: Vector2i) -> bool`：通过 `deploy_id` 查找条目，更新 `grid_pos`，不触发羁绊重算
- 修改 `undeploy_tower()` 接口：改为接受 `deploy_id: int` 而非数组索引，内部通过 `deploy_id` 查找条目

**hud.gd：**
- SHOP 阶段也显示（金币、等级、人口始终可见）
- 波次/计时/击杀信息在 SHOP 阶段隐藏或显示"准备中"

### 需要删除的文件
- `scenes/ui/shop.tscn`
- `scripts/ui/shop.gd`

### 需要新增的文件
- `scenes/ui/shop_overlay.tscn` — 底部面板 UI 场景
- `scripts/ui/shop_overlay.gd` — 面板逻辑
- `scripts/systems/drag_manager.gd` — 拖拽管理器

**wave_manager.gd：**
- 移除 `_ready()` 中的 `start_next_wave()` 自动调用（当前会在场景加载时立即开始波次）
- 改为由 main.gd 在 SHOP → BATTLE 切换时显式调用 `start_next_wave()`

**EventBus：**
- 新增 `tower_moved(deploy_id: int, old_pos: Vector2i, new_pos: Vector2i)` 信号（供 HUD/调试面板等监听）

### 不需要改动
- ShopManager（RefCounted）— 完全复用
- SceneFactory — 不变
- GameConfig / Resource 类 — 不变

## 补充说明

### 网格系统
统一使用 `GameConfig.GRID_SIZE = 16px` 网格。旧 shop.gd 使用的 64px 网格已废弃。塔占据 1 个 16px 格子，放置坐标为 `grid_pos * GRID_SIZE + GRID_SIZE / 2`（居中）。已有的 `deployed_towers` 中的 `grid_pos` 如果是旧 64px 格式需要迁移（乘以 4），但当前 develop 分支上不存在持久化存档，每次新游戏 `GameData.reset()` 会清空，因此无需数据迁移。

### 合成与塔节点同步
`GameData._check_merge()` 可能消耗 `deployed_towers` 中的塔。main.gd 通过监听 `EventBus.item_merged` 信号处理塔节点清理：
- 合成消耗的塔：从 TowerContainer 中找到对应塔节点并 `queue_free()`
- 合成结果进入 `bag`，不自动放置到地图（玩家需手动从背包拖出部署）
- 合成触发时播放合成特效

### 塔节点同步机制

不通过 EventBus 信号驱动塔节点同步（现有信号缺少必要信息）。改为由 DragManager 直接操作：

**稳定标识符：** 每个 deployed_towers 条目新增 `deploy_id: int` 字段（由 `GameData` 维护一个自增计数器 `_next_deploy_id`）。DragManager 内部用 `_tower_nodes: Dictionary`（key = `deploy_id`，value = 塔节点引用）映射。这样数组增删不影响映射关系。

**DragManager 负责拖拽相关的数据变更和节点操作：**
- **部署塔：** DragManager 调用 `GameData.deploy_tower(bag_index, grid_pos)` → 成功后，读取新增条目的 `deploy_id`，调用 `SceneFactory.create_tower()` 创建节点，设置 position，添加到 TowerContainer，记入 `_tower_nodes[deploy_id]`
- **收回塔：** DragManager 调用 `GameData.undeploy_tower(deploy_id)` → 成功后，从 `_tower_nodes[deploy_id]` 取出对应节点 `queue_free()`
- **移动塔：** DragManager 调用 `GameData.move_tower(deploy_id, new_grid_pos)` → 成功后，更新 `_tower_nodes[deploy_id].position`

**合成消耗已部署塔的处理：** `_check_merge()` 由 `ShopManager.buy_item()` 触发（不是 `deploy_tower()`）。shop_overlay.gd 在调用 `buy_item()` 前后快照 `deployed_towers`，diff 出被消耗的 `deploy_id` 列表，通知 DragManager 移除对应节点。具体流程：
1. `shop_overlay.gd` 保存快照：`var snapshot = GameData.deployed_towers.duplicate(true)`
2. 调用 `shop_manager.buy_item(slot_index)`
3. 对比快照与当前 `deployed_towers`，找出消失的 `deploy_id`
4. 调用 `DragManager.remove_tower_nodes(consumed_deploy_ids: Array[int])` 清理节点

**首次进入场景：** `_ready()` 时 `deployed_towers` 为空（新游戏 `reset()` 后），无需恢复。

**DragManager 持有 TowerContainer 和 Player 的引用（通过 main.gd 在 `_ready()` 中注入）。**

### BGM 阶段切换
由 main.gd 在阶段切换时手动调用 AudioManager：
- SHOP 阶段：`AudioManager.play_bgm("placement")`
- BATTLE 阶段：`AudioManager.play_bgm("battle")`
- SceneManager 不再负责 shop/main 之间的 BGM 切换

### SynergyEffectProcessor 生命周期
SynergyEffectProcessor 仅在 BATTLE 阶段激活：
- SHOP → BATTLE：调用 `processor.activate()`，开始处理 3/5 档机制效果
- BATTLE → SHOP：调用 `processor.deactivate()`，暂停所有机制效果

### 武器装备的拖拽目标检测
拖拽武器到玩家角色时，通过检查拖拽释放位置与玩家节点的距离判定：
- 检测半径：48px（3 个 GRID_SIZE，足够容错）
- 若释放位置在玩家 48px 范围内，执行 `GameData.deploy_weapon()`
- 若不在范围内，武器回到背包原位（取消操作）

### 塔的卖出
已部署的塔不支持直接从地图卖出。操作路径：拖回底部面板 → 收回背包 → 在背包中右键卖出。保持与现有卖出逻辑一致。

### 塔放置限制区域
放置/移动塔时，除了检查塔-塔重叠，还需要检查：
- 地图边界：`grid_pos` 必须在 `[0, MAP_GRID_WIDTH)` × `[0, MAP_GRID_HEIGHT)` 范围内
- 不检查玩家位置或敌人路径（玩家可以走开，敌人没有固定路径）

### 玩家死亡 / 游戏胜利
- 玩家死亡（BATTLE 阶段）：`EventBus.player_died` → 直接 `SceneManager.go_to("result")`，与现有行为一致
- 最终波次通关：`WaveManager` 检测到 `current_wave > total_waves` → `SceneManager.go_to("result")`，与现有行为一致
- SHOP 阶段不会触发死亡/胜利（无敌人、无伤害）
