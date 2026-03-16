# 游戏精简设计

## 目标

大幅精简武器、塔和系统，将游戏核心聚焦到 3 武器 + 3 塔的紧凑体验。

## 删除的系统

### 标签/羁绊系统（全部移除）

- `SynergyManager`（`scripts/systems/synergy_manager.gd`）
- `PairSynergyManager`（`scripts/systems/pair_synergy_manager.gd`）
- `SynergyEffectProcessor`（`scripts/systems/synergy_effect_processor.gd`）
- `SynergyData` Resource 类（`scripts/resources/synergy_data.gd`）
- `resources/synergies/` 目录下所有 `.tres` 文件
- GameData 中的羁绊相关字段和方法（`synergy_tag_counts`、`synergy_active_tiers`、`_synergy_manager`、`_pair_synergy_manager`）
- EventBus 中的羁绊信号（`synergy_changed`、`pair_synergy_activated`、`pair_synergy_deactivated`）
- 所有 Resource（WeaponData、TowerData、CharacterData）上的 `tag` 字段
- UI 中羁绊相关的显示逻辑

### 稀有度系统

- 移除 WeaponData/TowerData 上的 `rarity` 字段
- 移除 `Enums.WeaponRarity`、`Enums.TowerRarity`
- 统一所有武器/塔为同一价格
- 移除 ShopConfig 中 `cost_by_rarity` 和 `rarity_weights` 配置
- 商店物品池不再按稀有度权重抽取，改为等概率
- 移除 `upgrade_card_builder.gd` 和 `ui_constants.gd` 中的稀有度颜色逻辑
- 简化 `GameData.shop_slots` 结构：从 `{id, type, rarity, cost}` 改为 `{id, type, cost}`

### 删除的武器（9种）

| 武器 | 需删除的文件 |
|------|-------------|
| 步枪 rifle | `scripts/entities/weapons/bullet_weapon.gd`、`resources/weapons/rifle.tres` |
| 旋刃 blade | `scripts/entities/weapons/blade_weapon.gd`、`resources/weapons/blade.tres` |
| 霰弹枪 shotgun | `scripts/entities/weapons/shotgun_weapon.gd`、`resources/weapons/shotgun.tres` |
| 激光枪 laser | `scripts/entities/weapons/laser_weapon.gd`、`resources/weapons/laser.tres` |
| 加特林 minigun | `resources/weapons/minigun.tres` |
| 冰冻枪 ice_gun | `scripts/entities/weapons/ice_gun_weapon.gd`、`resources/weapons/ice_gun.tres` |
| 火箭筒 rocket | `scripts/entities/weapons/rocket_weapon.gd`、`resources/weapons/rocket.tres` |
| 闪电链 lightning | `scripts/entities/weapons/lightning_weapon.gd`、`resources/weapons/lightning.tres` |
| 火焰喷射 flamethrower | `scripts/entities/weapons/flamethrower_weapon.gd`、`resources/weapons/flamethrower.tres` |

### 删除的投射物

| 投射物 | 需删除的文件 |
|--------|-------------|
| 激光 | `scripts/entities/projectiles/laser_projectile.gd`、`scenes/entities/projectiles/laser_projectile.tscn` |
| 火箭 | `scripts/entities/projectiles/rocket_projectile.gd`、`scenes/entities/projectiles/rocket_projectile.tscn` |
| 闪电链 | `scripts/entities/projectiles/chain_projectile.gd`、`scenes/entities/projectiles/chain_projectile.tscn` |
| 火焰 | `scripts/entities/projectiles/flame_projectile.gd`、`scenes/entities/projectiles/flame_projectile.tscn` |
| 近战 | `scripts/entities/projectiles/melee_projectile.gd`、`scenes/entities/projectiles/melee_projectile.tscn` |

保留的投射物：`bullet_projectile`（弓和射手塔用）、`boomerang_projectile`（飞镖用）。

### 删除的塔（12种）

| 塔 | 需删除的文件 |
|----|-------------|
| 墙塔 stump | `resources/towers/stump.tres`、`scenes/entities/towers/stump.tscn` |
| 仙人掌 cactus | `scripts/entities/towers/tower_sniper.gd`、`resources/towers/cactus.tres`、`scenes/entities/towers/cactus.tscn` |
| 玫瑰 rose | `scripts/entities/towers/tower_burst.gd`、`resources/towers/rose.tres`、`scenes/entities/towers/rose.tscn` |
| 毒蘑菇 mushroom | `scripts/entities/towers/tower_aoe.gd`、`resources/towers/mushroom.tres`、`scenes/entities/towers/mushroom.tscn` |
| 藤蔓 vine | `scripts/entities/towers/tower_trap.gd`、`resources/towers/vine.tres`、`scenes/entities/towers/vine.tscn` |
| 蒲公英 dandelion | `scripts/entities/towers/tower_knockback.gd`、`resources/towers/dandelion.tres`、`scenes/entities/towers/dandelion.tscn` |
| 荆棘 thorn | `scripts/entities/towers/tower_thorn.gd`、`resources/towers/thorn.tres`、`scenes/entities/towers/thorn.tscn` |
| 爆竹竹 bamboo | `scripts/entities/towers/tower_bomb.gd`、`resources/towers/bamboo.tres`、`scenes/entities/towers/bamboo.tscn` |
| 猪笼草 pitcher | `scripts/entities/towers/tower_grab.gd`、`resources/towers/pitcher.tres`、`scenes/entities/towers/pitcher.tscn` |
| 橡树 oak | `scripts/entities/towers/tower_aura.gd`、`resources/towers/oak.tres`、`scenes/entities/towers/oak.tscn` |
| 薄荷 mint | `scripts/entities/towers/tower_buff.gd`、`resources/towers/mint.tres`、`scenes/entities/towers/mint.tscn` |
| 治愈花 heal_flower | `scripts/entities/towers/tower_heal.gd`、`resources/towers/heal_flower.tres`、`scenes/entities/towers/heal_flower.tscn` |

