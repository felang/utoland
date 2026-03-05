# Phase 5: Validation - Implementation Plan

> **For Claude:** Execute tasks sequentially. This is the final validation phase.

**Goal:** Verify everything works end-to-end, no regressions, ready to ship

**Estimated Time:** ~1 hour

---

## Task 1: Complete Game Playthrough

**Manual Testing - Full Game Loop**

### Step 1: Start game

In Godot: Press F5

**Verify:**
- [ ] Game loads without errors
- [ ] Start menu appears
- [ ] No console errors

### Step 2: Character selection

Click "开始游戏" → Character selection screen

**Test each character:**
- [ ] Select Warrior → Stats display correctly
- [ ] Select Ranger → Stats display correctly
- [ ] Select Tank → Stats display correctly
- [ ] Click "确认" → Proceeds to weapon select

### Step 3: Weapon selection

**Test each weapon:**
- [ ] Select Rifle → Description shows
- [ ] Select Shotgun → Description shows
- [ ] Select Sniper → Description shows
- [ ] Click "确认" → Proceeds to map select

### Step 4: Map selection

**Test each map:**
- [ ] Select Forest → Preview shows
- [ ] Select Desert → Preview shows
- [ ] Click "确认" → Proceeds to placement

### Step 5: Placement scene - Wave 1

**Test tower placement:**
- [ ] Click "射手塔" → Preview appears
- [ ] Move mouse → Preview follows (grid-aligned)
- [ ] Left click → Tower placed, coins deducted
- [ ] Right click → Preview cancelled
- [ ] Place shooter tower (verify cost from SceneFactory)
- [ ] Place wall tower (verify cost from SceneFactory)
- [ ] Place slow tower (verify cost from SceneFactory)
- [ ] Try placing without coins → Disabled/prevented
- [ ] Coins display updates correctly
- [ ] Click "开始战斗" → Proceeds to combat

### Step 6: Combat scene - Wave 1

**Test combat systems:**
- [ ] Towers restored at correct positions
- [ ] Player spawns correctly
- [ ] Player can move (WASD)
- [ ] Player auto-aims at enemies
- [ ] Player shoots bullets
- [ ] Enemies spawn from edges
- [ ] Normal enemies appear
- [ ] Fast enemies appear (if wave 1 has them)
- [ ] Shooter tower shoots enemies
- [ ] Wall tower blocks enemies
- [ ] Slow tower slows enemies
- [ ] Enemies attack towers
- [ ] Towers take damage and die
- [ ] Enemies drop coins on death
- [ ] Player can collect coins
- [ ] Wave timer counts down
- [ ] HUD displays correctly (HP, coins, wave)
- [ ] Wave completes → Proceeds to shop

### Step 7: Shop scene - After Wave 1

**Test shop system:**
- [ ] Coins carried over from combat
- [ ] 4 random items displayed
- [ ] Item prices shown
- [ ] Click "刷新" → New items, coins deducted
- [ ] Purchase passive upgrade → Coins deducted, stats updated
- [ ] Purchase tower → Coins deducted, tower added to inventory
- [ ] Purchase heal → Coins deducted, HP restored
- [ ] Cannot purchase without coins
- [ ] Click "继续" → Proceeds to placement

### Step 8: Placement scene - Wave 2

**Test tower persistence:**
- [ ] Previous towers still present at correct positions
- [ ] Can place new towers
- [ ] Purchased tower from shop available
- [ ] Place additional towers
- [ ] Click "开始战斗" → Proceeds to combat

### Step 9: Combat scene - Wave 2

**Test progression:**
- [ ] All towers present (old + new)
- [ ] Player stats reflect shop upgrades
- [ ] Enemies spawn with wave 2 config
- [ ] More/harder enemies than wave 1
- [ ] All systems work correctly
- [ ] Complete wave → Proceeds to shop

### Step 10: Continue to Wave 3+

