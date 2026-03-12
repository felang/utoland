# 地图尺寸与摄像机设计

## 目标

实现 Brotato 风格的竞技场体验：地图略大于一屏（约 1.3 倍可见区域），视野开阔，摄像机轻微跟随玩家，所有参数配置化便于调试。

## 当前状态

- 视口：640x360，stretch mode = canvas_items
- 地图：1280x960 固定像素（MAP_COLS=40, MAP_ROWS=30, GRID_SIZE=32）
- 摄像机：zoom=Vector2(0.75, 0.75)（可见区域约 853x480），硬编码在 camera_shake.gd
- 地图边界：map_boundary.tscn 碰撞墙位置硬编码
- Debug 快捷键：F1~F4，Touch Bar Mac 不友好

## 设计

### 1. 摄像机参数配置化

扩展现有 `EffectConfigData`，新增 `dead_zone_width`、`dead_zone_height` 字段，并将 `camera_zoom` 从 `Vector2` 改为 `float`（存储标量，使用时转换为 `Vector2(zoom, zoom)`）。同时新增 `map_size_ratio` 字段（全局，非 per-map）。

完整摄像机相关字段：

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| camera_zoom | float | 0.55 | 摄像机缩放标量，使用时转为 Vector2(v, v)，调试范围 0.4~0.8 |
| camera_smoothing_speed | float | 8.0 | 平滑跟随速度 |
| camera_look_ahead_distance | float | 40.0 | 前瞻偏移像素 |
| camera_look_ahead_smoothing | float | 3.0 | 前瞻平滑系数 |
| camera_dead_zone_width | float | 0.1 | 映射到 Camera2D drag_left_margin / drag_right_margin |
| camera_dead_zone_height | float | 0.1 | 映射到 Camera2D drag_top_margin / drag_bottom_margin |
| map_size_ratio | float | 1.3 | 地图与可见区域的比例 |

`camera_shake.gd` 在 `_ready()` 时读取配置：
- `zoom = Vector2(cfg.camera_zoom, cfg.camera_zoom)`
- 设置 `drag_horizontal_enabled = true`、`drag_vertical_enabled = true`
- 设置 `drag_left_margin = drag_right_margin = cfg.camera_dead_zone_width`
- 设置 `drag_top_margin = drag_bottom_margin = cfg.camera_dead_zone_height`

### 2. 地图尺寸动态计算

地图尺寸由 zoom 和比例系数动态计算，不再写死像素值：

- 计算公式：
  - `MAP_PIXEL_WIDTH = BASE_VIEWPORT_WIDTH / camera_zoom * map_size_ratio`
  - `MAP_PIXEL_HEIGHT = BASE_VIEWPORT_HEIGHT / camera_zoom * map_size_ratio`
- 以 zoom=0.55、ratio=1.3 为例：约 1513x851

**`GameConfig` 改造**：保留 `MAP_PIXEL_WIDTH/HEIGHT` 和 `MAP_HALF_WIDTH/HEIGHT` 作为 `var`（非 `const`），在 `_ready()` 中根据 `EffectConfigData` 计算赋值。移除 `MAP_COLS/MAP_ROWS` const（不再有意义，地图尺寸不再基于网格），保留 `GRID_SIZE` const（grid_overlay 仍需要）。

**消费者迁移**：所有在变量声明处直接引用 `GameConfig.MAP_HALF_WIDTH` 等的脚本需改为在 `_ready()` 中读取。在函数体/`_ready()` 中读取的引用无需改动（autoload `_ready()` 先于场景节点执行）。

需更新的声明处引用：
- `scripts/systems/enemy_spawner.gd` — `map_min_x/max_x/min_y/max_y` 改到 `_ready()` 赋值
- `scripts/ui/placement.gd` — 地图边界引用改到 `_ready()`
- `scripts/ui/grid_overlay.gd` — 地图尺寸引用改到 `_ready()`

