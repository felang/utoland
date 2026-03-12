# 地图选择界面 UI 重构设计

## 概述

将地图选择界面从当前的水平卡片布局改为吸血鬼幸存者风格的单列横条卡片列表，支持纵向滚动和解锁进度。

## 当前状态

- `scenes/ui/map_select.tscn` — HBoxContainer 水平排列地图卡片
- `scripts/ui/map_select.gd` — 动态生成 PanelContainer 卡片（色块 + 名称 + 选择按钮）
- 2 张地图：forest、desert
- MapData 字段：id, display_name, description, preview_image, background, fallback_color (String 类型, 如 "#2d5016"), wave_count, map_scene

## 设计方案

### 布局

- 单列纵向列表，每张地图一整行横条卡片
- 外层 ScrollContainer 支持纵向滚动（地图多时）
- 卡片结构：左侧预览色块（64x48，fallback_color 渐变）→ 地图名称 → 右侧状态图标

### 卡片样式

**已解锁地图：**
- 背景：StyleBoxFlat，用 `Color(map_data.fallback_color)` 转换后作为 bg_color，略加深色调
- 左侧：ColorRect 预览色块（64x48），用 fallback_color，圆角 6px
- 中间：地图名称，`UIConstants.FONT_SIZE_SUBTITLE`，`UIConstants.COLOR_TEXT_PRIMARY`
- 右侧：Label ">" 字符，`UIConstants.COLOR_GOLD`
- 点击整个卡片即可选择进入
- 卡片最小高度 64px

**锁定地图：**
- 背景：同上但颜色 darkened(0.6) + alpha 降低
- 整体 modulate.a = 0.6
- 右侧：Label 显示锁图标文字
- 点击无响应

### 解锁逻辑

简单顺序解锁，使用 GameConfig.maps 的字典顺序（不新增字段）：
- 第一张地图（forest）永远解锁
- 后续地图暂时 hardcode 为锁定状态
- 后续版本接入存档系统时再改为动态判断

### 选择行为

点击已解锁的地图卡片时：
1. `GameData.selected_map = map_id`
2. `SceneManager.go_to(Enums.Scene.MAIN)`

返回按钮：`SceneManager.go_to(Enums.Scene.CHARACTER_SELECTION)`

（与当前逻辑一致）

### 场景树结构

```
MapSelect (Control, full rect)
├── Background (ColorRect, UIConstants.COLOR_BG_PRIMARY)
├── MarginContainer (居中留边距)
│   └── VBoxContainer
│       ├── TitleLabel ("选择地图", UIConstants.FONT_SIZE_TITLE, UIConstants.COLOR_GOLD)
│       ├── ScrollContainer (纵向滚动)
│       │   └── MapList (VBoxContainer, separation=10)
│       │       └── [动态生成的横条卡片]
│       └── BackButton ("← 返回选角", UIConstants.FONT_SIZE_SMALL)
```

### 实现方式

- 原地重构 `map_select.gd` 和 `map_select.tscn`
- tscn 中将 HBoxContainer(MapContainer) 替换为 ScrollContainer > VBoxContainer(MapList) 结构
- 脚本中 `_create_map_card()` 改为生成横条卡片，新增 `_is_map_unlocked()` 判断
- 不需要单独的卡片场景，继续用代码动态创建

### 交互

- 已解锁卡片：hover 时边框高亮（`UIConstants.COLOR_GOLD`），点击进入地图
- 锁定卡片：hover 无反应，点击无响应
- 返回按钮：回到角色选择

## 测试计划

- 已解锁地图点击 → 正确设置 GameData.selected_map 并跳转 MAIN 场景
- 锁定地图点击 → 无响应
- 卡片数量 = GameConfig.maps 数量
- 第一张地图始终解锁
- 空 maps 字典 → 不崩溃

## 不做的事

- 不做预览图加载（preview_image），用 fallback_color 色块代替
- 不做难度标签
- 不做波数/描述显示
- 不做存档持久化
- 不做卡片动画/过渡效果
- 不做未知地图占位（??? 卡片），后续有需要再加