### 素材目录（保留不删）

`assets/weapons/`、`assets/towers/` 下被删除武器/塔的子目录暂时保留，不影响运行，未来可按需清理。

## 保留的武器（3种）

### 1. 弓 Bow（全新）

- **机制**: 单发射击，基础远程武器
- **weapon_type**: `"bow"`
- **需要**: 新脚本 `bow_weapon.gd`、新 Resource `bow.tres`、弓箭投射物复用 `bullet_projectile`
- **数值（3级）**: 参考步枪数值，具体待平衡

### 2. 飞镖 Boomerang（复用）

- **机制**: 飞出后返回，命中两次
- **weapon_type**: `"boomerang"`
- **复用**: 现有 `boomerang_weapon.gd` 和 `boomerang.tres`
- **改动**: 移除 `tag` 字段，移除 `rarity` 字段

### 3. 剑 Sword（全新）

- **机制**: 前方扇形挥砍，近战
- **weapon_type**: `"sword"`
- **区别于旋刃**: 旋刃是 360 度圆形，剑是前方扇形区域
- **需要**: 新脚本 `sword_weapon.gd`、新 Resource `sword.tres`、挥砍特效（不使用 melee_projectile，自行处理扇形检测）

## 保留的塔（3种）

### 1. 射手塔 Pea Shooter

- **机制**: 单体射击最近敌人
- **复用**: 现有 `tower_shooter.gd`、`pea_shooter.tres`、`pea_shooter.tscn`
- **改动**: 移除 `tag` 字段

### 2. 减速塔 Ice Flower

- **机制**: 光环持续减速范围内敌人
- **复用**: 现有 `tower_slow.gd`、`ice_flower.tres`、`ice_flower.tscn`
- **改动**: 移除 `tag` 字段

### 3. 向日葵 Sunflower

- **机制**: 定时生成金币
- **复用**: 现有 `tower_generator.gd`、`sunflower.tres`、`sunflower.tscn`
- **改动**: 移除 `tag` 字段

## 保留的系统

- **合成系统**: 3 个同类同级 → 升级，最高 Lv3，逻辑不变
- **人口系统**: 武器/塔各占 1 人口，保持不变
- **商店系统**: 保留刷新、购买、卖出，但移除稀有度权重，改为等概率抽取

## 经济调整

- 所有武器/塔统一价格（具体数值待定，建议 Lv1 = 3 金币）
- 卖出价格统一规则（Lv1 原价，Lv2/Lv3 按合成投入的 80%）
- ShopConfig 简化：移除 `cost_by_rarity`、`rarity_weights`，新增统一 `item_cost`

## 需要更新的系统

### 核心系统

- **Enums** (`scripts/core/enums.gd`): 精简 `WeaponId` 为 3 种（bow/boomerang/sword），`TowerId` 为 3 种（pea_shooter/ice_flower/sunflower），`ProjectileId` 移除 LASER/ROCKET/FLAME/CHAIN，移除 `Tag` 枚举，移除 `WeaponRarity`/`TowerRarity` 枚举
- **GameConfig**: 只注册 3 武器 + 3 塔，清理 `SPRITES["towers"]` 字典只保留 3 种塔
- **GameData**: 清除所有羁绊相关逻辑，保留 deploy/undeploy/merge/sell 核心逻辑
- **SceneFactory**: 只注册 3 种塔的创建方法，移除已删除投射物的工厂方法（`create_laser_projectile`、`create_rocket_projectile`、`create_chain_projectile`、`create_flame_projectile`、`create_melee_projectile`）
- **EventBus**: 移除羁绊信号

### 商店系统

- **ShopManager**: 简化物品池逻辑，移除稀有度权重
- **ShopConfig**: 移除 `cost_by_rarity`、`rarity_weights`，新增 `item_cost`

### 武器系统

- **WeaponManager**: 更新 `_create_weapon()` match 语句，只处理 bow/boomerang/sword
- **WeaponData**: 清理未使用的 export 组（laser、rocket、flame、lightning、ice 专属字段）

### 塔系统

- **TowerData**: 清理未使用的 export 组（burst、trap、knockback、grab、reflect、aura、buff、heal、bomb 专属字段）

### 角色系统

- **CharacterData**: 更新所有 5 个角色的 `recommended_weapon` 和 `recommended_tower`，指向保留的武器/塔

### UI 系统

- **HUD/ShopOverlay**: 移除羁绊显示 UI
- **upgrade_card_builder.gd**: 移除稀有度边框颜色逻辑
- **ui_constants.gd**: 移除 `get_rarity_color()`

### 测试

- **删除**: `test_synergy_manager.gd`、`test_synergy_effect_processor.gd`、`test_pair_synergy.gd` 等羁绊相关测试
- **更新**: 商店、武器、塔、经济、角色相关测试，移除稀有度和已删除武器/塔的测试用例

### 其他

- **`.godot/global_script_class_cache.cfg`**: 删除带 `class_name` 的脚本后需更新此文件，否则 headless 测试无法识别类名