**Test extended gameplay:**
- [ ] Repeat shop → placement → combat cycle
- [ ] Verify no memory leaks (performance stable)
- [ ] Verify no visual glitches
- [ ] Verify no gameplay bugs

### Step 11: Test win condition

**Complete all 10 waves:**
- [ ] Wave 10 completes
- [ ] Result screen shows "胜利"
- [ ] Stats displayed correctly
- [ ] Click "返回主菜单" → Returns to start

### Step 12: Test lose condition

**Intentionally lose:**
- [ ] Let player HP reach 0
- [ ] Result screen shows "失败"
- [ ] Stats displayed correctly
- [ ] Click "返回主菜单" → Returns to start

### Step 13: Document playthrough results

Create report:
```
Full Playthrough Test Results:
✅ Start menu works
✅ Character selection works (all 3 characters)
✅ Weapon selection works (all 3 weapons)
✅ Map selection works (all 2 maps)
✅ Tower placement works (all 3 tower types)
✅ Combat works (player, enemies, towers)
✅ Shop works (all item types)
✅ Multi-wave progression works
✅ Tower persistence works
✅ Win condition works
✅ Lose condition works
✅ No crashes or errors
✅ Performance stable
```

---

## Task 2: Verify Code Quality

**Code Quality Checks**

### Step 1: No hardcoded values

```bash
grep -rn "[0-9]\{2,\}" scripts/ | grep -v "# " | grep -v "//" | grep -v "scene_factory.gd"
```

Expected: Only legitimate numbers (array indices, etc.)

### Step 2: No preload outside SceneFactory

```bash
grep -r "preload" scripts/ | grep -v "scene_factory.gd"
```

Expected: No matches

### Step 3: No scene paths outside SceneFactory

```bash
grep -r "res://scenes" scripts/ | grep -v "scene_factory.gd"
```

Expected: No matches

### Step 4: No direct instantiate without config

```bash
grep -r "\.instantiate()" scripts/ | grep -v "scene_factory.gd"
```

Expected: No matches

### Step 5: Document findings

Create report:
```
Code Quality Verification:
✅ No hardcoded values found
✅ No preload() outside SceneFactory
✅ No scene paths outside SceneFactory
✅ No direct instantiate() calls
✅ All code follows standards
```

---

## Task 3: Verify MCP Tools Work

**Test MCP Tool Functionality**

### Step 1: Test scene creation

```
mcp__gdai-mcp__create_scene("res://test_mcp_scene.tscn", "Node2D")
```

Expected: Scene created successfully

### Step 2: Test node addition

```
mcp__gdai-mcp__open_scene("res://test_mcp_scene.tscn")
mcp__gdai-mcp__add_node(".", "Label", "TestLabel")
```

Expected: Node added successfully

### Step 3: Test property update

```
mcp__gdai-mcp__update_property("TestLabel", "text", "MCP Test")
```

Expected: Property updated successfully

### Step 4: Test scene loads in Godot

In Godot: Open test_mcp_scene.tscn
Expected: Scene loads, Label shows "MCP Test"

### Step 5: Clean up test scene

```bash
rm test_mcp_scene.tscn
```

### Step 6: Document MCP verification

```
MCP Tools Verification:
✅ create_scene works
✅ add_node works
✅ update_property works
✅ Scenes load correctly in Godot
✅ MCP workflow functional
```

---

## Task 4: Run Complete Test Suite

**Automated Testing**

### Step 1: Run all unit tests

In Godot: Tools → Gut → Run All Tests (Unit)

**Expected results:**
- test_scene_factory.gd: All pass
- test_game_config.gd: All pass (if exists)
- test_game_data.gd: All pass (if exists)

### Step 2: Run all integration tests

In Godot: Tools → Gut → Run All Tests (Integration)

**Expected results:**
- test_tower_placement.gd: All pass
- test_wave_system.gd: All pass
- test_scene_reconstruction.gd: All pass

### Step 3: Check test coverage

