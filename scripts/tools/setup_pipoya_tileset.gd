@tool
extends EditorScript
## 自动配置 Pipoya RPG Tileset type3 的 TileSet 资源
##
## 在 Godot 编辑器中运行：File → Run 或 Ctrl+Shift+X
## 输出：res://resources/maps/tilesets/pipoya_tileset.tres

# Godot 4.x MATCH_CORNERS_AND_SIDES 的 8 个 peering bit 索引
const RIGHT := 0        # CELL_NEIGHBOR_RIGHT_SIDE
const BOTTOM_RIGHT := 1 # CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
const BOTTOM := 2       # CELL_NEIGHBOR_BOTTOM_SIDE
const BOTTOM_LEFT := 3  # CELL_NEIGHBOR_BOTTOM_LEFT_CORNER
const LEFT := 4         # CELL_NEIGHBOR_LEFT_SIDE
const TOP_LEFT := 5     # CELL_NEIGHBOR_TOP_LEFT_CORNER
const TOP := 6          # CELL_NEIGHBOR_TOP_SIDE
const TOP_RIGHT := 7    # CELL_NEIGHBOR_TOP_RIGHT_CORNER

const ALL_BITS := [RIGHT, BOTTOM_RIGHT, BOTTOM, BOTTOM_LEFT, LEFT, TOP_LEFT, TOP, TOP_RIGHT]


func _run() -> void:
	print("=== 开始创建 Pipoya TileSet ===")

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)

	# --- Terrain Set 0: 3×3 bitmask ---
	tileset.add_terrain_set(0)
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)

	var terrain_names := ["Grass", "Water", "Wall", "Dirt"]
	var terrain_colors := [Color.GREEN, Color.BLUE, Color.GRAY, Color.SADDLE_BROWN]
	for i in range(4):
		tileset.add_terrain(0, i)
		tileset.set_terrain_name(0, i, terrain_names[i])
		tileset.set_terrain_color(0, i, terrain_colors[i])

	# --- Physics Layers ---
	# Layer 0: Solid (collision_layer=4 即第3层, mask=3 即第1+2层)
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 4)
	tileset.set_physics_layer_collision_mask(0, 3)
	# Layer 1: WallBlock (collision_layer=256 即第9层, mask=0)
	tileset.add_physics_layer(1)
	tileset.set_physics_layer_collision_layer(1, 256)
	tileset.set_physics_layer_collision_mask(1, 0)

	# --- Atlas Sources ---
	var paths := [
		"res://assets/tilesets/Pipoya RPG Tileset 32x32/[A]_type3/[A]Grass1_pipo.png",
		"res://assets/tilesets/Pipoya RPG Tileset 32x32/[A]_type3/[A]Water1_pipo.png",
		"res://assets/tilesets/Pipoya RPG Tileset 32x32/[A]_type3/[A]Wall-Up1_pipo.png",
		"res://assets/tilesets/Pipoya RPG Tileset 32x32/[A]_type3/[A]Dirt1_pipo.png",
	]
	# Grass 无碰撞，Water/Dirt 只有 Solid，Wall 有 Solid + WallBlock
	var has_solid := [false, true, true, true]
	var has_wallblock := [false, false, true, false]

	# type3 peering bit 映射表（见 _build_type3_peering_table）
	var peering_table := _build_type3_peering_table()

	for src_idx in range(4):
		var texture: Texture2D = load(paths[src_idx])
		if texture == null:
			push_error("无法加载纹理: " + paths[src_idx])
			continue

		var atlas := TileSetAtlasSource.new()
		atlas.texture = texture
		atlas.texture_region_size = Vector2i(32, 32)
		var source_id := tileset.add_source(atlas, src_idx)
		print("  添加 atlas source %d: %s (id=%d)" % [src_idx, terrain_names[src_idx], source_id])

		# 创建 8×6 的 tile 网格
		for row in range(6):
			for col in range(8):
				var coords := Vector2i(col, row)
				atlas.create_tile(coords)
				var td := atlas.get_tile_data(coords, 0)

				# 设置 terrain
				td.terrain_set = 0
				td.terrain = src_idx

				# 设置 peering bits
				var key := Vector2i(col, row)
				if peering_table.has(key):
					var same_bits: Array = peering_table[key]
					for bit in ALL_BITS:
						if same_bits.has(bit):
							td.set_terrain_peering_bit(bit, src_idx)
						else:
							td.set_terrain_peering_bit(bit, -1)
				else:
					# 未映射的 tile 默认全部设为当前 terrain
					for bit in ALL_BITS:
						td.set_terrain_peering_bit(bit, src_idx)

				# 物理碰撞
				if has_solid[src_idx]:
					var poly := PackedVector2Array([
						Vector2(-16, -16), Vector2(16, -16),
						Vector2(16, 16), Vector2(-16, 16),
					])
					td.add_collision_polygon(0)
					td.set_collision_polygon_points(0, 0, poly)

				if has_wallblock[src_idx]:
					var poly := PackedVector2Array([
						Vector2(-16, -16), Vector2(16, -16),
						Vector2(16, 16), Vector2(-16, 16),
					])
					td.add_collision_polygon(1)
					td.set_collision_polygon_points(1, 0, poly)

	# --- 保存 ---
	var save_path := "res://resources/maps/tilesets/pipoya_tileset.tres"
	var err := ResourceSaver.save(tileset, save_path)
	if err == OK:
		print("=== TileSet 已保存: %s ===" % save_path)
	else:
		push_error("保存失败: %s (错误码: %d)" % [save_path, err])


