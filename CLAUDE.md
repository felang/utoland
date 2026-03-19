# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

utoland 是一个基于 **Godot 4.6** 的 2D 塔防 + 射击混合类游戏（自走棋经济模式）。玩家选择角色，在波次战斗中击杀敌人获取经验球升级（提升人口上限）。波次结束后获得固定金币奖励，进入商店花金币购买武器/塔。购买武器立即装备，购买塔进入拖拽放置。3 个同类同级物品自动合成升级（最高 3 级）。武器和塔共用人口上限（无上限，由经验曲线自然限制）。

**武器（3 种）**: 弓箭(bow)、手里剑(shuriken)、剑(sword)

**防御塔（3 种）**: 射手塔(pea_shooter)、冰花(ice_flower，射击型减速塔)、向日葵(sunflower)

## 空间系统

- **网格单位**: 32px（PPU = GRID_SIZE = 32）
- **视口**: 960×540（1080p 的 2x 整数缩放，stretch mode = viewport）
- **地图**: 1440×960 像素（45×30 格）
- **精灵**: 当前素材为 16px，通过 `SpriteAnimator._apply_scale()` 自动 scale 2x 适配 32px 格子（`ENTITY_SIZE_STANDARD / frame_size`）
- **实体尺寸**: 标准 32px（`ENTITY_SIZE_STANDARD`），坦克 64px（`ENTITY_SIZE_TANK`）
- **空间值规范**: 所有距离、速度、范围等空间数值基于 32px 网格。新增空间值时参考现有数值比例

## 运行与测试

- **运行项目**: 通过 Godot 编辑器运行，或使用 gdai-mcp 插件的 `run_project` 工具
- **测试框架**: GUT (Godot Unit Test)，配置见 `.gutconfig.json`
- **测试目录**: `tests/unit/` (单元测试), `tests/integration/` (集成测试)
- **测试命名**: 文件前缀 `test_`，测试方法前缀 `test_`，继承 `GutTest`
- **渲染器**: GL Compatibility (兼容模式)
- **物理引擎**: Jolt Physics

## 架构

### Autoload 单例 (全局可用，加载顺序有依赖)

- **GameConfig** (`scripts/core/game_config.gd`) — 资源注册表，运行时从 `resources/` 目录加载 `.tres` 配置文件（武器、敌人、塔、波次、角色、地图、特效、精灵等）。必须最先加载（后续 Autoload 依赖它）。
- **PlayerState** (`scripts/core/player_state.gd`) — 角色身份、属性、被动系统、player_stats、selected_map、current_wave、pending_heal。`init_character(id)` 从 CharacterData 初始化属性，`reset()` 重置。
- **PlayerProgression** (`scripts/core/player_progression.gd`) — 经验/等级/人口上限。`add_exp(amount)` 累加经验自动升级，`exp_for_level(n)` 经验公式，`get_population_cap()` 公式化人口上限。
- **InventoryManager** (`scripts/core/inventory_manager.gd`) — 金币、deployed_weapons/towers、shop_slots、buy/sell/merge、deploy_id。依赖 PlayerState 和 PlayerProgression。`buy_and_equip_weapon()`/`buy_and_place_tower()` 购买即部署，`can_buy_item()` 智能人口判断（考虑合成释放人口），`_check_merge()` 合成系统。
- **StatsTracker** (`scripts/core/stats_tracker.gd`) — 战斗统计：击杀、金币、伤害、连杀。`record_kill()`/`reset_kill_streak()`/`record_damage_taken()`/`record_coins_earned()`。
- **SceneFactory** (`scripts/core/scene_factory.gd`) — 集中管理场景实例化与对象池。提供 `create_tower()`, `create_enemy()`, `create_exp_orb()`, `create_coin()`, `create_projectile()` 等工厂方法。高频对象（投射物、普通敌人 normal/fast/tank、金币、经验球）内部走对象池复用，对外创建 API 不变。回收通过 `release_enemy()` / `release_coin()` / `release_exp_orb()` / `release_projectile()` 替代 `queue_free()`。预热：`warmup_initial()`（main 场景加载时）+ `warmup_for_wave(wave_data)`（每波开始前）。`clear_all_pools()` 在场景退出时清理。创建实体必须通过此工厂。**容器管理**：`init_containers(entity_layer, projectile_layer, pickup_layer)` 由 main.gd 调用，之后通过 `get_entity_layer()/get_projectile_layer()/get_pickup_layer()` 获取对应容器。实体添加到场景树必须用正确的容器（测试环境自动 fallback 到 current_scene）。
- **EffectsManager** (`scripts/systems/effects_manager.gd`) — 特效管理：伤害数字、击中火花、死亡爆炸、红闪（flash_hit）、击中抖动（sprite_shake）、增强死亡特效（spawn_enhanced_death）、Boss 击杀慢动作（hitstop）等视觉效果。
- **AudioManager** (`scripts/systems/audio_manager.gd`) — 音效管理：SFX 通过 AudioStreamPlayer 池化播放 `play(sound_id)`，BGM 通过独立 AudioStreamPlayer 播放 `play_bgm(track_id)` / `stop_bgm()` / `fade_bgm(duration)`。SFX 放 `assets/sfx/`，BGM 放 `assets/bgm/`。
- **EventBus** (`scripts/core/event_bus.gd`) — 全局事件总线，用于跨系统解耦通信。商店信号：`item_purchased/item_sold/item_merged/player_level_changed/tower_moved`。战斗信号：`wave_started/wave_completed/wave_transition_ready/enemy_killed/boss_killed/boss_escaped/coins_changed/coins_generated`。经验信号：`exp_collected/exp_changed`。
- **SceneManager** (`scripts/core/scene_manager.gd`) — 集中管理场景切换，提供 `go_to(scene_name)` 方法（带淡入淡出过渡动画，async）。自动根据 SCENE_BGM 映射切换 BGM。所有场景路径在此统一维护，禁止直接调用 `get_tree().change_scene_to_file()`。

