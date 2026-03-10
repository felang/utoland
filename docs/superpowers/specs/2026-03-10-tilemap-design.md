# 地图系统设计：TileMapLayer

日期：2026-03-10

## 背景

当前地图系统仅有 `MapData` 资源和一张背景图路径，无任何图块内容。本设计引入 TileMapLayer 实现像素风格地图渲染，为后续障碍/碰撞扩展打下基础。

## 设计目标

- 像素图块风格地图（32×32 px/格）
- 装饰性为主，暂不涉及碰撞地形
- 每个地图独立场景，main.tscn 动态加载
- 后续可低成本扩展为有碰撞的障碍地形

## 架构

### 地图场景（每个地图独立）

```
scenes/levels/maps/
  forest.tscn
  desert.tscn
```

每个地图场景结构：
```
Node2D (map root)
  TileMapLayer (Layer 0 - 地面)   ← 基础地形，铺满整个地图
  TileMapLayer (Layer 1 - 装饰)   ← 树、石头等装饰物，无碰撞
```

### TileSet 配置

- **图块大小**：32×32 像素
- **地图尺寸**：1344×992 像素（42×31 格），与现有 MapBoundary 一致
- **tileset 素材**：从 itch.io 获取免费像素风素材

```
assets/tilesets/
  forest_tileset.png
  desert_tileset.png
```

每个地图对应一个在 Godot 编辑器中配置的 TileSet `.tres` 资源。

### MapData 变更

新增字段：

```gdscript
@export var map_scene: String = ""  # e.g. "res://scenes/levels/maps/forest.tscn"
```

现有 `background` 字段保留，继续用于地图选择界面预览图。

### main.gd 集成

```gdscript
func _ready() -> void:
    var map_data: MapData = GameConfig.maps[GameData.selected_map]
    var map_scene = load(map_data.map_scene).instantiate()
    add_child(map_scene)
    move_child(map_scene, 0)  # 确保地图渲染在最底层
```

## 不影响的系统

EnemySpawner、WaveManager、Player、HUD、EffectsManager、AudioManager 均无需修改。

## 后续扩展路径

当需要加碰撞障碍时：
1. 在 TileSet 中为对应图块添加 Physics Layer
2. 在 Layer 1（装饰层）或新建 Layer 2（障碍层）中绘制障碍图块
3. 无需改动任何游戏逻辑代码
