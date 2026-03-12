# 塔放置系统设计

## 概述

将塔放置功能重新加入游戏流程，改造现有 `placement.tscn` 为统一的"准备阶段"界面，包含布置 Tab 和商店 Tab，通过顶部 Tab 切换。左侧 120px 窄侧栏，右侧地图网格。

## 游戏流程

```
首波：map_select → placement(仅布置Tab) → main
后续：main(波次结束) → placement(布置Tab + 商店Tab) → main
全部完成/死亡：main → result
```

- 首波时 `GameData.current_wave == 0`，商店 Tab 隐藏
- 波次结束后进入 placement，`current_wave >= 1`，商店 Tab 可见，默认激活商店 Tab
- `map_select.gd` 改为 `go_to(PLACEMENT)`（`GameData.reset()` 仍在进入 placement 前调用）
- `main.gd` 波次结束后改为 `go_to(PLACEMENT)`
- `placement._start_battle()` 不修改 `current_wave`，波次推进由 `wave_manager.start_next_wave()` 负责

## 场景结构

```
Placement (Node2D)
├── Background/BackgroundSprite
├── Player (冻结)
├── MapBoundary
├── GridOverlay
├── RangeIndicator
├── PlacementCamera (Camera2D)
└── UI (CanvasLayer)
    └── SidePanel (VBoxContainer, 120px, 锚定左侧全高)
        ├── TabBar (HBoxContainer)
        │   ├── PlacementTab (Button)
        │   └── ShopTab (Button)
        ├── CoinsLabel
        ├── PlacementContent (VBoxContainer) ← Tab切换显隐
        │   └── TowerList (VBoxContainer, 塔卡片×3)
        ├── ShopContent (VBoxContainer) ← Tab切换显隐
        │   ├── ShopItemList (VBoxContainer, 物品×4)
        │   └── RefreshButton
        └── StartBattleButton
```

- `SidePanel` 锚定左侧全高，固定 120px 宽
- `PlacementContent` 和 `ShopContent` 通过 `visible` 切换
- `CoinsLabel` 和 `StartBattleButton` 两个 Tab 共享
- 输入路由：SidePanel 设 `mouse_filter = STOP` 阻断输入穿透；`placement.gd._input()` 中鼠标事件需检查 `get_global_mouse_position().x > 120` 再处理地图交互；滚轮缩放同理跳过侧栏区域
- ESC 键：有预览时取消放置；无预览时打开暂停菜单（复用 PauseOverlay）

## 脚本拆分

```
scripts/ui/placement.gd          — 主控：场景初始化、Tab切换、流程控制、相机、网格、开始战斗
scripts/ui/placement_panel.gd    — 布置侧栏：塔卡片管理、选中/拖放交互、放置/移除逻辑
scripts/ui/shop_panel.gd         — 商店侧栏：复用 ShopItemGenerator + ShopEffectApplier
```

### placement.gd（主控）

职责：
- 场景初始化：加载地图背景、网格覆层、范围指示器、相机
- Tab 切换：控制 PlacementContent / ShopContent 的 visible
- 相机控制：WASD 平移、滚轮缩放（复用现有逻辑）
- `_start_battle()`：收集塔写入 `GameData.tower_inventory`，跳转 main（不修改 `current_wave`）
- 首波/非首波判断：控制商店 Tab 是否显示

### placement_panel.gd（布置侧栏）

挂在 `PlacementContent` 节点上。

职责：
- 管理 3 个塔卡片 UI（射手/墙/减速），显示图标、名称、价格
- 金币不足时禁用卡片
- 点击选中：卡片高亮 → 地图上预览跟随鼠标 → 左键放置
- 拖放：`_gui_input()` 检测按下+移动>5px → 创建半透明预览 → 进入地图区域(x>120px)后吸附网格+显示范围指示器 → 松开放置
- 放置/移除逻辑：复用现有 `_can_place_at()`、`_place_tower()`、`_remove_tower_at()`
- 金币扣除/全额退还
- 右键点击已放置的塔移除