### 游戏流程 (场景切换)

```
start_menu → character_selection → map_select → main（SHOP 阶段，首次用初始金币购买）
    ↓ (点击"开战")
  main（BATTLE 阶段，战斗，拾取经验球升级）→ 波次结束 → main（SHOP 阶段，+固定金币奖励，自动刷新商店）
    ↓ (点击"开战")
  main（BATTLE 阶段，下一波战斗）→ ... → result (结算)
```

> **商店与战斗融合**: 不再有独立的商店场景。main 场景通过 `Phase` 状态机（SHOP/BATTLE）管理两个阶段。SHOP 阶段左侧面板（`ShopOverlay`，CanvasLayer layer=10）采用卡片式 UI：信息栏（金币/等级/人口/波次）+ 4 张物品卡片 + 刷新按钮 + 回收区 + 开战按钮。购买武器立即装备到角色，购买塔进入拖拽放置模式。拖拽已部署的塔或武器到回收区可卖出。人口满时能触发合成的物品仍可购买（`can_buy_item` 智能判断）。开战后面板滑出隐藏，波次结束后滑回。
>
> **波次系统（纯时间制）**: 共 15 波，每 5 波一个 Boss（第 5 波 boss_brute、第 10 波 boss_summoner、第 15 波 boss_guardian）。波次仅以时间结束（时间到清场），击杀敌人不影响波次进度。每波分 2-3 个生成阶段（`SpawnPhaseData`），前慢后快。`max_alive_enemies` 控制场上同时存在的敌人上限。Boss 波次时间到但 Boss 未被击杀会触发 `boss_escaped` 信号。难度缩放从第 11 波开始（HP/伤害指数增长）。WaveData 配置：`time_limit`（逐波递增 40s→90s）、`spawn_phases`、`max_alive_enemies`、`enemy_weights`、`elite_chance`。
>
> **双轨经济**: 金币来源：初始金币 + 每波固定奖励（`ShopConfig.wave_reward`）+ 向日葵生成。经验来源：怪物掉落经验球（`ExpOrb`），玩家拾取后累计经验自动升级（`PlayerProgression.add_exp`），公式 `floor(base_exp * n^exp_exponent)` 控制升级曲线，等级/人口无上限。经验配置见 `ExpConfig`（`resources/exp_config.tres`）。

### 代码组织

