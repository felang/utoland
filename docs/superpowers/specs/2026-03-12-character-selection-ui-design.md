# 角色选择界面重构设计

## 概述

将角色选择界面从水平卡片列表重构为左右分栏布局（类似 Ball X Pit）：左侧纯头像列表，右侧详细信息面板。

## 布局结构

### 整体

```
CharacterSelection (Control, 全屏)
├── Background (ColorRect, UIConstants.COLOR_BG_PRIMARY)
├── TitleLabel ("选择你的角色", 顶部居中)
├── HSplitContent (HBoxContainer, 左右分栏)
│   ├── LeftPanel (ScrollContainer, 固定宽度 120px)
│   │   └── PortraitList (VBoxContainer)
│   │       └── [动态生成] PortraitButton × N (TextureButton, 80×80)
│   └── RightPanel (PanelContainer, 填充剩余空间)
│       └── DetailContainer (详情面板)
└── BackButton ("← 返回主菜单", 左下角)
```

左侧 ScrollContainer 保证角色数量增加时可滚动。

### 右侧详情面板

```
DetailContainer (MarginContainer, UIConstants.GAP_SECTIONS)
└── VBoxContainer (间距 UIConstants.MARGIN_PANEL)
    ├── HeaderSection (HBoxContainer)
    │   ├── LargePortrait (TextureRect, 120×120, 角色大头像)
    │   └── NameAndWeapon (VBoxContainer)
    │       ├── CharacterName (Label, UIConstants.FONT_SIZE_SUBTITLE, UIConstants.COLOR_GOLD)
    │       └── WeaponLabel (Label, UIConstants.FONT_SIZE_SMALL, "默认武器: XXX")
    ├── StatsSection (PanelContainer, UIConstants.COLOR_BG_PANEL)
    │   └── StatsGrid (GridContainer, 2列)
    │       ├── "生命值"   | HPValue (max_hp)
    │       ├── "速度"     | SpeedValue (speed)
    │       ├── "伤害倍率" | DamageValue (damage_mult)
    │       ├── "攻速倍率" | AttackSpeedValue (attack_speed_mult)
    │       └── "生命回复" | HPRegenValue (hp_regen)
    ├── AffinitySection (HBoxContainer)
    │   ├── TagLabels (亲和标签, 小色块)
    │   └── DiscountLabel ("折扣 XX%")
    ├── PassiveSection (VBoxContainer)
    │   ├── PassiveTitle ("被动技能", UIConstants.FONT_SIZE_BODY)
    │   └── PassiveDesc (Label, 自动换行, UIConstants.COLOR_TEXT_SECONDARY)
    └── SelectButton ("选择此角色", 底部, UIConstants.COLOR_GOLD 高亮)
```

### 属性颜色

基准值定义（与现有 character_card.gd 保持一致）：
- max_hp: 100.0
- speed: 200.0
- damage_mult: 1.0
- attack_speed_mult: 1.0
- hp_regen: 0.0

颜色规则：
- 高于基准值：UIConstants.COLOR_POSITIVE
- 低于基准值：UIConstants.COLOR_ACCENT_DANGER
- 等于基准值：UIConstants.COLOR_TEXT_PRIMARY
- 属性差异化后自动生效，无需改 UI 代码

### 被动技能

- passive_description 为空时显示 "暂无被动技能" 占位文字

### 头像资产

- 从 CharacterData.portrait_path 加载头像
- 加载失败时使用深色 ColorRect 占位（与现有卡片 PortraitRect 行为一致）

## 交互逻辑

### 初始状态

- 默认选中第一个角色，右侧显示其详情
- 左侧第一个头像自动加金色边框 (UIConstants.COLOR_GOLD)

### 选中切换

- 点击左侧头像：更新金色边框，右侧面板直接替换数据（无动画）
- 注意：这是从单击直接选择到"先预览再确认"的交互变更，属于有意设计

### 选择确认

- 点击 "选择此角色"：写入 GameData (current_character, selected_weapon)，调用 init_character()
- 跳转 SceneManager.go_to(Enums.Scene.MAP_SELECT)
- 注意：reset() 在进入战斗场景时调用，此处只做角色初始化

### 返回

- 点击 "← 返回主菜单"：SceneManager.go_to(Enums.Scene.START_MENU)

### 键盘导航

- 暂不实现，作为后续增强项

## 代码结构

### 实现方式：场景模板 + 脚本填充

- `character_selection.tscn` — 预定义整体布局和右侧面板模板节点
- `character_selection.gd` — 动态生成左侧头像列表、处理选中切换、填充右侧数据

### 废弃文件

- `character_card.tscn` — 不再使用，删除
- `character_card.gd` — 不再使用，删除

## 测试计划

- 验证所有角色数据正确填充到详情面板（属性值、武器名、亲和标签）
- 验证 GameData 写入正确（current_character、selected_weapon、init_character 调用）
- 验证空 characters 字典时的边界处理
- 验证头像加载失败时的 fallback 行为
- 更新现有引用 character_card 的测试（如有）

## 设计考量

- 左侧动态生成头像，支持后续增减角色
- 属性展示预留完整字段，当前值相同但差异化后无需改 UI
- 被动技能区域预留，内容为空时有占位提示
- ScrollContainer 保证角色列表可扩展
- 所有颜色和字号引用 UIConstants，保持风格统一
