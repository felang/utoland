# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

utoland 是一个基于 **Godot 4.6** 的 2D 塔防 + 射击混合类游戏（自走棋经济模式）。玩家选择角色，在波次战斗中击杀敌人获取金币。波次结束后进入商店，花金币购买武器/塔（进入背包），购买经验升本提高人口上限，从背包装备武器到角色或布置塔到地图。3 个同类同级物品自动合成升级（最高 3 级）。武器和塔共用人口上限（2-8）。每个武器/塔/角色带有标签，同标签数量达到阈值可激活羁绊效果（2/3/5 档）。特定单位对组合可触发配对协同（双人羁绊）。

**武器（10 种）**: 步枪(rifle)、回旋镖(boomerang)、激光(laser)、霰弹枪(shotgun)、加特林(minigun)、冰冻枪(ice_gun)、火箭炮(rocket)、闪电(lightning)、刀刃(blade)、喷火器(flamethrower)

**植物塔（15 种）**: 射手塔(pea_shooter)、树桩(stump)、冰花(ice_flower)、仙人掌(cactus)、玫瑰(rose)、毒蘑菇(mushroom)、藤蔓(vine)、蒲公英(dandelion)、猪笼草(pitcher)、荆棘(thorn)、橡树(oak)、向日葵(sunflower)、薄荷(mint)、治愈花(heal_flower)、爆竹竹(bamboo)

## 运行与测试

- **运行项目**: 通过 Godot 编辑器运行，或使用 gdai-mcp 插件的 `run_project` 工具
- **测试框架**: GUT (Godot Unit Test)，配置见 `.gutconfig.json`
- **测试目录**: `tests/unit/` (单元测试), `tests/integration/` (集成测试)
- **测试命名**: 文件前缀 `test_`，测试方法前缀 `test_`，继承 `GutTest`
- **渲染器**: GL Compatibility (兼容模式)
- **物理引擎**: Jolt Physics

## 架构

### Autoload 单例 (全局可用，加载顺序有依赖)

- **GameConfig** (`scripts/core/game_config.gd`) — 资源注册表，运行时从 `resources/` 目录加载 `.tres` 配置文件（武器、敌人、塔、波次、角色、地图、特效、精灵等）。必须最先加载（GameData 依赖它）。
- **GameData** (`scripts/core/game_data.gd`) — 运行时游戏状态，存储角色属性、金币、波次、背包（`bag: Array[Dictionary]`）、已装备武器（`deployed_weapons`）、已布置塔（`deployed_towers`）、商店栏位（`shop_slots`）、人口等级（`player_level` 1-7）、羁绊标签数（`synergy_tag_counts`）、激活档位（`synergy_active_tiers`）。`reset()` 初始化新游戏状态。提供 `deploy/undeploy_weapon/tower()`、`sell_from_bag/deployed_weapon/deployed_tower()`、`buy_level_up()`、`_check_merge()` 等方法。持有 `_synergy_manager`（SynergyManager）和 `_pair_synergy_manager`（PairSynergyManager）内部实例，deploy/undeploy 后自动触发羁绊重算。跨场景传递数据。
- **SceneFactory** (`scripts/core/scene_factory.gd`) — 集中管理场景实例化，提供 `create_tower()`, `create_enemy()`, `create_bullet()`, `create_coin()` 等工厂方法。创建实体必须通过此工厂。
- **EffectsManager** (`scripts/systems/effects_manager.gd`) — 特效管理：伤害数字、击中火花、死亡爆炸、红闪（flash_hit）、击中抖动（sprite_shake）、增强死亡特效（spawn_enhanced_death）、Boss 击杀慢动作（hitstop）等视觉效果。
- **AudioManager** (`scripts/systems/audio_manager.gd`) — 音效管理：SFX 通过 AudioStreamPlayer 池化播放 `play(sound_id)`，BGM 通过独立 AudioStreamPlayer 播放 `play_bgm(track_id)` / `stop_bgm()` / `fade_bgm(duration)`。SFX 放 `assets/sfx/`，BGM 放 `assets/bgm/`。
- **EventBus** (`scripts/core/event_bus.gd`) — 全局事件总线，用于跨系统解耦通信。商店信号：`item_purchased/item_sold/item_merged/item_deployed/item_undeployed/player_level_changed`。战斗信号：`wave_started/wave_completed/wave_transition_ready/enemy_killed/boss_killed/coins_changed/coins_generated`。羁绊信号：`synergy_changed(tag, old_tier, new_tier)`、`pair_synergy_activated/deactivated(pair_id)`。
- **SceneManager** (`scripts/core/scene_manager.gd`) — 集中管理场景切换，提供 `go_to(scene_name)` 方法（带淡入淡出过渡动画，async）。自动根据 SCENE_BGM 映射切换 BGM。所有场景路径在此统一维护，禁止直接调用 `get_tree().change_scene_to_file()`。