- `scripts/core/` — 核心系统 (GameConfig, PlayerState, PlayerProgression, InventoryManager, StatsTracker, SceneFactory, EventBus, SpriteLoader)
- `scripts/components/` — 可复用组件：通用(HealthComponent, SpriteAnimator, Hitbox, Hurtbox, KnockbackHandler, SlowHandler)、索敌(TargetFinderComponent)、攻击(RangedAttackComponent, MeleeAttackComponent, GeneratorComponent)、投射物飞行(LinearMovementComponent, TrailComponent, RotationComponent)、投射物命中效果(SlowOnHitComponent, KnockbackOnHitComponent, PierceComponent, BounceOnHitComponent)
- `scripts/resources/` — 自定义 Resource 类定义 (WeaponData, EnemyData, TowerData, WaveData, SpawnPhaseData, CharacterData, ExpConfig, ShopConfig, AttackConfigData, GeneratorConfigData, ProjectileData, MeleeConfig 等)
- `scripts/entities/` — 游戏实体 (player, enemy, boss_base, boss_brute, coin, exp_orb, towers/, weapons/, projectiles/)
- `scripts/systems/` — 游戏系统 (wave_manager, enemy_spawner, shop_manager, effects_manager, audio_manager, drag_manager)
- `scripts/ui/` — UI 脚本 (hud, start_menu, result, 各选择界面, main 场景控制, shop_overlay 底部商店面板)
- `resources/` — `.tres` 配置数据文件 (weapons/, enemies/, towers/, waves/<map_id>/, characters/, maps/, shop/, effects/, spawn/)
- `assets/characters/<name>/` — 角色素材 (portrait.png, sprite.png, sprite.res)
- `assets/enemies/<name>/` — 敌人精灵 (sprite.png)
- `assets/towers/` — 塔素材 (各塔子目录)
- `assets/weapons/<name>/` — 武器素材
- `assets/projectiles/` — 弹道精灵
- `assets/items/` — 物品精灵 (gold_coin.png)
- `assets/effects/` — 特效动画 (explosions/, hit_sparks/, skill_effects/)
- `assets/ui/` — UI 素材 (icons/, panels/, buttons/, fonts/)
- `assets/themes/` — UI 主题 (default_theme.tres 默认主题, theme_1/ 木质像素风主题)
- `assets/maps/` — 地图背景
- `assets/tilesets/` — Tileset 图片
- `assets/sfx/` — 音效
- `assets/bgm/` — 背景音乐
- `assets_source/` — Aseprite 等源文件（镜像 assets/ 的实体目录结构）
- `scenes/entities/` — 实体场景 (player, coin, exp_orb, enemies/, towers/, projectiles/)
- `scenes/levels/` — 关卡场景 (main)
- `scenes/ui/` — UI 场景 (start_menu, hud, result, character_selection, map_select, shop_overlay)
- `scenes/shared/` — 共用场景 (map_boundary)

### 关键模式

