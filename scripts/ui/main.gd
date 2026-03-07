extends Node2D

func _ready() -> void:
	# 恢复布置的塔
	for tower_data: Dictionary in GameData.tower_inventory:
		var tower_type: String = tower_data["type"]
		var tower_pos: Vector2 = tower_data["position"]

		var tower: Node2D = SceneFactory.create_tower(tower_type)
		if tower:
			tower.global_position = tower_pos
			add_child(tower)

	# 不再清空 tower_inventory，保留已布置的塔数据供下次布置场景使用
