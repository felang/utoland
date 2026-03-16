# 商店阶段重构设计

## 背景

之前移除了备战背包机制，商店需要相应重构：去除残留的背包 UI、将简陋的按钮商店槽改为卡片 UI、完善购买即部署流程、增加回收区卖出机制。

## 设计目标

1. 清理背包系统残留（`BagRow` 节点、调试代码）
2. 商店卡片 UI：4 张卡片展示图标 + 名称 + 价格
3. 购买武器 → 立即装备并在角色身上显示旋转武器
4. 购买塔 → 进入放置模式，成功放置后扣金币
5. 拖拽到回收区卖出武器/塔
6. 人口满时智能判断：能触发合成的物品仍可购买
7. 自动三合一（已有逻辑，需修复武器合成的视觉同步）

## UI 布局

### ShopOverlay 两行结构

```
TopRow (信息栏):
  [金币: $XX] [等级: Lv.X] [人口: X/X] [波次: Wave X]

BottomRow (操作栏):
  [卡片1] [卡片2] [卡片3] [卡片4] | [刷新 $2] [Lv↑ $X] | [回收区] | [开战]
```

### 卡片结构

每张卡片为一个自定义控件（`PanelContainer` 或 `VBoxContainer`），内部：

- 上方：物品图标（`TextureRect`，从 `WeaponData`/`TowerData` 的 icon 路径加载）
- 中间：名称（`Label`）
- 下方：价格（`Label`，如 "$3"）

卡片状态：
- **可购买**：正常显示，可点击
- **金币不足**：灰显，按钮禁用
- **人口满且无法触发合成**：灰显，按钮禁用
- **已售出**：灰显 + "已售出"文字

### 回收区

- 位于底部操作栏右侧（开战按钮左边）
- 视觉：垃圾桶/回收图标
- 拖拽物品经过时高亮，显示返还金额（如 "$3"）
- 商店阶段可见，战斗阶段随面板隐藏

## 购买流程

### 购买武器

1. 点击武器卡片
2. `ShopManager.buy_weapon(slot_index)` → `_validate_slot()` 验证金币 + `can_buy_item()` → 扣金币
3. `GameData.buy_and_equip_weapon()` → 加入 `deployed_weapons` → 触发 `_check_merge()`
4. **即时视觉更新**：调用 `WeaponManager.add_weapon(id, level)` 在角色身上生成武器节点加入旋转轨道
5. 若合成发生：`WeaponManager` 同步更新（移除旧武器节点，生成升级后武器节点）
6. 卡片标记为已售出，刷新 UI

### 购买塔

1. 点击塔卡片 → 卡片显示"放置中"状态，**其他所有卡片和开战按钮禁用**
2. `DragManager.start_tower_placement(tower_id, on_placed_cb, on_cancelled_cb)`
3. 玩家在地图上选择位置，此时**不扣金币**
4. 成功放置：
   - `ShopManager.confirm_tower_purchase(slot_index, grid_pos)` → **重新验证**金币 + `can_buy_item()` → 扣金币
   - `DragManager.spawn_tower_node()` 生成塔节点
   - 触发合成检查 + `_handle_merge_tower_cleanup()` 清理被合成的塔节点
   - 合成后存活塔的视觉需更新：`DragManager.upgrade_tower_node(deploy_id, new_level)` 刷新精灵和射程
   - 卡片标记为已售出，恢复其他卡片和开战按钮
5. 取消放置：卡片恢复可点击状态，恢复其他卡片和开战按钮，不扣金币

## 卖出流程

### 拖拽卖出塔

1. 商店阶段，玩家拖拽地图上的塔（`DragManager` 已有的 `start_map_tower_drag` 逻辑）
2. 拖到回收区释放 → `GameData.sell_from_deployed_tower(deploy_id)` → 返还金币，移除塔节点
3. 拖到地图其他位置 → 保持现有移动逻辑

### 拖拽卖出武器

