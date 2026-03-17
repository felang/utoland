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

### 过渡动画

**进入商店阶段（波次结束 → 商店）：**
1. Tween 0.5s：Camera2D zoom 从当前值 → Vector2(0.865, 0.865)
2. Tween 0.5s：Camera2D global_position 从玩家位置 → Vector2(-98, 0)
3. 禁用 Camera2D 的 position_smoothing 和 drag margin（防止相机跟随玩家）
4. 商店面板从左侧滑入（0.3s，与相机过渡重叠）

**退出商店阶段（点击开战）：**
1. 商店面板滑出（0.3s）
2. Tween 0.5s：Camera2D zoom 从 0.865 → 战斗 zoom（1.0）
3. Tween 0.5s：Camera2D global_position → 玩家位置
4. 恢复 Camera2D 的 position_smoothing 和 drag margin

**实现位置：** `main.gd` 的 `_enter_shop_phase` / `_enter_battle_phase`，通过 `$Player` 获取 Camera2D 子节点引用。

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
| `scripts/ui/main.gd` | 进入/退出商店阶段时 Tween 相机 zoom + position |
| `tests/unit/test_shop_overlay.gd` | 适配新布局 |

## 不涉及

- 新文件、新 Resource、新 Autoload
- 战斗阶段的相机行为（保持不变）
- 商店逻辑（ShopManager、GameData 不变）
- DragManager 拖拽逻辑（不变）
