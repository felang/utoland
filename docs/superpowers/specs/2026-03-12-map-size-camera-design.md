# 地图尺寸与摄像机设计

## 目标

实现 Brotato 风格的竞技场体验：地图略大于一屏（约 1.3 倍可见区域），视野开阔，摄像机轻微跟随玩家，所有参数配置化便于调试。

## 当前状态

- 视口：640x360，stretch mode = canvas_items
- 地图：1200x900 固定像素
- 摄像机：zoom=0.75（可见区域约 853x480），硬编码在 camera_shake.gd
- 地图边界：map_boundary.tscn 碰撞墙位置硬编码
- Debug 快捷键：F1~F4，Touch Bar Mac 不友好

## 设计

### 1. 摄像机参数配置化

新建 Resource 类 `CameraConfigData`（或扩展 `EffectConfigData`），包含：

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| zoom | float | 0.55 | 摄像机缩放，调试范围 0.4~0.8 |
| smoothing_speed | float | 8.0 | 平滑跟随速度 |
| look_ahead_distance | float | 40.0 | 前瞻偏移像素 |
| look_ahead_smoothing | float | 3.0 | 前瞻平滑系数 |
| dead_zone_width | float | 0.1 | 死区宽度比例（0~1） |
| dead_zone_height | float | 0.1 | 死区高度比例 |

`camera_shake.gd` 在 `_ready()` 时从配置读取，不再硬编码。

### 2. 地图尺寸动态计算

地图尺寸由 zoom 和比例系数动态计算，不再写死像素值：

- `map_size_ratio`：地图与可见区域的比例，默认 1.3，配置化
- 计算公式：
  - `MAP_PIXEL_WIDTH = viewport_w / zoom * map_size_ratio`
  - `MAP_PIXEL_HEIGHT = viewport_h / zoom * map_size_ratio`
- `GameConfig` 中 `MAP_PIXEL_WIDTH/HEIGHT` 改为计算属性
- 以 zoom=0.55、ratio=1.3 为例：约 1513x851

### 3. 边界与摄像机限制自动适配

- `map_boundary.tscn` 碰撞墙位置根据计算出的地图尺寸动态设置
- 摄像机 limit（上下左右）同步设为地图半宽/半高
- 调整 zoom 或 ratio 时，边界和限制全部自动跟随

### 4. 摄像机跟随行为

- 摄像机挂在 Player 节点上（保持不变）
- position smoothing 开启，速度从配置读取
- look-ahead：根据玩家移动方向偏移，看到前方更多内容
- dead zone：玩家在屏幕中心小范围移动时摄像机不跟随
- camera shake 逻辑保持不变，仅初始化参数来源改为配置

### 5. Debug 快捷键改造

Touch Bar Mac 不支持 F 键，改为 Ctrl 组合键：

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

- `scripts/systems/camera_shake.gd` — 读取配置，移除硬编码
- `scripts/core/game_config.gd` — MAP_PIXEL_WIDTH/HEIGHT 改为计算属性
- `scripts/resources/` — 新建或扩展 CameraConfigData Resource
- `resources/` — 新建摄像机配置 .tres 文件
- `scenes/shared/map_boundary.tscn` 或其脚本 — 动态设置碰撞墙位置
- `scripts/ui/debug_panel.gd` — 快捷键改为 Ctrl 组合键，新增 zoom 调整
