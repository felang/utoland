# MCP-First Architecture Refactor - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor utoland project to MCP-First architecture, eliminating technical debt and establishing automated testing

**Architecture:** Three-layer pattern (Scene Templates → Scene Factories → Scene Controllers) with GUT testing framework and strict development rules

**Tech Stack:** Godot 4.6, GDScript, GUT (Godot Unit Test), GDAI MCP tools

**Design Document:** `docs/plans/2026-03-05-technical-debt-resolution-design.md`

---

## Plan Structure

This implementation plan is split into multiple files for manageability:

- **This file** - Overview and execution guidance
- **Phase 1** - `2026-03-05-mcp-first-refactor-phase1.md` - Foundation (GUT + SceneFactory)
- **Phase 2** - `2026-03-05-mcp-first-refactor-phase2.md` - Refactor Existing Code
- **Phase 3** - `2026-03-05-mcp-first-refactor-phase3.md` - Scene Reconstruction
- **Phase 4** - `2026-03-05-mcp-first-refactor-phase4.md` - Cleanup & Documentation
- **Phase 5** - `2026-03-05-mcp-first-refactor-phase5.md` - Validation

---

## Execution Strategy

**Approach:** Phased execution with validation checkpoints

**After each phase:**
1. Run all tests (`gut` command)
2. Manual playtest (Start → Character → Weapon → Map → Placement → Combat)
3. Verify no regressions
4. Commit changes
5. Get user approval before proceeding to next phase

**Rollback strategy:** Each phase is a clean git commit, can revert if issues arise

---

## Phase Overview

### Phase 1: Foundation (~4 hours)
- Install GUT testing framework
- Create SceneFactory.gd with all entity creation methods
- Write .claude/rules/ documentation (4 files)
- Reorganize scripts/ directory structure
- Write initial unit tests

**Deliverables:** Working test suite, SceneFactory, rules docs, reorganized structure

---

### Phase 2: Refactor Existing Code (~6 hours)
- Refactor placement.gd to use SceneFactory
- Refactor main.gd tower restoration
- Remove all hardcoded values
- Update all scripts to new directory structure
- Write integration tests

**Deliverables:** Zero hardcoded values, all instantiation through SceneFactory, passing tests

---

### Phase 3: Scene Reconstruction (~3 hours)
- Document current scene structures
- Rebuild scenes using MCP tools only
- Verify identical functionality
- Add regression tests

**Deliverables:** MCP-created scenes, git history shows MCP usage

---

### Phase 4: Cleanup & Documentation (~2 hours)
- Delete test_*.tscn files
- Create dev_playground.tscn
- Update CLAUDE.md
- Create code review checklist
- Final test suite run

**Deliverables:** Clean project, updated docs, 100% passing tests

---

### Phase 5: Validation (~1 hour)
- Full end-to-end playthrough
- Verify all systems work
- Confirm MCP tools work correctly
- Final test suite run

**Deliverables:** Working game, zero regressions, ready to ship

---

## Success Criteria

After completion:
- ✅ Zero manual .tscn edits (all via MCP tools)
- ✅ Zero hardcoded values (everything from GameConfig)
- ✅ Automated test coverage (core systems)
- ✅ Clean architecture (separation of concerns)
- ✅ Comprehensive documentation (rules with examples)
- ✅ Maintainable codebase (easy to extend)

---

## Next Steps

1. Read Phase 1 implementation plan: `docs/plans/2026-03-05-mcp-first-refactor-phase1.md`
2. Execute Phase 1 tasks
3. Validate Phase 1 completion
4. Get user approval
5. Proceed to Phase 2

---

**Plan Status:** Ready for execution
**Start Date:** 2026-03-05
**Estimated Total Time:** ~16 hours across 5 phases