Count tests:
```bash
grep -r "func test_" tests/ | wc -l
```

Expected: 15+ tests

### Step 4: Document test results

```
Test Suite Results:
- Unit tests: X/X passing (100%)
- Integration tests: Y/Y passing (100%)
- Total tests: Z/Z passing (100%)
- Coverage: SceneFactory (100%), Core systems (100%)
```

---

## Task 5: Performance Check

**Performance Validation**

### Step 1: Monitor FPS during gameplay

In Godot: Debug → Monitor → FPS

**Test scenarios:**
- [ ] Placement scene: FPS stable (60+)
- [ ] Combat with 10 enemies: FPS stable
- [ ] Combat with 20 enemies: FPS stable
- [ ] Combat with 30+ enemies: FPS acceptable (30+)

### Step 2: Check memory usage

In Godot: Debug → Monitor → Memory

**Test scenarios:**
- [ ] Start game: Baseline memory
- [ ] After 5 waves: Memory stable (no leaks)
- [ ] After 10 waves: Memory stable

### Step 3: Check for warnings/errors

In Godot: Output panel

**Verify:**
- [ ] No errors during gameplay
- [ ] No warnings about missing resources
- [ ] No memory leak warnings

### Step 4: Document performance

```
Performance Verification:
✅ FPS stable (60+ in normal gameplay)
✅ Memory stable (no leaks detected)
✅ No errors or warnings
✅ Performance acceptable
```

---

## Task 6: Verify Git History

**Git History Check**

### Step 1: Review recent commits

```bash
git log --oneline -20
```

Expected: Clean, descriptive commit messages

### Step 2: Verify MCP usage in history

```bash
git log --grep="MCP" --oneline
```

Expected: Multiple commits showing MCP tool usage

### Step 3: Check for manual .tscn edits

```bash
git log --all --full-history -- "*.tscn" | grep -v "MCP" | head -20
```

Expected: Only old commits (before Phase 3)

### Step 4: Verify phase completion commits

```bash
git log --grep="Phase" --oneline
```

Expected: 5 commits (one per phase)

### Step 5: Document git verification

```
Git History Verification:
✅ Clean commit messages
✅ MCP usage documented in commits
✅ No manual .tscn edits (after Phase 3)
✅ All phases committed
✅ Git history clean
```

---

## Task 7: Documentation Review

**Documentation Completeness Check**

### Step 1: Verify all docs exist

```bash
ls -la CLAUDE.md
ls -la docs/ARCHITECTURE.md
ls -la docs/DEVELOPMENT.md
ls -la .claude/rules/mcp-only.md
ls -la .claude/rules/no-hardcode.md
ls -la .claude/rules/scene-factory.md
ls -la .claude/rules/testing.md
ls -la .claude/code-review-checklist.md
```

Expected: All files exist

### Step 2: Verify docs are up-to-date

Read each file, check for:
- [ ] CLAUDE.md reflects MCP-First architecture
- [ ] ARCHITECTURE.md includes SceneFactory
- [ ] DEVELOPMENT.md includes testing guide
- [ ] All rules documented with examples
- [ ] Code review checklist complete

### Step 3: Verify docs are accurate

Cross-reference with actual code:
- [ ] Directory structure matches docs
- [ ] Code examples in docs are correct
- [ ] No outdated information

### Step 4: Document documentation review

```
Documentation Review:
✅ All documentation files exist
✅ Documentation is up-to-date
✅ Documentation is accurate
✅ Examples are correct
✅ Documentation complete
```

---

## Task 8: Architecture Validation

**Architecture Compliance Check**

### Step 1: Verify three-layer pattern

**Layer 1 (Scene Templates):**
- [ ] .tscn files are minimal
- [ ] No hardcoded values in scenes
- [ ] All created via MCP tools

**Layer 2 (Scene Factories):**
- [ ] SceneFactory.gd exists
- [ ] All preload() calls in SceneFactory
- [ ] Config applied at instantiation

