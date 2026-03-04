# 配置驱动优化实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 建立统一的配置系统，支持热重载和游戏内调试，解决数值调整困难问题

**Architecture:** 创建 GameConfig 全局单例管理所有游戏数值，重构现有代码从配置读取参数，添加 DebugManager 提供调试面板和快捷键

**Tech Stack:** Godot 4.6, GDScript, Autoload 单例系统

**Design Document:** `docs/plans/2026-03-04-config-driven-optimization-design.md`

---

## 计划结构

本实施计划分为 4 个阶段，每个阶段的详细步骤在独立文件中：

### 阶段 1：配置系统基础
**文件:** `2026-03-04-config-driven-phase1.md`
**内容:** 创建 GameConfig 单例，定义所有配置常量
**预计时间:** 30-45 分钟

### 阶段 2：核心系统重构
**文件:** `2026-03-04-config-driven-phase2.md`
**内容:** 重构玩家、敌人、塔系统使用配置
**预计时间:** 60-90 分钟

### 阶段 3：调试工具开发
**文件:** `2026-03-04-config-driven-phase3.md`
**内容:** 实现调试面板、快捷键、热重载功能
**预计时间:** 60-90 分钟

### 阶段 4：难度平衡调整
**文件:** `2026-03-04-config-driven-phase4.md`
**内容:** 使用调试工具调整游戏难度，测试平衡性
**预计时间:** 30-60 分钟

---

## 总体原则

### DRY (Don't Repeat Yourself)
- 所有数值配置只在 GameConfig 中定义一次
- 避免在多个文件中重复相同的配置逻辑

### YAGNI (You Aren't Gonna Need It)
- 只实现当前需要的配置项
- 不添加未来可能用到的功能
- 调试面板只包含必要功能

### TDD (Test-Driven Development)
- 每次修改后立即运行游戏测试
- 确保功能正常后再提交
- 使用调试工具验证配置生效

### 频繁提交
- 每完成一个小任务就提交
- 提交信息清晰描述改动
- 保持每次提交的改动范围小而聚焦

---

## 执行顺序

1. 阅读设计文档 `docs/plans/2026-03-04-config-driven-optimization-design.md`
2. 按顺序执行阶段 1-4
3. 每个阶段完成后测试游戏功能
4. 所有阶段完成后进行完整的游戏测试

---

## 验收标准

### 功能验收
- [ ] 所有游戏数值从 GameConfig 读取
- [ ] F12 可以打开/关闭调试面板
- [ ] F9 可以热重载配置
- [ ] 调试快捷键（F1-F5）正常工作
- [ ] 游戏难度明显提升

### 代码质量验收
- [ ] 无硬编码的游戏数值
- [ ] 代码可读性提升
- [ ] 配置结构清晰易懂
- [ ] 调试代码不影响正式版本

### 测试验收
- [ ] 游戏可以正常启动
- [ ] 所有场景流程正常
- [ ] 武器、敌人、塔功能正常
- [ ] 商店和波次系统正常

---

**下一步:** 开始执行阶段 1 - 配置系统基础
