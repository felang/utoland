extends Node2D

func _ready():
	# 恢复布置的塔
	for tower_data in GameData.tower_inventory:
		var tower_type = tower_data["type"]
		var tower_pos = tower_data["position"]

		var tower_scene = null
		if tower_type == "shooter":
			tower_scene = preload("res://scenes/towers/tower_shooter.tscn")
		elif tower_type == "wall":
			tower_scene = preload("res://scenes/towers/tower_wall.tscn")
		elif tower_type == "slow":
			tower_scene = preload("res://scenes/towers/tower_slow.tscn")

		if tower_scene:
			var tower = tower_scene.instantiate()
			tower.global_position = tower_pos
			add_child(tower)

	# 不再清空 tower_inventory，保留已布置的塔数据供下次布置场景使用