- **配置驱动**: 游戏数值通过 Resource 类定义 (`scripts/resources/`)，以 `.tres` 文件存储 (`resources/`)，由 `GameConfig` 在运行时加载。修改数值编辑对应 `.tres` 文件即可。
- **工厂 + Resource 注入**: `SceneFactory` 创建实体时注入对应的 Resource 数据（`EnemyData`、`TowerData`），实体不再直接依赖 `GameConfig` 字典
- **组件化实体**: 行为通过子节点组件组合，不通过类继承。伤害通过 `Hitbox`/`Hurtbox` Area2D 体系处理（所有伤害流统一走此管线，包括塔受伤）。`HealthComponent` 支持 `damage_reduction` 和带 `attacker` 参数的 `damaged` 信号。`SlowHandler` 为效果字典模式，支持多源减速叠加（取最大值）。塔支持 `apply_buff/remove_buff` 增益系统。敌人支持 `apply_root/remove_root` 定身系统
- **武器 Pivot+Offset 架构**: WeaponManager 为每把武器创建 `WeaponPivot → WeaponOffset` 子树。Pivot 用 position 在轨道圆上移动（不旋转），承载索敌(TargetFinderComponent)和攻击组件(RangedAttackComponent/MeleeAttackComponent)。Offset position=(0,0) 承载视觉（WeaponSprite/FirePoint），近战突刺时 Tween 推 Offset 并携带 Hitbox 扫过路径命中敌人。无武器子类，差异通过组件组合和 WeaponData 配置实现
- **塔组件化**: 统一 `tower.gd` 基座，通过 `_ready()` 中 `get_node_or_null()` 自动检测挂载的组件（RangedAttackComponent/GeneratorComponent/Hurtbox）并初始化。Hurtbox 通过 `_on_hurtbox_hit_taken()` 包装方法连接到 HealthComponent。无 TowerShooter/TowerGenerator 子类
- **投射物组件化**: 统一 `Projectile` 基座，飞行行为（LinearMovementComponent）、视觉效果（TrailComponent、RotationComponent）和命中效果（SlowOnHitComponent、KnockbackOnHitComponent、PierceComponent、BounceOnHitComponent）均为场景子节点组件。每种投射物一个 .tscn 场景（arrow/shuriken/pea_bullet/ice_bullet），预配好所需组件。命中时基座遍历子节点调用 `on_hit(target, projectile)`
- **索敌组件**: `TargetFinderComponent` 使用 Area2D 物理检测，支持可插拔策略（NEAREST/LOWEST_HP/HIGHEST_HP/RANDOM）。武器和塔共用此组件
- **角色被动**: 角色通过 `CharacterData.passive_id` 字段引用被动 ID（如 `kaze_swift`、`nemo_guardian`），PlayerState 在 `init_character()` 时解析并存入 `player_stats`，不再使用枚举类型的 `PassiveType`
- **事件总线**: 跨系统通信通过 `EventBus` 全局事件总线，避免系统间直接耦合
- **信号通信**: 组件通过信号与宿主通信（如 `HealthComponent.died`）；跨系统事件通过 `EventBus`
- **分组管理**: 实体通过 Godot 分组 (`towers`, `enemies`, `coins`, `exp_orbs`) 进行批量操作
- **对象池**: 高频实体（投射物、普通敌人、金币、经验球）通过 SceneFactory 内部对象池复用。可池化实体实现 `var _is_pooled: bool` 和 `reset_for_pool()` 方法。销毁时调用 `SceneFactory.release_*()` 而非 `queue_free()`。投射物和敌人的 release 使用 `call_deferred` 避免物理回调冲突。组件提供 `HealthComponent.reset()`、`SlowHandler.clear_all()`、`Hurtbox.reset_for_pool()` 支持池化重置

### 碰撞系统

**碰撞层定义**（project.godot 中命名，共 8 层）：

| 层 | 名称 | bitmask | 用途 |
|---|---|---|---|
| 1 | Player | 1 | 玩家 CharacterBody2D |
| 2 | Enemy | 2 | 敌人 CharacterBody2D |
| 3 | Solid | 4 | 塔/障碍物 StaticBody2D |
| 4 | Pickup | 8 | Coin/ExpOrb (Area2D) |
| 5 | PlayerAttack | 16 | 玩家侧攻击 Hitbox（投射物 + 近战） |
| 6 | EnemyAttack | 32 | 敌人侧攻击 Hitbox（接触伤害） |
| 7 | DefenderHurt | 64 | 被敌人攻击的目标 Hurtbox（玩家 + 塔） |
| 8 | EnemyHurt | 128 | 被玩家攻击的目标 Hurtbox（敌人） |

**碰撞矩阵**：
- PlayerAttack(5) → EnemyHurt(8)：玩家攻击命中敌人
- EnemyAttack(6) → DefenderHurt(7)：敌人接触伤害玩家和塔
- Pickup(4) → Player(1)：拾取检测
- Enemy(2) / Player(1) → Solid(3)：被塔/障碍物阻挡

**碰撞形状规范**：
- 移动实体（Player/Enemy）：CircleShape2D（Player r=14, Enemy r=14, Boss r=22）
- 静态实体（Tower/障碍物）：RectangleShape2D 32×32
- Hitbox/Hurtbox 尺寸：玩家 Hurtbox 小于精灵（r=8），敌人 Hurtbox 大于精灵（r=15），投射物 Hitbox 略大（r=6~8）

**Hurtbox repeat_damage 模式**：`@export var repeat_damage: bool`，启用后对每个重叠的 Hitbox 独立计时（Dictionary `_hitbox_timers`），每 `repeat_interval` 秒重复触发 `hit_taken`。玩家和塔的 Hurtbox 启用此模式（敌人接触持续伤害），敌人 Hurtbox 不启用（投射物命中即消失）。