**Layer 3 (Scene Controllers):**
- [ ] Controllers use SceneFactory
- [ ] No scene structure knowledge
- [ ] Focus on business logic

### Step 2: Verify separation of concerns

**Check directory structure:**
```bash
tree -L 2 scripts/
```

Expected:
- core/ - Core systems
- entities/ - Game entities
- systems/ - Game systems
- ui/ - UI controllers

### Step 3: Verify configuration-driven design

**Check GameConfig usage:**
```bash
grep -r "GameConfig\." scripts/ | wc -l
```

Expected: Many references (50+)

### Step 4: Document architecture validation

```
Architecture Validation:
✅ Three-layer pattern implemented
✅ Separation of concerns maintained
✅ Configuration-driven design
✅ SceneFactory pattern followed
✅ Architecture compliant
```

---

## Task 9: Create Final Report

**Files:**
- Create: `docs/refactor-completion-report.md`

### Step 1: Create completion report

```markdown
# MCP-First Architecture Refactor - Completion Report

**Date:** 2026-03-05
**Status:** ✅ Complete

---

## Executive Summary

Successfully refactored utoland project to MCP-First architecture, eliminating all technical debt and establishing automated testing framework.

---

## Phases Completed

### Phase 1: Foundation ✅
- Installed GUT testing framework
- Created SceneFactory.gd
- Reorganized directory structure
- Wrote development rules documentation
- Added unit tests

### Phase 2: Refactor Existing Code ✅
- Eliminated all hardcoded values
- Refactored all scripts to use SceneFactory
- Removed all preload() calls outside SceneFactory
- Added integration tests
- Verified full game playthrough

### Phase 3: Scene Reconstruction ✅
- Documented scene structures
- Rebuilt all tower scenes via MCP tools
- Rebuilt all enemy scenes via MCP tools
- Added regression tests
- Verified identical functionality

### Phase 4: Cleanup & Documentation ✅
- Deleted all test scene files
- Created dev_playground.tscn (gitignored)
- Updated all documentation
- Created code review checklist
- Verified all tests passing

### Phase 5: Validation ✅
- Complete game playthrough successful
- All tests passing (100%)
- Code quality verified
- MCP tools verified working
- Performance acceptable
- Documentation complete

---

## Success Criteria Met

✅ **Zero manual .tscn edits** - All changes via MCP tools
✅ **Zero hardcoded values** - Everything from GameConfig
✅ **Automated test coverage** - Core systems tested
✅ **Clean architecture** - Clear separation of concerns
✅ **Comprehensive documentation** - Rules with examples
✅ **Maintainable codebase** - Easy to extend

---

## Metrics

**Code Quality:**
- Hardcoded values: 0
- preload() outside SceneFactory: 0
- Scene paths outside SceneFactory: 0
- Direct instantiate() calls: 0

**Testing:**
- Total tests: Z
- Passing tests: Z (100%)
- Test coverage: SceneFactory (100%), Core systems (100%)

**Performance:**
- FPS: 60+ (stable)
- Memory: Stable (no leaks)
- Errors: 0
- Warnings: 0

**Documentation:**
- CLAUDE.md: Updated ✅
- ARCHITECTURE.md: Updated ✅
- DEVELOPMENT.md: Updated ✅
- Development rules: 4 files ✅
- Code review checklist: Created ✅

---

## Technical Debt Eliminated

1. ✅ Manual .tscn editing - Now MCP-only
2. ✅ Hardcoded values - Now from GameConfig
3. ✅ Missing abstractions - SceneFactory created
4. ✅ Test scene clutter - Deleted
5. ✅ No automated testing - GUT framework installed
6. ✅ Inconsistent patterns - Standards enforced

---

## Architecture Improvements

**Before:**
- Scattered preload() calls
- Hardcoded values everywhere
- No testing
- Manual .tscn editing
- Flat directory structure

**After:**
- Centralized SceneFactory
- Configuration-driven design
- Automated testing (GUT)
- MCP-first workflow
- Organized directory structure

---

## Next Steps

**Immediate:**
- Continue using MCP tools for all scene modifications
- Write tests for new features
- Follow development rules in .claude/rules/

**Future Enhancements:**
- Add more integration tests
- Expand test coverage to UI controllers
- Consider CI/CD pipeline for automated testing

---

## Lessons Learned

1. **MCP-first workflow is effective** - Clean, reproducible scene modifications
2. **SceneFactory pattern scales well** - Easy to add new entity types
3. **Testing catches regressions** - Confidence when refactoring
4. **Documentation is crucial** - Clear rules prevent mistakes
5. **Phased approach works** - Validation checkpoints prevent issues

---

## Conclusion

The MCP-First architecture refactor is complete and successful. The codebase is now:
- Clean and maintainable
- Well-tested and reliable
- Properly documented
- Ready for future development

All technical debt has been eliminated, and the project follows best practices for Godot development with AI assistance.

---

**Report Status:** ✅ Final
**Approved By:** [User]
**Date:** 2026-03-05
```

