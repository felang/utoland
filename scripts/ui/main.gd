extends Node2D

func _ready() -> void:
	# 塔防阶段暂时跳过（后续版本恢复）
	# for tower_data: Dictionary in GameData.tower_inventory:
	# 	var tower_type: String = tower_data["type"]
	# 	var tower_pos: Vector2 = tower_data["position"]
	# 	var tower: Node2D = SceneFactory.create_tower(tower_type)
	# 	if tower:
	# 		tower.global_position = tower_pos
	# 		add_child(tower)
	pass
