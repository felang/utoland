# 类幸存者优先设计 — 跳过塔防阶段

日期：2026-03-08

## 目标

跳过塔布置（placement）阶段，先做好类幸存者核心玩法，之后再加回塔防部分。

## 游戏流程变更

```
原流程：start_menu → character_selection → map_select → placement → main → shop → placement → main → ... → result
新流程：start_menu → character_selection → map_select → main → shop → main → ... → result
```

## 变更范围

### 1. 场景跳转修改
- `map_select.gd`：选择地图后直接进入 MAIN（而非 PLACEMENT）
- `shop_manager.gd`：确认购买后直接进入 MAIN（而非 PLACEMENT）
- placement 场景/代码保留，不删除

### 2. 塔相关逻辑屏蔽
- `main.gd`：跳过 tower_inventory 恢复逻辑
- `shop_manager.gd`：运行时过滤掉塔相关 effect_type 的物品
- `item_effect_manager.gd`：塔相关逻辑自然不触发（无塔实体）
- `GameData`：塔相关字段保留不清理

### 3. 新增商店物品（约10-12个）

**武器强化类（3-4个）：**
- 弹速提升 — 投射物速度 +20%
- 射程增加 — 武器射程 +15%
- 暴击率 — 10% 概率双倍伤害
- 弹道分裂 — 投射物命中后分裂为2个小弹

**生存防御类（3-4个）：**
- 护盾 — 每波开始获得临时护盾（挡1次伤害）
- 回血 — 每波结束回复 10% 最大生命
- 减伤 — 受到伤害降低 10%
- 闪避 — 15% 概率闪避攻击

**移动机动类（3-4个）：**
- 加速靴 — 移动速度 +12%
- 磁铁 — 金币拾取范围 +50%
- 减速光环 — 周围敌人减速 15%
- 冲刺 — 每10秒自动短距冲刺（无敌帧）

稀有度分布：common 4-5个，rare 4-5个，epic 2-3个

### 4. 不变的部分
- 角色系统、武器系统、波次系统、敌人系统
- 角色亲和标签（engineer/tank 的工程亲和暂时无用）
- 塔相关代码/场景/资源文件保留
- 塔相关测试保留
