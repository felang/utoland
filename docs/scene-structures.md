# Scene Structures Documentation

This document records the current scene structures before MCP-First Architecture reconstruction.

**Date**: 2026-03-05
**Purpose**: Reference for Phase 3 scene reconstruction using MCP tools

---

## Tower Scenes

### tower_shooter.tscn

**Location**: `res://scenes/towers/tower_shooter.tscn`
**UID**: `uid://r200n4ikcpv2`
**Script**: `res://scripts/entities/towers/tower_shooter.gd` (uid://ckwxfmslcyshb)

```
Root: TowerShooter (StaticBody2D) [unique_id: 1629987127]
├── Visual (ColorRect) [unique_id: 1512730339]
├── CollisionShape2D [unique_id: 203969423]
├── DetectArea (Area2D)
│   └── CollisionShape2D
└── ShootTimer (Timer)
```

**Properties**:
- **Root Node**:
  - collision_layer: 3
  - collision_mask: 2

- **Visual (ColorRect)**:
  - offset_left: -16.0
  - offset_top: -16.0
  - offset_right: 16.0
  - offset_bottom: 16.0
  - color: Color(0.2, 0.8, 0.2, 1) [green]

- **CollisionShape2D**:
  - shape: RectangleShape2D (32x32)

- **DetectArea (Area2D)**:
  - collision_layer: 0
  - collision_mask: 2
  - CollisionShape2D shape: CircleShape2D (radius: 300.0)

- **ShootTimer (Timer)**:
  - wait_time: 1.0
  - one_shot: false
  - autostart: false

---

### tower_wall.tscn

**Location**: `res://scenes/towers/tower_wall.tscn`
**UID**: `uid://b5760tlktfkgu`
**Script**: `res://scripts/entities/towers/tower.gd` (uid://c787bqtynkfr0)

```
Root: TowerWall (StaticBody2D) [unique_id: 655985224]
├── Visual (ColorRect) [unique_id: 1199573255]
└── CollisionShape2D [unique_id: 1871816359]
```

**Properties**:
- **Root Node**:
  - collision_layer: 3
  - collision_mask: 2

- **Visual (ColorRect)**:
  - offset_left: -24.0
  - offset_top: -24.0
  - offset_right: 24.0
  - offset_bottom: 24.0
  - color: Color(0.6, 0.4, 0.2, 1) [brown]

- **CollisionShape2D**:
  - shape: RectangleShape2D (48x48)

---

### tower_slow.tscn

**Location**: `res://scenes/towers/tower_slow.tscn`
**UID**: `uid://ucsglghc6mnm`
**Script**: `res://scripts/entities/towers/tower_slow.gd` (uid://numv2t5y702l)

```
Root: TowerSlow (StaticBody2D) [unique_id: 1886032181]
├── Visual (ColorRect) [unique_id: 1884607702]
├── CollisionShape2D [unique_id: 1321429890]
└── SlowArea (Area2D)
    └── CollisionShape2D
```

**Properties**:
- **Root Node**:
  - collision_layer: 3
  - collision_mask: 2

- **Visual (ColorRect)**:
  - offset_left: -16.0
  - offset_top: -16.0
  - offset_right: 16.0
  - offset_bottom: 16.0
  - color: Color(0.2, 0.8, 0.8, 1) [cyan]

- **CollisionShape2D**:
  - shape: RectangleShape2D (32x32)

- **SlowArea (Area2D)**:
  - collision_layer: 0
  - collision_mask: 2
  - CollisionShape2D shape: CircleShape2D (radius: 200.0)

---

## Enemy Scenes

### enemy_normal.tscn

**Location**: `res://scenes/enemies/enemy_normal.tscn`
**UID**: `uid://5iglv6nvabcq`
**Script**: `res://scripts/entities/enemy.gd` (uid://b1ohisgqjft26)

```
Root: EnemyNormal (CharacterBody2D) [unique_id: 1365841566]
├── Visual (ColorRect) [unique_id: 274199104]
└── CollisionShape2D [unique_id: 404462319]
```

**Properties**:
- **Root Node**:
  - collision_layer: 2
  - collision_mask: 5
  - (Uses default script properties)

- **Visual (ColorRect)**:
  - offset_left: -16.0
  - offset_top: -16.0
  - offset_right: 16.0
  - offset_bottom: 16.0
  - color: Color(1, 0, 0, 1) [red]

- **CollisionShape2D**:
  - shape: RectangleShape2D (32x32)

---

### enemy_fast.tscn

**Location**: `res://scenes/enemies/enemy_fast.tscn`
**UID**: `uid://bxlj77kpxroab`
**Script**: `res://scripts/entities/enemy.gd` (uid://b1ohisgqjft26)

```
Root: EnemyFast (CharacterBody2D) [unique_id: 1365841566]
├── Visual (ColorRect) [unique_id: 274199104]
└── CollisionShape2D [unique_id: 404462319]
```

**Properties**:
- **Root Node**:
  - collision_layer: 2
  - collision_mask: 5
  - speed: 250.0
  - max_hp: 20.0
  - touch_damage: 8.0

- **Visual (ColorRect)**:
  - offset_left: -16.0
  - offset_top: -16.0
  - offset_right: 16.0
  - offset_bottom: 16.0
  - color: Color(0, 0, 1, 1) [blue]

- **CollisionShape2D**:
  - shape: RectangleShape2D (32x32)

---

### enemy_tank.tscn

**Location**: `res://scenes/enemies/enemy_tank.tscn`
**UID**: `uid://c1natg0slsxfx`
**Script**: `res://scripts/entities/enemy.gd` (uid://b1ohisgqjft26)

```
Root: EnemyTank (CharacterBody2D) [unique_id: 1365841566]
├── Visual (ColorRect) [unique_id: 274199104]
└── CollisionShape2D [unique_id: 404462319]
```

**Properties**:
- **Root Node**:
  - collision_layer: 2
  - collision_mask: 5
  - speed: 100.0
  - max_hp: 150.0
  - touch_damage: 15.0

- **Visual (ColorRect)**:
  - offset_left: -24.0
  - offset_top: -24.0
  - offset_right: 24.0
  - offset_bottom: 24.0
  - color: Color(0.5, 0, 0.5, 1) [purple]

- **CollisionShape2D**:
  - shape: RectangleShape2D (48x48)

---

## Key Observations

### Collision Layers
- **Layer 1 (bit 0)**: Player/Bullets
- **Layer 2 (bit 1)**: Enemies
- **Layer 3 (bit 0+1)**: Towers

### Common Patterns

**Towers**:
- All use StaticBody2D as root
- All have Visual (ColorRect) + CollisionShape2D
- Shooter and Slow towers have additional Area2D for detection/effect range
- Shooter tower has Timer node for shooting intervals

**Enemies**:
- All use CharacterBody2D as root
- All share the same script (enemy.gd)
- All have Visual (ColorRect) + CollisionShape2D
- Differentiated by exported properties (speed, max_hp, touch_damage)
- Visual colors: Normal=red, Fast=blue, Tank=purple

### Unique IDs
All nodes have unique_id attributes for internal Godot references. These will need to be regenerated when reconstructing scenes via MCP tools.

---

## Reconstruction Notes

When rebuilding these scenes with MCP tools:

1. **Create root node** with correct type (StaticBody2D or CharacterBody2D)
2. **Set collision layers/masks** before adding children
3. **Add Visual node** (ColorRect) with proper offsets and colors
4. **Add CollisionShape2D** with appropriate shape and size
5. **Add special nodes** (Area2D, Timer) for specific tower types
6. **Attach scripts** after node structure is complete
7. **Set exported properties** for enemy variants

The unique_id values will be auto-generated and will differ from originals.