### 渲染深度分层

分层容器（PickupLayer/EntityLayer/ProjectileLayer）位于**地图场景内部**，main.gd 加载地图后动态获取引用。Player 也在运行时实例化并添加到地图的 EntityLayer。这样地图的 TileMap 物件层（Objects）可以和实体在同一个 y_sort 父节点下自然排序。

```
地图场景结构：
├── Background (Sprite2D, z=-1)
├── Ground (TileMapLayer, z=-1)
├── Decoration (TileMapLayer)
├── PickupLayer (Node2D, z=0)          — Coin、ExpOrb
├── EntityLayer (Node2D, z=1, y_sort)  — Player、Enemy、Tower
│   └── Objects (TileMapLayer, y_sort) — 碰撞+遮挡物件（树、石头等）
├── ProjectileLayer (Node2D, z=2)      — 投射物
├── MapBoundary (instance)
z_index  3+: 特效（伤害数字、击中火花等，由 EffectConfigData 配置）
```

- 实体通过 `y_sort_origin` 属性设置排序基准点到脚底（Player/Enemy/Tower=16, Boss=24）
- Objects TileMapLayer 的 tile 通过 TileSet 配置 y_sort_origin 和碰撞，与实体自然 y-sort
- 投射物不参与 Y-Sort（固定在实体上方）
- SceneFactory 管理容器引用，各系统通过 `SceneFactory.get_*_layer()` 获取正确容器
- 新增地图必须包含 `PickupLayer`、`EntityLayer`、`ProjectileLayer` 三个约定命名的子节点

## 开发流程

完整规范见 `docs/design/dev-workflow.md`。以下是 Claude Code 必须遵循的要点：

### Git 工作流

- 分支：`main`（稳定）→ `develop`（开发）→ `feature/<名称>` / `fix/<名称>`
- 提交格式：`<type>: <中文描述>`，type = feat/fix/refactor/test/docs/chore
- feature/fix 合并到 develop 前用 Claude Code review

### 代码风格

- 命名：类 `PascalCase`，函数/变量 `snake_case`，常量 `UPPER_SNAKE_CASE`，信号 `snake_case` 过去式，私有 `_` 前缀
- 文件：脚本 `snake_case.gd`，场景 `snake_case.tscn`
- 脚本内顺序：信号 → 常量 → @export → @onready → 变量 → 生命周期 → 公共方法 → 私有方法
- 中文注释，英文标识符
- 函数参数和返回值使用类型标注

### 架构规范

- **禁止硬编码数值** — 所有游戏数值通过 `.tres` 资源文件定义，由 `GameConfig` 加载
- **禁止直接实例化场景** — 通过 `SceneFactory` 创建实体
- **禁止系统间直接调用** — 跨系统通信通过 `EventBus` 事件总线，不直接引用其他系统
- **实体不直接读 GameConfig** — 实体通过 SceneFactory 注入的 Resource 数据初始化，不直接依赖 GameConfig 字典
- 新增实体流程：Resource 类定义 (`scripts/resources/`) → `.tres` 数据文件 (`resources/`) → GameConfig 注册加载 → 脚本 → 场景（挂载组件子节点） → SceneFactory 注册（注入 Resource） → 测试
- 新增组件流程：`scripts/components/` 中创建组件脚本 → 在 `.tscn` 场景中添加为子节点 → 实体 `_ready()` 中通过 `@onready` 引用并初始化

### 测试规范

- 核心模块必须有单元测试，新功能/bugfix 必须附带测试
- 文件：`test_<模块>.gd`，方法：`test_<行为描述>()`，继承 `GutTest`
- Bug 修复先写失败测试再修复（TDD）
- **headless 测试注意**: 新增带 `class_name` 的脚本后，若无法打开 Godot 编辑器自动刷新，需手动在 `.godot/global_script_class_cache.cfg` 中补充对应条目，否则 headless 测试无法识别该类名

## MCP 插件

项目集成了 `gdai-mcp-plugin-godot` 插件，可通过 MCP 工具直接操控 Godot 编辑器（创建场景、添加节点、运行项目等）。

## 语言

项目使用中文注释和 UI 文本，代码标识符使用英文。
