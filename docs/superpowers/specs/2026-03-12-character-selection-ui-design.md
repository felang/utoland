# 角色选择界面重构设计

## 概述

将角色选择界面从水平卡片列表重构为左右分栏布局（类似 Ball X Pit）：左侧纯头像列表，右侧详细信息面板。

## 布局结构

### 整体

```
CharacterSelection (Control, 全屏)
├── Background (ColorRect, #1a1a2e)
├── TitleLabel ("选择你的角色", 顶部居中)
├── HSplitContent (HBoxContainer, 左右分栏)
│   ├── LeftPanel (ScrollContainer, 固定宽度 ~120px, 约 15% 屏幕宽度)
│   │   └── PortraitList (VBoxContainer)
│   │       └── [动态生成] PortraitButton × N (TextureButton, 80×80)
│   └── RightPanel (PanelContainer, 填充剩余空间 ~85%)
│       └── DetailContainer (详情面板)
└── BackButton ("← 返回主菜单", 左下角)
```

左侧 ScrollContainer 保证角色数量增加时可滚动。

### 右侧详情面板

```
DetailContainer (MarginContainer, 内边距 20px)
└── VBoxContainer (间距 16px)
    ├── HeaderSection (HBoxContainer)
    │   ├── LargePortrait (TextureRect, 120×120, 角色大头像)
    │   └── NameAndWeapon (VBoxContainer)
    │       ├── CharacterName (Label, 24px, 金色 #ffd700)
    │       └── WeaponLabel (Label, 14px, "默认武器: XXX")
    ├── StatsSection (PanelContainer, 深色背景)
    │   └── StatsGrid (GridContainer, 2列)
    │       ├── "生命值"   | HPValue
    │       ├── "速度"     | SpeedValue
    │       ├── "伤害倍率" | DamageValue
    │       ├── "攻速倍率" | AttackSpeedValue
    │       └── "生命回复" | HPRegenValue
    ├── AffinitySection (HBoxContainer)
    │   ├── TagLabels (亲和标签, 小色块)
    │   └── DiscountLabel ("折扣 XX%")
    ├── PassiveSection (VBoxContainer)
    │   ├── PassiveTitle ("被动技能", 18px)
    │   └── PassiveDesc (Label, 自动换行, 灰色文字)
    └── SelectButton ("选择此角色", 底部, 金色高亮)
```

### 属性颜色

- 高于基准值：绿色 (#4ecca3)
- 低于基准值：红色 (#e94560)
- 等于基准值：白色 (#e0e0e0)
- 属性差异化后自动生效，无需改 UI 代码

### 被动技能

- passive_description 为空时显示 "暂无被动技能" 占位文字

## 交互逻辑

### 初始状态

- 默认选中第一个角色，右侧显示其详情
- 左侧第一个头像自动加金色边框 (#ffd700)

### 选中切换

- 点击左侧头像：更新金色边框，右侧面板直接替换数据（无动画）

### 选择确认

- 点击 "选择此角色"：写入 GameData (current_character, selected_weapon, init_character())，跳转 MAP_SELECT

### 返回

- 点击 "← 返回主菜单"：SceneManager.go_to("START_MENU")

## 代码结构

### 实现方式：场景模板 + 脚本填充

- `character_selection.tscn` — 预定义整体布局和右侧面板模板节点
- `character_selection.gd` — 动态生成左侧头像列表、处理选中切换、填充右侧数据

### 废弃文件

- `character_card.tscn` — 不再使用，删除
- `character_card.gd` — 不再使用，删除

## 设计考量

- 左侧动态生成头像，支持后续增减角色
- 属性展示预留完整字段，当前值相同但差异化后无需改 UI
- 被动技能区域预留，内容为空时有占位提示
- ScrollContainer 保证角色列表可扩展
