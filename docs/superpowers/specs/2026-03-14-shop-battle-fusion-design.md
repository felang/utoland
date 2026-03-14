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
- 新增 `move_tower(tower_index: int, new_grid_pos: Vector2i) -> bool`
- 更新 `deployed_towers[tower_index].grid_pos`，不触发羁绊重算

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

### 不需要改动
- ShopManager（RefCounted）— 完全复用
- SceneFactory — 不变
- WaveManager — 不变，触发方式从场景切换变为阶段切换
- EventBus — 现有信号足够
- GameConfig / Resource 类 — 不变
