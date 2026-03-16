# 移除背包，购买即装备

## 目标

去掉背包（bag）中间层，商店购买武器直接装备到角色，购买塔进入放置模式直接布置到地图。简化玩家操作流程。

## 核心规则

1. **购买武器** → 直接加入 `deployed_weapons`，立即生效
2. **购买塔** → 进入放置模式，玩家在地图上选择位置，确认后加入 `deployed_towers`；取消则退款
3. **人口满了不能购买**（买=装备，受人口上限限制）
4. **合成** → 只检查 `deployed_weapons` + `deployed_towers`，3 同类同级自动合成

## 删除的内容

### GameData 字段和方法
- `bag: Array[Dictionary]` — 整个背包数组
- `get_bag_count()` — 背包计数
- `can_buy()` — 原来检查背包容量，改为检查人口
- `sell_from_bag()` — 从背包卖出
- `deploy_weapon()` / `undeploy_weapon()` — 从背包部署/收回武器
- `deploy_tower()` / `undeploy_tower()` — 从背包部署/收回塔
- `_DEFAULTS` 中的 `"bag": []` 条目

### ShopConfig 字段
- `bag_capacity` — 背包容量不再需要

### ShopOverlay UI
- 背包栏显示（10 格背包 UI）
- 从背包拖拽到地图/角色的交互

### DragManager 功能
- 从背包拖拽部署武器到玩家
- 从背包拖拽部署塔到地图
- 保留：地图上已布置塔的移动

## 修改的内容

### GameData

新增方法：
- `buy_and_equip_weapon(weapon_id: String) -> bool` — 检查人口，扣金币，加入 deployed_weapons，触发合成检查
- `buy_and_place_tower(tower_id: String, grid_pos: Vector2i) -> int` — 检查人口，扣金币，加入 deployed_towers（含 deploy_id），触发合成检查。返回 deploy_id，0=失败

修改方法：
- `can_buy()` → 改为 `can_deploy()`（已有，检查人口上限）
- `_check_merge()` — 删除 bag 扫描，只扫描 deployed_weapons + deployed_towers
- `_collect_items_by_id_level()` — 同上，删除 bag 扫描
- `reset()` — 删除 bag 重置，保留 starting_weapon 逻辑
- `sell_from_deployed_weapon()` / `sell_from_deployed_tower()` — 保持不变

### ShopManager

- `buy_item()` — 改为：武器直接调用 `GameData.buy_and_equip_weapon()`；塔返回"需要放置"的状态，由 UI 层处理放置流程
- 删除对 `GameData.bag` 的所有引用

### ShopOverlay UI

- 删除背包栏 UI
- 购买武器按钮：直接装备，刷新显示
- 购买塔按钮：进入放置模式（复用现有 DragManager 的塔放置逻辑），放置成功后扣款，取消则不扣款
- 购买按钮 disabled 条件：金币不足 OR 人口满

### DragManager

- 删除从背包拖拽的逻辑
- 保留：已布置塔在地图上的移动/重新定位

### _check_merge() 合成

合成后释放 2 个人口位（3 个 Lv1 消耗 3 人口，合成为 1 个 Lv2 只占 1 人口）。合成品保留在 deployed 中。

对于武器合成：3 个已装备的同武器合成为 1 个更高级武器，仍在 deployed_weapons 中。
对于塔合成：3 个已布置的同塔合成为 1 个更高级塔。合成后只保留其中一个塔的位置，另外 2 个塔实例从地图上移除。

## 不变的内容

- 合成规则（3 同类同级→升级，最高 Lv3，递归检查）
- 人口系统（player_level 1-7，人口上限 2-8）
- 卖出机制（从已装备武器/已布置塔直接卖出）
- 商店刷新、统一价格 3 金币
- 塔在地图上的移动（move_tower）
