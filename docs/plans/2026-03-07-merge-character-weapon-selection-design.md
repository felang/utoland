# 合并角色与武器选择设计文档

## 概要

将角色选择和武器选择合并为一个场景。武器不再由玩家自由选择，而是作为角色的初始配置项，三个角色各自带一把固定武器。

## 角色-武器对应

| 角色 | 武器 |
|------|------|
| 战士 (warrior) | 步枪 (rifle) |
| 游侠 (ranger) | 回旋镖 (boomerang) |
| 坦克 (tank) | 激光枪 (laser) |

## 变更清单

### 1. CharacterData 新增字段
- `@export var default_weapon: String = ""` — 存储武器 ID

### 2. 角色 .tres 文件更新
- `warrior.tres`: `default_weapon = "rifle"`
- `ranger.tres`: `default_weapon = "boomerang"`
- `tank.tres`: `default_weapon = "laser"`

### 3. 角色选择场景改造
- 改为卡片式布局，每张卡片展示：
  - 角色名称
  - 生命值、速度、伤害倍率
  - 自带武器名称
- 选择后自动设置 `GameData.selected_weapon = char_data.default_weapon`
- 跳转目标改为 `map_select`（跳过 weapon_select）

### 4. 删除武器选择
- 删除 `scenes/ui/weapon_select.tscn`
- 删除 `scripts/ui/weapon_select.gd`
- SceneManager 移除 `weapon_select` 条目
- Enums.Scene 移除 `WEAPON_SELECT`

### 5. 场景流程变更
```
之前: start_menu → character_selection → weapon_select → map_select → ...
之后: start_menu → character_selection → map_select → ...
```

## 不变的部分

- WeaponData 资源类、武器 .tres 文件 — 不动
- 武器系统代码（WeaponManager、Weapon、Projectile）— 不动
- GameData.selected_weapon 字段 — 保留，下游不变
- SceneFactory — 不动

## 数据流

```
角色选择 → CharacterData.default_weapon → GameData.selected_weapon
                                        → GameData.init_character()
         → SceneManager.go_to(map_select)
```
