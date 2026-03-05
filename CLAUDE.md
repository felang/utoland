# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

utoland 是一个基于 **Godot 4.6** 的 2D 塔防 + 射击混合类游戏。玩家选择角色和武器，在波次战斗中击杀敌人获取金币，通过商店购买塔和属性升级来生存。

## 运行与测试

- **运行项目**: 通过 Godot 编辑器运行，或使用 gdai-mcp 插件的 `run_project` 工具
- **测试框架**: GUT (Godot Unit Test)，配置见 `.gutconfig.json`
- **测试目录**: `tests/unit/` (单元测试), `tests/integration/` (集成测试)
- **测试命名**: 文件前缀 `test_`，测试方法前缀 `test_`，继承 `GutTest`
- **渲染器**: GL Compatibility (兼容模式)
- **物理引擎**: Jolt Physics

## 架构

### Autoload 单例 (全局可用)

- **GameConfig** (`game_config.gd`) — 所有游戏数值的配置中心，包含武器、敌人、塔、波次、玩家、角色、商店、地图的常量配置。修改数值只需改这里。
- **GameData** (`scripts/core/game_data.gd`) — 运行时游戏状态，存储当前角色属性、金币、波次、已购买的塔等。跨场景传递数据。
- **SceneFactory** (`scripts/core/scene_factory.gd`) — 集中管理场景实例化，提供 `create_tower()`, `create_enemy()`, `create_bullet()`, `create_coin()` 等静态工厂方法。创建实体必须通过此工厂。

### 游戏流程 (场景切换)

```
start_menu → character_selection → weapon_select → map_select → main (战斗)
    ↓ (波次结束)
  shop (商店) → placement (布置塔) → main (下一波战斗)
    ↓ (全部波次完成或玩家死亡)
  result (结算)
```

### 代码组织

- `scripts/core/` — 核心系统 (GameData, SceneFactory)
- `scripts/entities/` — 游戏实体 (player, enemy, bullet, coin, towers/)
- `scripts/systems/` — 游戏系统 (wave_manager, enemy_spawner, shop_manager)
- `scripts/ui/` — UI 脚本 (hud, start_menu, result, 各选择界面, main 场景控制)
- `scenes/` — 对应的 .tscn 场景文件

### 关键模式

- **配置驱动**: 所有数值在 `GameConfig` 中定义，实体在 `_ready()` 中从 GameConfig 读取配置
- **工厂模式**: 通过 `SceneFactory` 创建所有实体，不直接 preload/instantiate 场景
- **信号通信**: `WaveManager` 通过信号 (`wave_started`, `wave_completed`, `game_won`, `game_lost`) 驱动游戏流程
- **分组管理**: 实体通过 Godot 分组 (`towers`, `enemies`, `coins`) 进行批量操作

## MCP 插件

项目集成了 `gdai-mcp-plugin-godot` 插件，可通过 MCP 工具直接操控 Godot 编辑器（创建场景、添加节点、运行项目等）。

## 语言

项目使用中文注释和 UI 文本，代码标识符使用英文。