### shop_panel.gd（商店侧栏）

挂在 `ShopContent` 节点上。

职责：
- 复用 `ShopItemGenerator.generate_items()` 生成 4 件物品（`locked_slots` 传 `[false, false, false, false]`，不支持锁定槽）
- 物品卡片紧凑纵向列表（名称 + 简述 + 价格），带稀有度颜色条
- 点击购买，复用 `ShopEffectApplier.apply_effect()` 应用效果
- 刷新按钮：花费金币重新生成物品
- 购买/刷新后同步金币显示

## 放置规则

- 32px 网格对齐（复用现有 `_get_grid_position()`）
- 任意空位可放置（不重叠、不在玩家位置）
- 合法性颜色反馈：白色半透明=可放，红色半透明=不可放
- 移除已放置的塔全额退还金币
- 3 种塔固定可用（shooter、wall、slow），金币限制

## 拖放交互

从侧栏拖出：
1. 塔卡片 `_gui_input()` 检测鼠标按下+移动超过 5px 阈值
2. 创建半透明塔预览（`SceneFactory.create_tower()`）跟随鼠标
3. 鼠标进入地图区域（x > 120px）后预览吸附网格，显示范围指示器
4. 松开放置，复用 `_can_place_at()` 验证 + `_place_tower()` 执行

点击放置（保留现有方式）：
1. 点击塔卡片 → 选中状态（高亮）→ 预览跟随鼠标
2. 左键点击地图放置
3. 右键或 ESC 取消

两种方式共用同一套预览、验证、放置底层逻辑。

## 商店 Tab 集成

- 复用现有 `ShopItemGenerator` 和 `ShopEffectApplier`，不重新实现
- 永久移除 `shop_item_generator.gd` 中的 `TOWER_EFFECT_TYPES` 过滤，塔升级类物品（塔再生、塔链接、共生、战争机器等）重新出现在商店中
- 不再需要锁定槽功能（侧栏空间有限）
- 退役独立商店场景：删除 `scenes/ui/shop.tscn`，从 `SceneManager.SCENES` 中移除 `SHOP` 条目，`shop_manager.gd` 保留但不再被路由调用（核心逻辑迁移到 `shop_panel.gd`）

## 数据持久化

### GameData 改动

- 现有 `tower_inventory: Array`（`{type, position}` 字典数组）保持不变
- 现有 `purchased_towers: Array` 保持不变
- 不新增字段，首波判断用 `current_wave == 0`

### 塔 HP 策略

- 塔在波间全回满 HP。`placement` 从 `tower_inventory` 恢复塔时创建全新实例，不保存战斗中的 HP 状态。这简化了实现，也给玩家一个波间喘息机会。

### main.gd 改动

- `_ready()` 中读取 `GameData.tower_inventory`，通过 `SceneFactory.create_tower()` 还原所有塔到战场
- 波次结束后 `go_to(PLACEMENT)` 替代 `go_to(SHOP)`
- `item_effect_manager.gd` 的塔相关被动效果（塔再生、战场维修等）恢复生效

## 测试策略

- **placement_panel 测试**：塔选中、放置、移除、金币扣除/退还、金币不足禁用
- **shop_panel 测试**：物品生成、购买、刷新、金币同步
- **Tab 切换测试**：切换显隐正确、金币共享、首波隐藏商店 Tab
- **流程测试**：map_select → placement → main → placement(含商店) 场景切换
- **拖放测试**：拖放阈值、网格吸附、越界取消
- **商店过滤恢复测试**：塔相关物品不再被过滤
- **输入路由测试**：侧栏区域点击不触发地图交互

## 音效

- 塔放置：`AudioManager.play("tower_place")`（新增音效）
- 塔移除：`AudioManager.play("tower_remove")`（新增音效）
- 商店购买：复用现有 `shop_buy`
- Tab 切换：无音效（轻量操作）
