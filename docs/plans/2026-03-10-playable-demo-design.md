# 可试玩 Demo 设计

> 目标：自己测试验证核心玩法循环是否有趣，快速迭代手感
> 日期：2026-03-10

## 概述

项目核心流程已完整（开始菜单→角色选择→地图选择→战斗→商店→结算），253 个测试全部通过。距离可试玩 demo 缺少的是影响"手感验证"的几个关键模块。

## 模块 1：基础音效系统

### 架构
新建 `AudioManager` Autoload 单例（`scripts/systems/audio_manager.gd`），统一管理 SFX 播放。

### 音效列表
用 jsfxr 生成 .wav，放 `assets/sfx/`：

| 音效 | 触发点 |
|------|--------|
| shoot | 武器开火 |
| hit | 子弹命中敌人 |
| enemy_die | 敌人死亡 |
| coin_pickup | 拾取金币 |
| player_hit | 玩家受伤 |
| wave_start | 波次开始 |
| wave_complete | 波次结束 |
| shop_buy | 商店购买 |
| boss_appear | Boss 出现 |

### 实现细节
- 各系统通过 `AudioManager.play("shoot")` 播放
- AudioManager 内部用 `AudioStreamPlayer` 池（~8个）避免同时播放过多时丢声
- 音效配置通过字典映射音效名→AudioStream 路径
- 音量统一默认值，暂不做设置面板

## 模块 2：暂停功能

### 实现
- `main.gd` 战斗场景中监听 ESC 键，切换 `get_tree().paused`
- 新增 `pause` input action 绑定 ESC 键

### UI
- `PauseOverlay`（CanvasLayer，高 z-index）作为 `main.tscn` 子节点
- 半透明遮罩 + "已暂停" 文字 + "继续"/"返回主菜单" 按钮
- process_mode = PROCESS_MODE_ALWAYS（暂停时仍可交互）

## 模块 3：Boss 蛮兽冲锋技能

### 行为设计
boss_brute 每隔一段时间对玩家发起冲锋：

1. **预警**：原地停顿 0.8s，闪红（提示玩家躲避）
2. **冲刺**：朝玩家当前位置高速直线移动（速度 ×4），持续 0.6s
3. 冲锋期间碰到玩家造成 2 倍伤害 + 强击退
4. **眩晕**：冲锋结束后停止移动 0.5s，然后恢复正常追击

### 实现
- `boss_brute.gd` 中用状态机：CHASE → CHARGE_WINDUP → CHARGING → STUNNED → CHASE
- 冲锋伤害通过现有 Hitbox 体系，临时提高 damage 值
- 触发条件：冷却 8s + 与玩家距离 > 80px

### 数值
在 `EnemyData` 中新增可选字段（只有 boss_brute 的 .tres 填值）：
- `charge_cooldown: float` (8.0)
- `charge_speed_mult: float` (4.0)
- `charge_damage_mult: float` (2.0)
- `charge_windup_time: float` (0.8)

## 模块 4：调试面板

### 实现
- `DebugPanel`（CanvasLayer）作为 `main.tscn` 子节点
- F1 切换显隐
- process_mode = PROCESS_MODE_ALWAYS

### 显示内容
- 当前波次 / 总波次
- 存活敌人数
- 玩家 HP / 伤害 / 攻速
- 当前金币
- FPS

### 快捷操作
- F2：跳过当前波次（触发波次完成）
- F3：加 100 金币
- F4：切换无敌模式
