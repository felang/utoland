# 开发流程与代码规范设计文档

> 本文档定义 utoland 项目的开发流程和代码规范，供团队成员和 Claude Code 共同遵循。

## 1. Git 工作流

### 分支策略（Git Flow 精简版）

- `main` — 稳定版本，只接受从 develop 合并或 hotfix
- `develop` — 日常开发主分支，feature 分支从这里分出、合并回这里
- `feature/<名称>` — 新功能分支，如 `feature/new-enemy-type`
- `fix/<名称>` — bugfix 分支，如 `fix/tower-placement-crash`
- `hotfix/<名称>` — 紧急修复，从 main 分出，修复后合并回 main 和 develop

### 提交规范（Conventional Commits + 中文描述）

```
<type>: <中文描述>

[可选正文]

Co-Authored-By: ...
```

type 取值：
- `feat` — 新功能
- `fix` — 修复 bug
- `refactor` — 重构（不改变功能）
- `test` — 测试相关
- `docs` — 文档
- `chore` — 构建/配置/工具

### Review 流程

- feature/fix 分支合并到 develop 前，使用 Claude Code review
- develop 合并到 main 前，团队成员至少一人确认

## 2. GDScript 代码风格

### 命名规范

- 类名：`PascalCase` — `Tower`, `WaveManager`
- 函数/变量：`snake_case` — `create_tower()`, `current_hp`
- 常量：`UPPER_SNAKE_CASE` — `WEAPONS`, `DEBUG_MODE`
- 信号：`snake_case` 过去式 — `wave_started`, `game_won`
- 私有变量/函数：`_` 前缀 — `_tower_scenes`, `_setup_wave_manager()`
- 节点引用：`snake_case` — `@onready var hp_label = $HPLabel`

### 文件命名

- 脚本：`snake_case.gd` — `wave_manager.gd`, `tower_slow.gd`
- 场景：`snake_case.tscn` — `enemy_normal.tscn`, `start_menu.tscn`
- 脚本和场景一一对应时，保持同名

### 代码组织（单个脚本内的顺序）

```gdscript
extends BaseClass

# 1. 信号声明
signal wave_started(wave_number: int)

# 2. 常量
const MAX_SPEED = 300.0

# 3. 导出变量
@export var speed: float = 100.0

# 4. @onready 节点引用
@onready var hp_label = $HPLabel

# 5. 普通变量
var current_hp: float = 0.0

# 6. 生命周期函数 (_ready, _process, _physics_process)
func _ready():
    pass

# 7. 公共方法
func take_damage(amount: float):
    pass

# 8. 私有方法
func _update_ui():
    pass
```

### 注释与类型

- 注释语言：中文注释，英文标识符
- 类型标注：鼓励在函数参数和返回值上使用类型标注，变量可选

## 3. 架构规范

### 尺寸标准（全局统一）

- 基准分辨率：640 x 360
- 显示放大：3x 对应 1080p
- PPU：30
- 网格单元：30 x 30 像素
- 地图尺寸：40 列 x 30 行（1200 x 900 像素）
- 地图中心：世界坐标原点 (0, 0)
- 所有尺寸常量定义在 `GameConfig` 中，禁止在其他脚本中硬编码

### 核心原则

1. **配置驱动** — 所有游戏数值在 `GameConfig` 中定义，禁止在实体脚本中硬编码数值
2. **工厂模式** — 通过 `SceneFactory` 创建所有实体，禁止在业务代码中直接 `preload/load/instantiate`
3. **信号通信** — 系统之间通过信号解耦，禁止系统之间直接调用方法
4. **分组管理** — 实体通过 Godot 分组进行批量操作，组名统一小写：`towers`, `enemies`, `coins`, `player`, `wave_manager`

### 目录结构

```
scripts/
  core/        — 核心单例 (GameData, SceneFactory)
  entities/    — 游戏实体 (player, enemy, bullet, coin)
    towers/    — 塔类实体
  systems/     — 游戏系统 (wave_manager, enemy_spawner, shop_manager)
  ui/          — UI 控制脚本 (hud, menus, main)
scenes/
  enemies/     — 敌人场景
  towers/      — 塔场景
  ui/          — UI 场景
  backup/      — 备份场景（不参与构建）
tests/
  unit/        — 单元测试
  integration/ — 集成测试
docs/
  plans/       — 设计文档和实现计划
```

### 新增实体的标准流程

1. 在 `GameConfig` 中添加配置
2. 在 `scripts/entities/` 中创建脚本
3. 在 `scenes/` 对应目录创建场景
4. 在 `SceneFactory` 中注册 preload 和工厂方法
5. 编写单元测试

## 4. 测试规范

### 必测范围

- 核心模块：`GameConfig`、`GameData`、`SceneFactory` 必须有单元测试
- 新功能：每个新功能必须附带测试
- Bug 修复：每个 bugfix 先写失败测试，再修复（TDD）

### 存量代码补充优先级

1. 核心系统（已有部分测试）
2. 实体逻辑（player、enemy 的 take_damage、die 等）
3. 系统逻辑（wave_manager、shop_manager）
4. UI 逻辑（优先级最低，可选）

### 测试文件组织

```
tests/
  unit/
    test_game_config.gd      — 对应 game_config.gd
    test_scene_factory.gd    — 对应 scene_factory.gd
    test_enemy.gd            — 对应 entities/enemy.gd
  integration/
    test_combat_flow.gd      — 跨系统集成测试
    test_tower_placement.gd
```

### 测试命名

- 文件：`test_<被测模块>.gd`
- 方法：`test_<行为描述>()`，如 `test_take_damage_reduces_hp()`、`test_die_when_hp_zero()`
- 继承 `GutTest`

### 运行测试

- 通过 Godot 编辑器的 GUT 面板运行
- CI 中通过 `godot --headless -s addons/gut/gut_cmdln.gd` 运行
