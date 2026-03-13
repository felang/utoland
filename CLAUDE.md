# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

utoland 是一个基于 **Godot 4.6** 的 2D 塔防 + 射击混合类游戏。玩家选择角色，在波次战斗中击杀敌人获取金币。拾取金币同步获得经验值（1 金币 = 1 XP），升级后在波次结束时进入 N 轮 3 选 1 升级弹窗（武器+塔混合池，N = 本波升级次数），之后进入纯布置阶段放置已拥有的塔。武器和塔均有 1-5 级等级系统。

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
- **GameData** (`scripts/core/game_data.gd`) — 运行时游戏状态，存储当前角色属性、金币、波次、owned_weapons/owned_towers（{id: level} 字典）、经验值/等级（current_level/current_xp/pending_upgrades）。`reset()` 从 CharacterData 初始化默认武器/塔并重置等级。`upgrade_weapon()`/`upgrade_tower()` 管理等级升级。`add_xp()` 累积经验值并触发升级。跨场景传递数据。
- **SceneFactory** (`scripts/core/scene_factory.gd`) — 集中管理场景实例化，提供 `create_tower()`, `create_enemy()`, `create_bullet()`, `create_coin()` 等工厂方法。创建实体必须通过此工厂。
- **EffectsManager** (`scripts/systems/effects_manager.gd`) — 特效管理：伤害数字、击中火花、死亡爆炸、闪白等视觉效果。
- **AudioManager** (`scripts/systems/audio_manager.gd`) — 音效管理：AudioStreamPlayer 池化播放，通过 `play(sound_id)` 统一触发。音效文件放 `assets/sfx/`。
- **EventBus** (`scripts/core/event_bus.gd`) — 全局事件总线，用于跨系统解耦通信（波次事件、等级事件 player_leveled_up/xp_changed 等）。
- **SceneManager** (`scripts/core/scene_manager.gd`) — 集中管理场景切换，提供 `go_to(scene_name)` 方法。所有场景路径在此统一维护，禁止直接调用 `get_tree().change_scene_to_file()`。

### 游戏流程 (场景切换)

```
start_menu → character_selection → map_select → placement (纯塔布置)
    ↓ (开始战斗)
  main (战斗，拾取金币获取XP) → 波次结束 → upgrade_popup (N轮3选1武器+塔混合升级弹窗)
    ↓ (选择后)
  placement (纯塔布置) → main (下一波战斗)
    ↓ (全部波次完成或玩家死亡)
  result (结算)
```

> **波次结束流程**: 战斗中拾取金币同步获取 XP，可能升多级。波次结束后，若 pending_upgrades > 0 则弹出升级弹窗（N 轮 3 选 1，武器+塔混合池，由 UpgradeGenerator 生成），否则直接进布置。
> **布置阶段**: 左侧 120px 侧栏（已拥有塔列表），右侧地图网格。纯塔布置，无商店。塔在波间全回满 HP。

### 代码组织

- `scripts/core/` — 核心系统 (GameConfig, GameData, SceneFactory, EventBus, SpriteLoader)
- `scripts/components/` — 可复用组件 (HealthComponent, SpriteAnimator, Hitbox, Hurtbox, KnockbackHandler, SlowHandler)
- `scripts/resources/` — 自定义 Resource 类定义 (WeaponData, EnemyData, TowerData, WaveData, CharacterData 等)
- `scripts/entities/` — 游戏实体 (player, enemy, boss_base, boss_brute, coin, towers/, weapons/, projectiles/)
- `scripts/systems/` — 游戏系统 (wave_manager, enemy_spawner, upgrade_generator, effects_manager, audio_manager)
- `scripts/ui/` — UI 脚本 (hud, start_menu, result, 各选择界面, main 场景控制, placement 布置场景控制, placement_panel 塔布置侧栏, upgrade_popup 升级弹窗)
- `resources/` — `.tres` 配置数据文件 (weapons/, enemies/, towers/, waves/<map_id>/, characters/, maps/, shop/, effects/, spawn/)
- `scenes/entities/` — 实体场景 (player, coin, enemies/, towers/, projectiles/)
- `scenes/levels/` — 关卡场景 (main, placement)
- `scenes/ui/` — UI 场景 (start_menu, hud, result, character_selection, map_select)
- `scenes/shared/` — 共用场景 (map_boundary)

### 关键模式

- **配置驱动**: 游戏数值通过 Resource 类定义 (`scripts/resources/`)，以 `.tres` 文件存储 (`resources/`)，由 `GameConfig` 在运行时加载。修改数值编辑对应 `.tres` 文件即可。
- **工厂 + Resource 注入**: `SceneFactory` 创建实体时注入对应的 Resource 数据（`EnemyData`、`TowerData`），实体不再直接依赖 `GameConfig` 字典
- **组件化实体**: 共享行为提取为可复用组件（`HealthComponent`、`SpriteAnimator`），专用行为提取为独立组件（`WeaponManager`、`KnockbackHandler`、`SlowHandler`），伤害通过 `Hitbox`/`Hurtbox` Area2D 体系处理，通过场景树子节点挂载
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