1. 商店阶段，每个围绕角色旋转的武器节点添加 `Area2D` 碰撞区域用于点击检测
2. 玩家点击某个武器 → `DragManager.start_weapon_drag(weapon_index)` → 武器节点半透明，生成拖拽预览
3. 拖到回收区 → `GameData.sell_from_deployed_weapon(index)` → 返还金币，`WeaponManager.remove_weapon(index)` 移除武器节点
4. 拖到其他地方 → 取消，武器回原位，恢复不透明

### 回收区视觉反馈

- 拖拽物品经过回收区时高亮
- 显示返还金额
- 释放后恢复正常

## 人口上限 + 合成联动

人口满时不是简单禁用所有卡片，而是逐张判断。

`GameData` 新增 `can_buy_item(item_id: String, item_level: int) -> bool`：

1. 如果 `can_deploy()` 为 true → 返回 true
2. 否则统计已部署中同 `item_id` + 同 `item_level`（level=1，因为商店卖的都是 Lv1）的数量
3. 数量 ≥ 2 → 返回 true（买入后触发 3→1 合成，净减少 2 人口）
4. 否则返回 false

### 验证层改动

`can_buy_item()` 需要在**所有三层**替换 `can_deploy()`：

1. **UI 层**：`shop_overlay.gd` 卡片禁用判断从 `can_deploy()` 改为 `can_buy_item(slot.id, 1)`
2. **ShopManager 层**：`_validate_slot()` 中的 `can_deploy()` 改为 `can_buy_item(slot.id, 1)`
3. **GameData 层**：`buy_and_equip_weapon()` 和 `buy_and_place_tower()` 中的 `can_deploy()` 改为 `can_buy_item(item_id, 1)`

合成触发时会临时超出人口上限（cap+1），但 `_check_merge()` 会立即将 3 个合为 1 个，最终人口回落。这是合法的临时状态。

## 清理项

1. **删除 `BagRow`** — 从 `shop_overlay.tscn` 移除废弃节点
2. **删除 `_debug_spawn_towers()`** — `main.gd` 中的调试代码
3. **实现 `_handle_merge_weapon_cleanup()`** — 从 no-op stub 改为调用 `WeaponManager` 更新武器节点（移除旧武器，添加升级后武器）
4. **实现 `DragManager.upgrade_tower_node()`** — 合成后存活塔的精灵和射程需刷新为新等级
5. **清理废弃信号** — `EventBus` 中 `item_deployed` 和 `item_undeployed` 未使用，考虑移除

## 改动文件清单

| 文件 | 改动 |
|------|------|
| `scenes/ui/shop_overlay.tscn` | 重构：删 BagRow，ShopSlot 改为卡片布局，两行结构，新增回收区 |
| `scripts/ui/shop_overlay.gd` | 卡片渲染逻辑，回收区交互，用 `can_buy_item()` 替代 `can_deploy()` |
| `scripts/systems/shop_manager.gd` | 小改：配合卡片数据提供图标/名称信息 |
| `scripts/core/game_data.gd` | 新增 `can_buy_item(item_id, level) -> bool` |
| `scripts/systems/drag_manager.gd` | 新增：武器拖拽、回收区检测、`upgrade_tower_node()` |
| `scripts/entities/weapons/weapon_manager.gd` | 新增 `add_weapon(id, level)` / `remove_weapon(index)` 热更新方法 |
| `scripts/entities/weapons/weapon_base.gd` (或各武器脚本) | 武器节点添加 `Area2D` 用于商店阶段点击检测 |
| `scripts/ui/main.gd` | 删除调试代码，确保 WeaponManager 热更新连通 |
| `scripts/core/event_bus.gd` | 可选：清理废弃信号 |

## 定价

当前所有物品统一价格 `ShopConfig.item_cost = 3`，本次重构保持不变。卡片上显示的价格从 slot 数据读取。稀有度差异定价留待未来扩展。

## 不涉及

- 新 Resource 类
- 新 Autoload 单例
- 新场景文件（卡片用代码在现有场景中构建）
- 稀有度系统（未来需要时再扩展）
