# Rule: Zero Hardcoded Values

## Principle
All game values must come from GameConfig.

## What Counts as Hardcoded

### ❌ Bad Examples
```gdscript
if coins < 30:  # Magic number
var tower_costs = {"shooter": 30}  # Duplicate data
var path = "res://scenes/towers/tower_shooter.tscn"  # String literal
```

### ✅ Good Examples
```gdscript
if coins < GameConfig.TOWERS["shooter"]["shop_price_min"]:
var cost = SceneFactory.get_tower_cost("shooter")
var tower = SceneFactory.create_tower("shooter")
```

## Why This Matters
- Single source of truth
- Easy to balance gameplay
- Config changes don't require code changes
- Prevents inconsistencies

## Verification
Run: `grep -r "[0-9]\{2,\}" scripts/` to find magic numbers
