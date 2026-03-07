extends Control

@onready var forest_button: Button = $VBoxContainer/MapCardsContainer/ForestCard/ForestButton
@onready var desert_button: Button = $VBoxContainer/MapCardsContainer/DesertCard/DesertButton

func _ready() -> void:
	# 验证节点存在
	if not forest_button or not desert_button:
		push_error("地图选择按钮未找到")
		return

	# 连接按钮信号
	forest_button.pressed.connect(_on_map_selected.bind("forest"))
	desert_button.pressed.connect(_on_map_selected.bind("desert"))

	# 验证地图配置
	if not GameConfig.maps.has("forest") or not GameConfig.maps.has("desert"):
		push_error("地图配置缺失")

func _on_map_selected(map_id: String) -> void:
	# 验证地图 ID
	if not GameConfig.maps.has(map_id):
		push_error("未知地图: " + map_id)
		return

	# 保存选择
	GameData.selected_map = map_id
	var md: MapData = GameConfig.maps[map_id]
	print("选择地图: ", md.display_name)

	# 跳转到塔布置场景
	SceneManager.go_to("placement")
