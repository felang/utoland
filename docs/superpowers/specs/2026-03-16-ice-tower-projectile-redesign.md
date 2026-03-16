# 冰花塔投射物化重设计

## 概述

将冰花塔 (ice_flower) 从 Area2D 持续减速模式改为投射物射击模式。弹道命中敌人时施加持续时间减速效果，类似 PvZ 寒冰射手。

## 当前实现

- `tower_slow.gd` 使用 `SlowArea` (Area2D) 检测范围内敌人
- 敌人进入范围立即减速，离开范围立即恢复
- 无伤害，纯减速功能

## 目标实现

- 冰花塔改为射击型，复用 `tower_shooter.gd` 的射击逻辑
- 弹道命中单个敌人，造成低伤害 + 持续时间减速
- 无穿透、无溅射，与射手塔行为一致
- 弹道视觉暂复用现有 BulletProjectile，换冰蓝色精灵（后续增强）

## 设计详情

### 1. tower_shooter.gd 扩展

**移除 `_ready()` 中硬编码的 `tower_type = Enums.TowerId.PEA_SHOOTER`**。`tower_type` 由 `SceneFactory.create_tower()` 在实例化时注入，`_ready()` 中的赋值会覆盖工厂注入值，导致冰花塔被错误识别为射手塔。其他塔脚本（tower_generator）也有同样问题，一并移除。

在 `_apply_level_stats()` 中新增减速数据读取：

```gdscript
# 现有逻辑
damage = data.damage_per_level[current_level - 1]
fire_rate = data.fire_rate_per_level[current_level - 1]
attack_range = data.attack_range_per_level[current_level - 1]

# 新增：减速数据（仅冰花塔有这些字段）
if data.slow_ratio_per_level.size() > 0:
    slow_on_hit = data.slow_ratio_per_level[current_level - 1]
if data.slow_duration_per_level.size() > 0:
    slow_duration = data.slow_duration_per_level[current_level - 1]
```

在 `_shoot_nearest_enemy()` 创建弹道时传入减速参数：

```gdscript
var bullet = SceneFactory.create_bullet_projectile()
bullet.setup(damage, knockback_force, global_position, direction)
if slow_on_hit > 0.0:
    bullet.slow_on_hit = slow_on_hit
    bullet.slow_duration = slow_duration
```

### 2. TowerData Resource 类修改

`scripts/resources/tower_data.gd` 新增字段：

```gdscript
@export var slow_duration_per_level: PackedFloat32Array = []
```

类型使用 `PackedFloat32Array`，与现有 `slow_ratio_per_level` 保持一致。

`slow_ratio_per_level` 已存在，无需修改。

### 3. ice_flower.tres 资源更新

```
id = "ice_flower"
display_name = "冰花"
description = "射出寒冰弹，命中敌人造成伤害并减速。"

hp_per_level = [70, 125, 200]
damage_per_level = [3, 5, 8]
fire_rate_per_level = [0.8, 0.7, 0.6]
attack_range_per_level = [100, 120, 150]
slow_ratio_per_level = [0.3, 0.4, 0.5]
slow_duration_per_level = [1.5, 2.0, 2.5]
sell_price_per_level = [3, 7, 21]
```

### 4. tower_ice_flower.tscn 场景修改

- 根节点脚本从 `tower_slow.gd` 改为 `tower_shooter.gd`
- 移除 `SlowArea` 节点（Area2D + CollisionShape2D）
- 添加 `DetectArea` 节点（Area2D + CircleShape2D），collision_mask = 2
- 添加 `ShootTimer` 节点（Timer，one_shot=false，与射手塔一致）
- 保留 `Visual`（AnimatedSprite2D）和 `HealthComponent`

### 5. 清理

- 删除 `scripts/entities/towers/tower_slow.gd`（不再使用）
- 确认无其他引用后移除

## 不变的部分

- `SlowHandler` 组件：`apply_timed_slow()` 已支持持续时间减速
- `BulletProjectile`：已有 `slow_on_hit` / `slow_duration` 属性
- `SceneFactory.create_tower()`：无需修改
- `GameConfig` 加载逻辑：无需修改
- 射手塔 (pea_shooter)：无 slow 字段，行为不变

## 数据流

```
ShootTimer 超时
  → tower_shooter 查找 DetectArea 内最近敌人
  → SceneFactory.create_bullet_projectile()
  → 设置 damage + slow_on_hit + slow_duration
  → 弹道飞行命中敌人
  → Hitbox/Hurtbox 触发伤害
  → BulletProjectile 调用 enemy.slow_handler.apply_timed_slow(slow_on_hit, slow_duration, source_id)
  → 减速持续 N 秒后 SlowHandler 自动移除
```

## 前置条件

- `ice_flower.tres` 当前缺少 `damage_per_level` 和 `fire_rate_per_level`，必须在场景脚本切换前添加，否则 `tower_shooter._apply_level_stats()` 会数组越界崩溃
- 场景修改（步骤 4）必须在删除 `tower_slow.gd`（步骤 5）之前完成

## 风险与注意事项

- `tower_shooter.gd` 新增的减速字段对射手塔无影响（数组为空，值为 0）
- 合成系统不受影响（合成只关心 id 和 level）
- BulletProjectile 的 `slow_on_hit` 路径已验证会调用 `apply_timed_slow`（bullet_projectile.gd:80-84）