测试文件更新（断言策略：验证公式正确性，即 `MAP_PIXEL_WIDTH == BASE_VIEWPORT_WIDTH / zoom * ratio`）：
- `tests/unit/test_game_config_dimensions.gd` — 断言改为验证动态计算公式
- `tests/unit/test_placement_grid_rules.gd` — 边界值更新
- `tests/unit/test_grid_overlay.gd` — 尺寸值更新
- `tests/unit/test_camera_shake.gd` — 摄像机限制值更新
- `tests/integration/test_enemy_spawning.gd` — 生成边界值更新

### 3. 边界与摄像机限制自动适配

为 `map_boundary.tscn` 附加脚本 `scripts/shared/map_boundary.gd`：
- `_ready()` 中读取 `GameConfig.MAP_HALF_WIDTH/HEIGHT`
- 动态设置四面碰撞墙的 position 和 collision shape size
- 不再依赖 .tscn 中硬编码的位置

摄像机 limit 由 `camera_shake.gd` 在 `_ready()` 中同步设为 `+/- MAP_HALF_WIDTH/HEIGHT`。

### 4. 摄像机跟随行为

- 摄像机挂在 Player 节点上（保持不变）
- position smoothing 开启，速度从配置读取
- look-ahead：根据玩家移动方向偏移，看到前方更多内容
- dead zone：使用 Godot Camera2D 内置 drag margin 机制实现
- camera shake 逻辑保持不变，仅初始化参数来源改为配置

### 5. Debug 快捷键改造

Touch Bar Mac 不支持 F 键，改为 Ctrl 组合键。需同步更新 `project.godot` input map 中的 action 映射。

| 功能 | 当前 | 新键 |
|------|------|------|
| 显隐面板 | F1 | Ctrl+D |
| 跳波 | F2 | Ctrl+1 |
| 加100金币 | F3 | Ctrl+2 |
| 无敌切换 | F4 | Ctrl+3 |
| Zoom 缩小 | 无 | Ctrl+4 |
| Zoom 放大 | 无 | Ctrl+5 |

Zoom 调整步长 0.05，调参时 debug 面板显示当前 zoom 值和可见区域尺寸。

## 不在本次范围内

- 敌人刷新方式（从边缘改为地图内刷新）— 后续单独处理
- 视口分辨率变更 — 如调试后精灵太小再考虑
- 动态缩放系统 — 过度设计，不做
- 精灵素材重绘 — 当前素材先保持

## 涉及文件

- `scripts/systems/camera_shake.gd` — 读取配置，移除硬编码，zoom float→Vector2 转换
- `scripts/core/game_config.gd` — MAP_PIXEL_WIDTH/HEIGHT 改为 var，_ready() 中计算
- `scripts/resources/effect_config_data.gd` — 扩展字段：camera_zoom 改 float，新增 dead_zone/map_size_ratio
- `resources/effects/default.tres` — 更新对应字段值
- `scripts/shared/map_boundary.gd` — 新建，动态设置碰撞墙位置
- `scenes/shared/map_boundary.tscn` — 附加 map_boundary.gd 脚本
- `scripts/ui/debug_panel.gd` — 快捷键改为 Ctrl 组合键，新增 zoom 调整
- `project.godot` — 更新 input map action 映射
- `scripts/systems/enemy_spawner.gd` — map 边界变量改到 _ready() 读取
- `scripts/ui/placement.gd` — 地图边界引用改到 _ready()
- `scripts/ui/grid_overlay.gd` — 地图尺寸引用改到 _ready()
- `tests/unit/test_game_config_dimensions.gd` — 断言改为验证动态公式
- `tests/unit/test_placement_grid_rules.gd` — 边界值更新
- `tests/unit/test_grid_overlay.gd` — 尺寸值更新
- `tests/unit/test_camera_shake.gd` — 摄像机限制值更新
- `tests/integration/test_enemy_spawning.gd` — 生成边界值更新