### Step 2: Save report

Save to: `docs/refactor-completion-report.md`

### Step 3: Commit report

```bash
git add docs/refactor-completion-report.md
git commit -m "docs: add refactor completion report"
```

---

## Task 10: Final Commit and Tag

**Git Finalization**

### Step 1: Verify all changes committed

```bash
git status
```

Expected: Working tree clean

### Step 2: Review all phase commits

```bash
git log --oneline --grep="Phase"
```

Expected: 5 phase completion commits

### Step 3: Create final commit

```bash
git add -A
git commit -m "feat: complete MCP-First Architecture Refactor

All 5 phases completed successfully:
- Phase 1: Foundation (GUT + SceneFactory)
- Phase 2: Refactor Existing Code
- Phase 3: Scene Reconstruction
- Phase 4: Cleanup & Documentation
- Phase 5: Validation

Technical debt eliminated:
✅ Zero manual .tscn edits
✅ Zero hardcoded values
✅ Automated test coverage
✅ Clean architecture
✅ Comprehensive documentation

Ready for production."
```

### Step 4: Create git tag

```bash
git tag -a v1.0.0-mcp-refactor -m "MCP-First Architecture Refactor Complete"
```

### Step 5: Verify tag created

```bash
git tag -l
git show v1.0.0-mcp-refactor
```

### Step 6: Document git finalization

```
Git Finalization:
✅ All changes committed
✅ Final commit created
✅ Git tag created (v1.0.0-mcp-refactor)
✅ Repository clean
✅ Ready to push
```

---

## Phase 5 Validation

### Final Checklist

- [ ] Complete game playthrough successful
- [ ] All tests passing (100%)
- [ ] Code quality verified (no violations)
- [ ] MCP tools verified working
- [ ] Performance acceptable
- [ ] Git history clean
- [ ] Documentation complete and accurate
- [ ] Architecture compliant
- [ ] Completion report created
- [ ] Final commit and tag created

### Final Verification

```bash
# Clean working tree
git status
# Expected: nothing to commit, working tree clean

# All tests pass
# In Godot: Tools → Gut → Run All Tests
# Expected: 100% passing

# Game runs
# In Godot: F5
# Expected: Game works perfectly
```

---

## Completion

**Phase 5 Complete!**

**All 5 phases of the MCP-First Architecture Refactor are now complete.**

### Summary

✅ **Phase 1:** Foundation established
✅ **Phase 2:** Code refactored
✅ **Phase 3:** Scenes reconstructed
✅ **Phase 4:** Cleanup and documentation
✅ **Phase 5:** Validation successful

### Project Status

🎉 **MCP-First Architecture Refactor: COMPLETE**

The utoland project is now:
- Clean, maintainable, and well-tested
- Following MCP-first development workflow
- Ready for future feature development
- Free of technical debt

---

**Congratulations! The refactor is complete.**
