class_name TerrainAutotiler
extends RefCounted

## 地形 autotile 辅助类
## 根据 MapLayout 中 cell 的邻居关系计算 8-bit bitmask，
## 通过查找表映射到 Pipoya RPG Tileset type3 (8x6) 的 atlas 坐标。

const N := 1
const NE := 2
const E := 4
const SE := 8
const S := 16
const SW := 32
const W := 64
const NW := 128

const _NEIGHBOR_OFFSETS: Array[Dictionary] = [
	{"offset": Vector2i(0, -1), "bit": N},
	{"offset": Vector2i(1, -1), "bit": NE},
	{"offset": Vector2i(1, 0), "bit": E},
	{"offset": Vector2i(1, 1), "bit": SE},
	{"offset": Vector2i(0, 1), "bit": S},
	{"offset": Vector2i(-1, 1), "bit": SW},
	{"offset": Vector2i(-1, 0), "bit": W},
	{"offset": Vector2i(-1, -1), "bit": NW},
]

## bitmask → type3 atlas 坐标 (47 条)
const BITMASK_TO_ATLAS: Dictionary = {
	# 左块: 仅边 (16 tiles)
	0: Vector2i(0, 0),
	4: Vector2i(1, 0),
	68: Vector2i(2, 0),
	64: Vector2i(3, 0),
	16: Vector2i(0, 1),
	20: Vector2i(1, 1),
	84: Vector2i(2, 1),
	80: Vector2i(3, 1),
	17: Vector2i(0, 2),
	21: Vector2i(1, 2),
	85: Vector2i(2, 2),
	81: Vector2i(3, 2),
	1: Vector2i(0, 3),
	5: Vector2i(1, 3),
	69: Vector2i(2, 3),
	65: Vector2i(3, 3),
	# 右块 rows 0-3 cols 4-6: 3边+角
	92: Vector2i(4, 0),
	124: Vector2i(5, 0),
	116: Vector2i(6, 0),
	113: Vector2i(4, 1),
	241: Vector2i(5, 1),
	209: Vector2i(6, 1),
	197: Vector2i(4, 2),
	199: Vector2i(5, 2),
	71: Vector2i(6, 2),
	23: Vector2i(4, 3),
	31: Vector2i(5, 3),
	29: Vector2i(6, 3),
	# col 7: 2邻边+角 / 全填充
	255: Vector2i(7, 0),
	28: Vector2i(7, 1),
	7: Vector2i(7, 2),
	112: Vector2i(7, 3),
	# rows 4-5: 4边+角变化 (base=85)
	253: Vector2i(0, 4),
	247: Vector2i(1, 4),
	223: Vector2i(2, 4),
	127: Vector2i(3, 4),
	245: Vector2i(4, 4),
	215: Vector2i(5, 4),
	95: Vector2i(6, 4),
	125: Vector2i(7, 4),
	213: Vector2i(0, 5),
	87: Vector2i(1, 5),
	93: Vector2i(2, 5),
	117: Vector2i(3, 5),
	221: Vector2i(4, 5),
	119: Vector2i(5, 5),
	193: Vector2i(6, 5),
}


static func get_atlas_coord(layout: MapLayout, pos: Vector2i, cell_type: int) -> Vector2i:
	var bitmask := compute_bitmask(layout, pos, cell_type)
	if BITMASK_TO_ATLAS.has(bitmask):
		return BITMASK_TO_ATLAS[bitmask]
	return Vector2i(0, 0)


static func compute_bitmask(layout: MapLayout, pos: Vector2i, cell_type: int) -> int:
	var mask := 0
	for neighbor in _NEIGHBOR_OFFSETS:
		var neighbor_pos: Vector2i = pos + neighbor["offset"]
		if layout.get_cell(neighbor_pos) == cell_type:
			mask |= neighbor["bit"] as int
	# Corner masking: 角位只在两个相邻边位都是同类型时才计入
	if not (mask & N and mask & E):
		mask &= ~NE
	if not (mask & E and mask & S):
		mask &= ~SE
	if not (mask & S and mask & W):
		mask &= ~SW
	if not (mask & W and mask & N):
		mask &= ~NW
	return mask