### 游戏流程 (场景切换)

```
start_menu → character_selection → map_select → shop（首次，用初始金币购买）
    ↓ (点击"开始战斗")
  main (战斗，拾取金币积累) → 波次结束 → shop（自动刷新商店）
    ↓ (点击"开始战斗")
  main (下一波战斗) → ... → result (结算)
```

> **商店阶段**: 统一界面包含商店栏（4 个物品 + 刷新）、背包（10 格）、角色装备栏、地图布置区。购买物品进背包，从背包装备武器或布置塔到地图。花金币升本提高人口上限和解锁高稀有度物品。3 个同类同级自动合成。

### 代码组织

- `scripts/core/` — 核心系统 (GameConfig, GameData, SceneFactory, EventBus, SpriteLoader)
- `scripts/components/` — 可复用组件 (HealthComponent, SpriteAnimator, Hitbox, Hurtbox, KnockbackHandler, SlowHandler)
- `scripts/resources/` — 自定义 Resource 类定义 (WeaponData, EnemyData, TowerData, WaveData, CharacterData, SynergyData 等)
- `scripts/entities/` — 游戏实体 (player, enemy, boss_base, boss_brute, coin, towers/, weapons/, projectiles/)
- `scripts/systems/` — 游戏系统 (wave_manager, enemy_spawner, shop_manager, effects_manager, audio_manager, synergy_manager, pair_synergy_manager, synergy_effect_processor)
- `scripts/ui/` — UI 脚本 (hud, start_menu, result, 各选择界面, main 场景控制, shop 商店场景控制)
- `resources/` — `.tres` 配置数据文件 (weapons/, enemies/, towers/, waves/<map_id>/, characters/, maps/, shop/, effects/, spawn/)
- `scenes/entities/` — 实体场景 (player, coin, enemies/, towers/, projectiles/)
- `scenes/levels/` — 关卡场景 (main)
- `scenes/ui/` — UI 场景 (start_menu, hud, result, character_selection, map_select, shop)
- `scenes/shared/` — 共用场景 (map_boundary)

### 关键模式

- **配置驱动**: 游戏数值通过 Resource 类定义 (`scripts/resources/`)，以 `.tres` 文件存储 (`resources/`)，由 `GameConfig` 在运行时加载。修改数值编辑对应 `.tres` 文件即可。
- **工厂 + Resource 注入**: `SceneFactory` 创建实体时注入对应的 Resource 数据（`EnemyData`、`TowerData`），实体不再直接依赖 `GameConfig` 字典
- **组件化实体**: 共享行为提取为可复用组件（`HealthComponent`、`SpriteAnimator`），专用行为提取为独立组件（`WeaponManager`、`KnockbackHandler`、`SlowHandler`），伤害通过 `Hitbox`/`Hurtbox` Area2D 体系处理，通过场景树子节点挂载。`HealthComponent` 支持 `damage_reduction` 和带 `attacker` 参数的 `damaged` 信号。`SlowHandler` 为效果字典模式，支持多源减速叠加（取最大值）。塔支持 `apply_buff/remove_buff` 增益系统。敌人支持 `apply_root/remove_root` 定身系统
- **标签/羁绊系统**: 每个武器、塔、角色在其 Resource 中携带 `tag` 字段（assault/control/blast/fortify/boost 五种）。`SynergyManager`（RefCounted，由 GameData 持有）统计已上阵单位的标签数量并计算激活档位（2/3/5 档）。每档触发对应的数值加成或机制效果（由 `SynergyEffectProcessor` Node 在战斗场景中处理 3/5 档机制型效果）。`PairSynergyManager`（RefCounted，由 GameData 持有）管理特定单位对的双人协同效果（共 8 组）。羁绊数据通过 `SynergyData` Resource 配置，存于 `resources/synergies/`
- **角色被动**: 角色通过 `CharacterData.passive_id` 字段引用被动 ID（如 `kaze_swift`、`nemo_guardian`），GameData 在 `init_character()` 时解析并存入 `player_stats`，不再使用枚举类型的 `PassiveType`
- **事件总线**: 跨系统通信通过 `EventBus` 全局事件总线，避免系统间直接耦合
- **信号通信**: 组件通过信号与宿主通信（如 `HealthComponent.died`）；跨系统事件通过 `EventBus`
- **分组管理**: 实体通过 Godot 分组 (`towers`, `enemies`, `coins`) 进行批量操作

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
