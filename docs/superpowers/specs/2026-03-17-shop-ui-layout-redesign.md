# 商店阶段 UI 布局重设计

## 背景

当前商店面板在屏幕底部水平布局，遮挡地图下方区域，且相机仍跟随玩家无法看到全图。需要改为：商店阶段相机缩放至全图可见并紧贴右侧，左侧留出空间给纵向商店面板。

## 设计目标

1. 商店阶段相机平滑缩放至全图可见，地图紧贴右侧屏幕边缘
2. 商店面板改为左侧纵向布局，从左侧滑入滑出
3. 卡片改为横向小尺寸（图标+名称+价格水平排列）
4. 波次之间有平滑相机过渡动画

## 相机系统

### 参数计算

- 视口：640×360
- 地图：544×416 像素（中心在原点，范围 ±272×±208）
- 商店 zoom = 360/416 ≈ 0.865（地图高度适配视口高度）
- 相机可见世界宽度 = 640/0.865 ≈ 740
- 地图右边缘 X=272，相机中心 X = 272 - 740/2 = -98
- 商店阶段相机目标位置：(-98, 0)，zoom=0.865
- 左侧剩余空间 ≈ 169 屏幕像素（740-544=196 世界像素 × 0.865 ≈ 169）

### 相机控制方式

Camera2D 是 Player 的子节点，直接 tween `global_position` 会与 Player 父节点变换冲突。采用 tween Camera2D 的 `position`（局部坐标）方式：

- 目标局部 position = 目标世界位置 - Player.global_position
- 商店阶段禁用玩家输入（`set_input_enabled(false)`）+ 清零速度（`velocity = Vector2.ZERO`），确保玩家不移动

### 相机限制处理

Camera2D 的 `limit_left/right/top/bottom` 会约束可视区域。商店阶段相机位置 (-98, 0) 在 zoom=0.865 下左侧可视边缘超出 `limit_left=-272`，会被 Godot 钳制。解决方案：

- 进入商店阶段前：扩大 camera limits（设为极大值 ±10000）
- 退出商店阶段后：恢复原始 limits（±MAP_HALF_WIDTH, ±MAP_HALF_HEIGHT）

### 相机 offset 和 shake 重置

`camera_shake.gd` 每帧设置 `offset`（抖动+前瞻）。商店阶段需要：

- 重置 `camera.offset = Vector2.ZERO`
- 设置 `camera.set_process(false)` 暂停 shake/look-ahead 的 `_process`
- 退出商店阶段时恢复 `camera.set_process(true)`

### 过渡动画

**进入商店阶段（波次结束 → 商店）：**
1. 禁用玩家输入，清零速度
2. 扩大 camera limits
3. 重置 camera offset，暂停 camera `_process`
4. 禁用 position_smoothing 和 drag margin
5. Tween 0.5s：Camera2D zoom → Vector2(0.865, 0.865)
6. Tween 0.5s：Camera2D position（局部）→ 目标世界位置 - Player.global_position
7. 商店面板从左侧滑入（0.3s，与相机过渡重叠）

**首次进入商店阶段（`is_first=true`）：**
- 直接设置相机参数（不用 Tween），避免启动时的过渡动画

**退出商店阶段（点击开战）：**
1. 商店面板滑出（0.3s）
2. Tween 0.5s：Camera2D zoom → 战斗 zoom（`GameConfig.effects.camera_zoom`，默认 1.0）
3. Tween 0.5s：Camera2D position → Vector2.ZERO（回到玩家中心）
4. Tween 完成后：恢复 camera limits、position_smoothing、drag margin、`_process`
5. 恢复玩家输入

**实现位置：** `main.gd` 的 `_enter_shop_phase` / `_enter_battle_phase`，通过 `$Player` 获取 Camera2D 子节点引用。

### 交互时序

相机 Tween 进行中时，商店面板交互（包括塔放置拖拽）可以正常使用，因为 `DragManager._viewport_to_world()` 每帧读取当前 canvas_transform，能正确适应变化中的相机状态。

## 商店面板布局

### 结构

```
ShopOverlay (CanvasLayer, layer=10)
└── ShopPanel (PanelContainer, 左侧锚定, 宽度 169px, 全高)
    └── VBoxContainer
        ├── InfoBar (VBoxContainer) — 两行紧凑信息
        │   ├── Line1: "$34  Lv.4"
        │   └── Line2: "人口 3/5  Wave 0"
        ├── CardList (VBoxContainer, size_flags_vertical=EXPAND_FILL)
        │   ├── Card0 (HBoxContainer, ~160×32)
        │   │   ├── Icon (TextureRect, 16×16)
        │   │   ├── NameLabel
        │   │   └── PriceLabel
        │   ├── Card1 ...
        │   ├── Card2 ...
        │   └── Card3 ...
        ├── RefreshButton — "刷新 $2"
        ├── LevelUpButton — "Lv↑ $12"
        ├── RecycleArea (PanelContainer) — 回收区
        └── StartButton — "开战"
```

### 锚定

- `anchor_left = 0, anchor_top = 0, anchor_right = 0, anchor_bottom = 1`
- 固定宽度 169px（`custom_minimum_size.x = 169`）

### 卡片样式

- 从纵向大卡片（PanelContainer 60×80，图标上方垂直排列）→ 横向小卡片（~160×32，水平排列）
- 图标：32×32 → 16×16
- 布局：HBoxContainer（图标 | 名称 | 价格），价格右对齐

### 滑入滑出动画

- `slide_in()`：面板从 X = -panel_width 滑到 X = 0（0.3s Tween）
- `slide_out()`：面板从 X = 0 滑到 X = -panel_width（0.3s Tween）
- 改为水平方向（原来是垂直方向从底部滑出）

## 改动文件

| 文件 | 改动 |
|------|------|
| `scripts/ui/shop_overlay.gd` | 面板改左侧锚定，纵向布局，卡片横向小尺寸，滑动改水平方向 |
| `scenes/ui/shop_overlay.tscn` | 锚定改左侧全高，宽度 169px |
| `scripts/ui/main.gd` | 进入/退出商店阶段时 Tween 相机 zoom + position + limits |
| `tests/unit/test_shop_overlay.gd` | 适配新布局 |

## 不涉及

- 新文件、新 Resource、新 Autoload
- 战斗阶段的相机行为（保持不变）
- 商店逻辑（ShopManager、GameData 不变）

## 已知预存问题（不在本次范围内修复）

- `DragManager.is_over_recycle_area()` 使用世界坐标与屏幕坐标混合比较，在相机偏移时可能不准。如出现问题后续修复。
