extends Node2D

# 美术资源测试场景
# 用于快速预览和测试美术资源

func _ready():
	print("=== 美术资源测试场景 ===")
	print("按键说明:")
	print("1 - 测试玩家精灵")
	print("2 - 测试敌人精灵")
	print("3 - 测试植物塔精灵")
	print("4 - 测试地图瓦片")
	print("ESC - 退出")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				test_player_sprite()
			KEY_2:
				test_enemy_sprites()
			KEY_3:
				test_tower_sprites()
			KEY_4:
				test_tilemap()
			KEY_ESCAPE:
				get_tree().quit()

func test_player_sprite():
	print("测试玩家精灵...")
	# TODO: 加载并显示玩家精灵
	var sprite = Sprite2D.new()
	# sprite.texture = load("res://assets/sprites/player/player_idle.png")
	sprite.position = Vector2(400, 300)
	add_child(sprite)

func test_enemy_sprites():
	print("测试敌人精灵...")
	# TODO: 加载并显示各类敌人

func test_tower_sprites():
	print("测试植物塔精灵...")
	# TODO: 加载并显示各类植物塔

func test_tilemap():
	print("测试地图瓦片...")
	# TODO: 创建 TileMap 并铺设瓦片
