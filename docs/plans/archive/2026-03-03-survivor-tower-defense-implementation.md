# 幸存者+阵地战游戏 MVP 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现一个结合 Brotato 式自动射击和植物大战僵尸式阵地建设的 2D 生存游戏 MVP

**Architecture:** 使用 Godot 4.6 引擎，采用三阶段渐进式开发。阶段1验证核心战斗手感，阶段2完善战斗循环和多样性，阶段3补全商店和成长系统。充分利用 GDAI MCP 工具进行场景和脚本创建。

**Tech Stack:** Godot 4.6, GDScript, GDAI MCP Plugin

---

## 计划结构

本实施计划分为三个阶段，每个阶段都有独立的详细任务文档：

### [阶段 1：核心战斗原型](./2026-03-03-survivor-tower-defense-phase1.md)
**目标**: 验证核心手感（走位+自动射击+怪物追击+塔阻挡）
**时间**: 2-3天
**关键功能**:
- 玩家 WASD 移动 + 摄像机跟随
- 单一武器自动射击最近敌人
- 单一敌人类型追击玩家
- 3个预设坚果墙测试阻挡机制
- 简单 HUD 和 60 秒生存测试

### [阶段 2：完整战斗循环](./2026-03-03-survivor-tower-defense-phase2.md)
**目标**: 完善战斗循环（多样性+难度曲线+经济系统）
**时间**: 2-3天
**关键功能**:
- 3种敌人类型（普通/快速/肉盾）
- 3种植物塔类型（豌豆射手/坚果墙/冰雪菇）
- 10波次渐进难度系统
- 金币掉落和自动吸附

### [阶段 3：商店与成长系统](./2026-03-03-survivor-tower-defense-phase3.md)
**目标**: 补全游戏流程（商店+成长+完整UI）
**时间**: 2-3天
**关键功能**:
- 完整游戏流程（开始→选择→战斗→商店循环→结算）
- 2种武器选择
- 6种被动属性强化
- 初始布置期和局间布置期
- 商店随机刷新机制

---

## 核心技术要点

### 碰撞层配置（关键）
```
Layer 1: 玩家 - 与敌人碰撞，穿透植物塔
Layer 2: 敌人 - 被植物塔阻挡，可触碰玩家
Layer 3: 植物塔 - 阻挡敌人，不阻挡玩家
Layer 4: 玩家子弹 - 穿透植物塔，命中敌人
Layer 5: 金币/拾取物 - 玩家靠近自动吸附
```

### 项目目录结构
```
utoland/
├── scenes/
│   ├── main.tscn (主战斗场景)
│   ├── player.tscn (玩家场景)
│   ├── enemies/
│   │   ├── enemy_base.tscn
│   │   ├── enemy_normal.tscn
│   │   ├── enemy_fast.tscn
│   │   └── enemy_tank.tscn
│   ├── towers/
│   │   ├── tower_base.tscn
│   │   ├── tower_shooter.tscn
│   │   ├── tower_wall.tscn
│   │   └── tower_slow.tscn
│   ├── bullet.tscn
│   ├── coin.tscn
│   └── ui/
│       ├── hud.tscn
│       ├── shop.tscn
│       ├── start_menu.tscn
│       ├── weapon_select.tscn
│       └── result.tscn
├── scripts/
│   ├── player.gd
│   ├── enemy.gd
│   ├── tower.gd
│   ├── weapon.gd
│   ├── bullet.gd
│   ├── coin.gd
│   ├── wave_manager.gd
│   ├── enemy_spawner.gd
│   ├── tower_manager.gd
│   └── shop_manager.gd
└── project.godot
```

---

## 开发原则

1. **TDD (Test-Driven Development)**: 每个功能先在场景中测试，确认工作后再继续
2. **DRY (Don't Repeat Yourself)**: 使用基类（enemy.gd, tower.gd）避免重复代码
3. **YAGNI (You Aren't Gonna Need It)**: 只实现当前阶段需要的功能
4. **频繁提交**: 每完成一个小功能就提交，便于回滚和追踪

---

## 执行方式

请查看各阶段的详细实施文档：
- [阶段 1 详细任务](./2026-03-03-survivor-tower-defense-phase1.md)
- [阶段 2 详细任务](./2026-03-03-survivor-tower-defense-phase2.md)
- [阶段 3 详细任务](./2026-03-03-survivor-tower-defense-phase3.md)

---

**计划创建日期**: 2026-03-03
**预计完成时间**: 6-9天
