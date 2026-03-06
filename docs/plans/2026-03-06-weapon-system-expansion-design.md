# 武器系统扩展设计

## 目标

将武器系统从 3 把同质直线射击武器（步枪/霰弹枪/狙击枪）重构为 3 把手感差异巨大的武器（步枪/回旋镖/激光枪），同时让武器系统具备可扩展性。

## 设计原则

- 操作爽感优先，平衡后调
- 方案 A：多弹道脚本 + 配置标记（每种弹道行为一个独立脚本）
- 配置驱动：武器参数全部在 GameConfig.WEAPONS 中定义

## 武器清单

| 武器 | 弹道类型 | 核心手感 |
|------|---------|---------|
| 步枪 (rifle) | bullet（直线单发） | 标准基准武器 |
| 回旋镖 (boomerang) | boomerang（去程+折返） | 双重命中，走位讲究 |
| 激光枪 (laser) | laser（瞬间射线贯穿） | 高频切割，一排穿透 |

删除：霰弹枪 (shotgun)、狙击枪 (sniper)

## 配置结构

GameConfig.WEAPONS 中每个武器增加 `projectile_type` 字段，区分弹道行为。

```gdscript
const WEAPONS = {
    "rifle": {
        "name": "步枪",
        "projectile_type": "bullet",
        "fire_rate": 0.1,
        "damage": 10.0,
        "bullet_count": 1,
        "bullet_speed": 600,
        "range": 300.0
    },
    "boomerang": {
        "name": "回旋镖",
        "projectile_type": "boomerang",
        "fire_rate": 0.8,
        "damage": 15.0,
        "speed": 350.0,
        "outbound_distance": 200.0,
        "return_speed_mult": 1.3,
        "range": 200.0
    },
    "laser": {
        "name": "激光枪",
        "projectile_type": "laser",
        "fire_rate": 0.15,
        "damage": 8.0,
        "beam_range": 400.0,
        "beam_width": 2.0,
        "beam_duration": 0.08,
        "range": 400.0
    }
}
```

## 回旋镖行为（boomerang.gd，继承 Area2D）

### 状态机

```
OUTBOUND（去程）→ 飞出 outbound_distance 后切换
RETURNING（回程）→ 每帧追踪玩家当前位置，到达后销毁
```

### 碰撞规则

- 去程：穿透所有敌人，每个敌人只受一次去程伤害
- 回程：同理，每个敌人只受一次回程伤害
- 同一敌人最多被同一个回旋镖命中 2 次（去 + 回各一次）
- 用 `_hit_outbound: Array` 和 `_hit_returning: Array` 记录已命中敌人

### 回收条件

- 回程时与玩家距离 < 15px → queue_free()
- 安全兜底：总生存时间超过 5 秒 → 强制 queue_free()

### 爽感设计

- 不会因命中而消失（和 bullet 的核心区别）
- 玩家走位可让回程路径扫过更多敌人
- 回程速度更快（return_speed_mult: 1.3）→ 手感利落

## 激光行为（laser_beam.gd，继承 Node2D）

### 核心区别

激光不是"飞行弹道"，而是瞬间射线判定。

### 发射流程

1. 玩家发射时，创建一条从玩家到最远距离的射线
2. 用 PhysicsDirectSpaceState2D.intersect_ray() 检测线上所有敌人
3. 对所有命中敌人造成伤害（全贯穿）
4. 生成 Line2D 视觉效果，持续约 0.08 秒后 Tween 淡出消失

### 职责分离

- 伤害逻辑：在 player.gd 发射时直接做射线检测并结算
- 视觉效果：laser_beam.gd 只负责 Line2D 显示和自动清理

### 对比

| | 子弹 | 回旋镖 | 激光 |
|---|---|---|---|
| 飞行时间 | 有 | 有 | 无（瞬间） |
| 碰撞检测 | Area2D 碰撞 | Area2D 碰撞 | 射线查询 |
| 穿透 | 不穿透 | 穿透 | 穿透 |
| 视觉存在时间 | 飞行中 | 飞行中 | ~0.08s 闪现 |

## 文件变更

### 新增文件

| 文件 | 类型 | 说明 |
|---|---|---|
| scripts/entities/boomerang.gd | 脚本 | 回旋镖弹道行为 |
| scenes/boomerang.tscn | 场景 | 回旋镖实体（Area2D + CollisionShape2D + Sprite2D） |
| scripts/entities/laser_beam.gd | 脚本 | 激光视觉效果（Line2D + Tween 淡出） |
| scenes/laser_beam.tscn | 场景 | 激光视觉实体 |

### 修改文件

| 文件 | 改动 |
|---|---|
| game_config.gd | 替换 WEAPONS 配置（删除 shotgun/sniper，新增 boomerang/laser） |
| scripts/entities/player.gd | shoot_bullet() → shoot_weapon()，按 projectile_type 分发 |
| scripts/core/scene_factory.gd | 新增 create_boomerang()、create_laser_beam() |
| scripts/ui/weapon_select.gd | 数据驱动生成按钮，移除硬编码 |
| scenes/ui/weapon_select.tscn | 移除硬编码按钮，改为动态容器 |

## 不做的事项

- 武器商店升级
- 数值平衡精调（后续迭代）
- 武器切换（选定后固定）
