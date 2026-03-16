# 塔美术资源设计

## 概述

为 3 座塔（射手塔、减速塔、金币塔）设计完整的美术资源方案，包括塔精灵、弹道精灵和等级装饰。

## 设计决策

| 决策项 | 选择 |
|---|---|
| 精灵来源 | 每个塔独立精灵文件（不再用 tileset 图集） |
| 动画 | 简单动画：idle 待机 + attack 攻击 |
| 等级区分 | 基础精灵 + 等级叠加装饰（光圈/粒子） |
| 弹道精灵 | 有特色的专属，不需要弹道的塔不制作 |
| 底座 | 不需要，精灵本身包含底部 |
| 精灵尺寸 | 按精灵自身尺寸渲染，不统一 |

## 资源清单

### 射手塔 (pea_shooter)

| 文件 | 尺寸 | 说明 |
|---|---|---|
| `assets/towers/pea_shooter/sprite.png` | ~24x24 | 基础精灵，兼作商店/背包图标（通过 TowerData.icon_path 引用） |
| `assets/towers/pea_shooter/idle.png` | ~24x24 x 2-4帧 | idle 动画帧序列（轻微摇摆） |
| `assets/towers/pea_shooter/attack.png` | ~24x24 x 2-3帧 | 攻击动画帧序列（射击后坐力） |
| `assets/projectiles/pea.png` | ~8x8 | 专属弹道 — 豌豆 |

### 减速塔 (ice_flower)

| 文件 | 尺寸 | 说明 |
|---|---|---|
| `assets/towers/ice_flower/sprite.png` | ~16x16 | 基础精灵，兼作图标 |
| `assets/towers/ice_flower/idle.png` | ~16x16 x 2-4帧 | idle 动画帧序列（冰晶闪烁/呼吸） |
| `assets/towers/ice_flower/attack.png` | ~16x16 x 2-3帧 | 攻击动画帧序列（释放冰气） |

> ice_flower 是 AOE 减速塔（通过 SlowArea 区域减速），不发射弹道，无需弹道精灵。

### 金币塔 (sunflower)

| 文件 | 尺寸 | 说明 |
|---|---|---|
| `assets/towers/sunflower/sprite.png` | ~16x16 | 基础精灵，兼作图标 |
| `assets/towers/sunflower/idle.png` | ~16x16 x 2-4帧 | idle 动画帧序列（花瓣摇曳） |
| `assets/towers/sunflower/attack.png` | ~16x16 x 2-3帧 | 产金动画帧序列（发光/弹出金币） |

> sunflower 不需要弹道精灵，金币使用已有的 `assets/items/gold_coin.png`。

### 共享等级装饰

| 文件 | 说明 |
|---|---|
| `assets/towers/shared/lv2_glow.png` | Lv2 光圈/光晕叠加层 |
| `assets/towers/shared/lv3_glow.png` | Lv3 增强光圈（更亮/换色） |

等级装饰在运行时叠加到塔精灵上方，所有塔共用。

## 总计

- 塔精灵：9 张（3 塔 x 3 张）
- 弹道精灵：1 张（豌豆）
- 等级装饰：2 张（共享）
- **合计 12 张**

## 实现关联

### 场景改造

- **pea_shooter / ice_flower**：当前 `.tscn` 中 `Sprite2D` 节点使用 `tileset_towers.png` + `region_rect` 裁切。需改为加载独立 `sprite.png`，并将 `Sprite2D` 替换为 `AnimatedSprite2D`（支持 idle/attack 动画）
- **sunflower**：当前使用 `ColorRect` 占位，需替换为 `AnimatedSprite2D` 节点，保持与其他塔一致的结构

### 动画系统

- 每个塔创建 `SpriteFrames` 资源（`.tres`），包含 `idle` 和 `attack` 两个动画
- 帧从对应的 `idle.png` / `attack.png` 帧序列切分
- `AnimatedSprite2D` 默认播放 `idle` 动画
- 塔脚本在攻击时调用 `play("attack")`，攻击动画结束后自动回到 `idle`

### TowerData 字段

- `icon_path` 已存在（当前为空字符串），填入 `sprite.png` 路径即可
- 弹道精灵路径：pea_shooter 的 `pea.png` 需要通过 bullet projectile 的可配置精灵机制加载（在 SceneFactory 或 tower_shooter 脚本中支持传入弹道精灵路径）

### 清理

- `tileset_towers.png` 不再使用，可在实现完成后删除
- 各塔子目录下的 `.gitkeep` 在放入实际资源后删除
