# 武器漂浮显示

## 目标

让已装备的武器在战斗中围绕角色漂浮显示，提供视觉反馈。类似 Brotato 的武器环绕效果。

## 核心行为

1. 每个已装备武器在角色周围显示一个彩色圆形占位精灵
2. 多个武器均匀分布在圆形轨道上
3. **无目标时**：武器沿轨道匀速环绕旋转
4. **有目标时**：武器转向目标方向（保持在轨道半径距离上）

## 视觉规格

- 占位图：彩色小圆形（约 6x6 px）
- 不同武器类型不同颜色：弓=绿色，飞镖=蓝色，剑=红色
- 环绕半径：20px
- 环绕速度：约 1 圈/2 秒（`TAU / 2.0` 弧度/秒）

## 实现改动

### WeaponManager（`scripts/entities/weapons/weapon_manager.gd`）

改为 `extends Node2D`（当前是 `extends Node`），作为武器精灵容器。

新增字段：
- `_orbit_radius: float = 20.0` — 环绕半径
- `_orbit_speed: float = TAU / 2.0` — 环绕角速度（无目标时）
- `_orbit_angle: float = 0.0` — 当前环绕基准角度
- `_weapon_sprites: Array[Sprite2D]` — 与 `_weapons` 一一对应的精灵

`_add_weapon()` 中创建对应 `Sprite2D`：
- 创建 6x6 彩色圆形纹理（`ImageTexture`，或简单用一个白色圆形 + `modulate` 着色）
- 根据 `weapon_type` 设置颜色（bow=绿, boomerang=蓝, sword=红）

`tick()` 中更新精灵位置：
- 无目标时：`_orbit_angle += _orbit_speed * delta`，每个武器按均匀分布的角度偏移放置
- 有目标时：计算玩家到目标的方向角度，所有武器朝该方向偏移（保持均匀分布但中心偏向目标方向）

### Weapon 基类（`scripts/entities/weapons/weapon.gd`）

新增只读属性：
- `weapon_color: Color` — 由 WeaponManager 根据 weapon_type 设置

无其他改动。武器逻辑（冷却、射击、伤害）完全不变。

### player.tscn

`WeaponManager` 节点类型从 `Node` 改为 `Node2D`（或在脚本中改 extends 即可，场景中该节点会自动适配）。

## 不变的内容

- 武器逻辑（冷却、射击、伤害计算、合成）
- 投射物系统
- 商店/购买流程