## 构建 type3 8×6 layout 的 peering bit 映射表
## 返回 Dictionary[Vector2i, Array[int]]
## key = Vector2i(col, row), value = 该 tile 中与当前 terrain 相同的方向 bit 列表
##
## Pipoya type3 (RPG Maker A2) 标准布局：
## 每个 tile 表示特定的邻居组合，terrain 覆盖的方向设为 terrain_id，其余为 -1
func _build_type3_peering_table() -> Dictionary:
	var t := {}

	# === Row 0: 顶部边缘行（上方无 terrain） ===
	# (0,0): 孤立 tile，四周无同类 terrain
	t[Vector2i(0, 0)] = []
	# (1,0): 仅下方有 terrain
	t[Vector2i(1, 0)] = [BOTTOM]
	# (2,0): 仅右方有 terrain
	t[Vector2i(2, 0)] = [RIGHT]
	# (3,0): 右 + 右下 + 下
	t[Vector2i(3, 0)] = [RIGHT, BOTTOM_RIGHT, BOTTOM]
	# (4,0): 下方一整排 = 左 + 左下 + 下 + 右下 + 右（上方无）
	t[Vector2i(4, 0)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, BOTTOM_LEFT, LEFT]
	# (5,0): 仅左 + 下
	t[Vector2i(5, 0)] = [BOTTOM, LEFT]
	# (6,0): 左 + 左下 + 下
	t[Vector2i(6, 0)] = [BOTTOM, BOTTOM_LEFT, LEFT]
	# (7,0): 左 + 下 + 右（无角）
	t[Vector2i(7, 0)] = [RIGHT, BOTTOM, LEFT]

	# === Row 1: 中间行 ===
	# (0,1): 仅上方有 terrain
	t[Vector2i(0, 1)] = [TOP]
	# (1,1): 上 + 下（竖条）
	t[Vector2i(1, 1)] = [BOTTOM, TOP]
	# (2,1): 上 + 右
	t[Vector2i(2, 1)] = [RIGHT, TOP]
	# (3,1): 右 + 右下 + 下 + 上 + 右上
	t[Vector2i(3, 1)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, TOP, TOP_RIGHT]
	# (4,1): 全部 8 个方向（完全被同类包围的中心 tile）
	t[Vector2i(4, 1)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, BOTTOM_LEFT, LEFT, TOP_LEFT, TOP, TOP_RIGHT]
	# (5,1): 左 + 上 + 下
	t[Vector2i(5, 1)] = [BOTTOM, LEFT, TOP]
	# (6,1): 左 + 左下 + 下 + 上 + 左上
	t[Vector2i(6, 1)] = [BOTTOM, BOTTOM_LEFT, LEFT, TOP_LEFT, TOP]
	# (7,1): 右 + 下 + 左 + 上（四边但无角）
	t[Vector2i(7, 1)] = [RIGHT, BOTTOM, LEFT, TOP]

	# === Row 2: 底部边缘行 + 内角 ===
	# (0,2): 左上内角 = 左 + 左上 + 上
	t[Vector2i(0, 2)] = [LEFT, TOP_LEFT, TOP]
	# (1,2): 右上内角 = 上 + 右上 + 右
	t[Vector2i(1, 2)] = [RIGHT, TOP, TOP_RIGHT]
	# (2,2): 右列（右 + 右上 + 上 + 下 + 右下）
	t[Vector2i(2, 2)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, TOP, TOP_RIGHT]
	# (3,2): 左列（左 + 左上 + 上 + 下 + 左下）
	t[Vector2i(3, 2)] = [BOTTOM, BOTTOM_LEFT, LEFT, TOP_LEFT, TOP]
	# (4,2): 竖条（上 + 下）
	t[Vector2i(4, 2)] = [BOTTOM, TOP]
	# (5,2): 横条（左 + 右）
	t[Vector2i(5, 2)] = [RIGHT, LEFT]
	# (6,2): 上一排全有 = 左上 + 上 + 右上 + 左 + 右（下方无）
	t[Vector2i(6, 2)] = [RIGHT, LEFT, TOP_LEFT, TOP, TOP_RIGHT]
	# (7,2): 下一排全有 = 左 + 左下 + 下 + 右下 + 右（上方无）
	t[Vector2i(7, 2)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, BOTTOM_LEFT, LEFT]

	# === Row 3: 内角组合 ===
	# (0,3): 左下内角 = 左 + 左下 + 下 (+ 上 + 右 已有的 → 实际是缺右下角)
	# 内角 tile 意味着"几乎全覆盖，只缺一个角"
	# 内角左上 = 全覆盖但缺左上角
	t[Vector2i(0, 3)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, BOTTOM_LEFT, LEFT, TOP, TOP_RIGHT]
	# (1,3): 内角右上 = 全覆盖但缺右上角
	t[Vector2i(1, 3)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, BOTTOM_LEFT, LEFT, TOP_LEFT, TOP]
	# (2,3): 上 + 右上 + 右 + 左 + 左上（下方无）— T 形上
	t[Vector2i(2, 3)] = [RIGHT, LEFT, TOP_LEFT, TOP, TOP_RIGHT]
	# (3,3): 右 + 右下 + 下 + 左 + 左下（上方无）— T 形下
	t[Vector2i(3, 3)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, BOTTOM_LEFT, LEFT]
	# (4,3): 全覆盖但缺左上和右下两个角
	t[Vector2i(4, 3)] = [RIGHT, BOTTOM, BOTTOM_LEFT, LEFT, TOP, TOP_RIGHT]
	# (5,3): 全覆盖但缺右上和左下两个角
	t[Vector2i(5, 3)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, LEFT, TOP_LEFT, TOP]
	# (6,3): 内角左下 = 全覆盖但缺左下角
	t[Vector2i(6, 3)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, LEFT, TOP_LEFT, TOP, TOP_RIGHT]
	# (7,3): 内角右下 = 全覆盖但缺右下角
	t[Vector2i(7, 3)] = [RIGHT, BOTTOM, BOTTOM_LEFT, LEFT, TOP_LEFT, TOP, TOP_RIGHT]

	# === Row 4: 边缘 + 内角组合 ===
	# (0,4): 上边缘 + 缺左下角 = 右 + 右下 + 下 + 左 + 左下 但无左下
	t[Vector2i(0, 4)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, LEFT]
	# (1,4): 上边缘 + 缺右下角
	t[Vector2i(1, 4)] = [RIGHT, BOTTOM, BOTTOM_LEFT, LEFT]
	# (2,4): 左边缘 + 缺右上角 = 右 + 下 + 右下 + 上 但无右上
	t[Vector2i(2, 4)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, TOP]
	# (3,4): 左边缘 + 缺右下角
	t[Vector2i(3, 4)] = [RIGHT, BOTTOM, TOP, TOP_RIGHT]
	# (4,4): 下边缘 + 缺左上角
	t[Vector2i(4, 4)] = [RIGHT, LEFT, TOP, TOP_RIGHT]
	# (5,4): 下边缘 + 缺右上角
	t[Vector2i(5, 4)] = [RIGHT, LEFT, TOP_LEFT, TOP]
	# (6,4): 右边缘 + 缺左上角 = 左 + 下 + 左下 + 上 但无左上
	t[Vector2i(6, 4)] = [BOTTOM, BOTTOM_LEFT, LEFT, TOP]
	# (7,4): 右边缘 + 缺左下角
	t[Vector2i(7, 4)] = [BOTTOM, LEFT, TOP_LEFT, TOP]

	# === Row 5: 双内角组合 ===
	# (0,5): 全覆盖但缺左下 + 右下
	t[Vector2i(0, 5)] = [RIGHT, BOTTOM, LEFT, TOP_LEFT, TOP, TOP_RIGHT]
	# (1,5): 全覆盖但缺左上 + 左下
	t[Vector2i(1, 5)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, LEFT, TOP, TOP_RIGHT]
	# (2,5): 全覆盖但缺右上 + 右下
	t[Vector2i(2, 5)] = [RIGHT, BOTTOM, BOTTOM_LEFT, LEFT, TOP_LEFT, TOP]
	# (3,5): 全覆盖但缺左上 + 左下 + 右上（三角缺失）
	t[Vector2i(3, 5)] = [RIGHT, BOTTOM_RIGHT, BOTTOM, LEFT, TOP]
	# (4,5): 全覆盖但缺左上 + 右上 + 右下
	t[Vector2i(4, 5)] = [RIGHT, BOTTOM, BOTTOM_LEFT, LEFT, TOP]
	# (5,5): 全覆盖但缺左上 + 左下 + 右下
	t[Vector2i(5, 5)] = [RIGHT, BOTTOM, LEFT, TOP, TOP_RIGHT]
	# (6,5): 全覆盖但缺右上 + 左下 + 右下
	t[Vector2i(6, 5)] = [RIGHT, BOTTOM, LEFT, TOP_LEFT, TOP]
	# (7,5): 全覆盖但缺全部四角
	t[Vector2i(7, 5)] = [RIGHT, BOTTOM, LEFT, TOP]

	return t
