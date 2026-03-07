extends Control

var shop_items: Array[Dictionary] = []
var passive_upgrades: Array[Dictionary] = [
	{"name": "最大生命值+20%", "stat": "hp_mult", "value": 0.2},
	{"name": "生命回复+5/5秒", "stat": "hp_regen", "value": 5},
	{"name": "伤害+10%", "stat": "damage_mult", "value": 0.1},
	{"name": "攻击速度+15%", "stat": "attack_speed_mult", "value": 0.15},
	{"name": "移动速度+10%", "stat": "move_speed_mult", "value": 0.1},
	{"name": "工程学+20%", "stat": "tower_mult", "value": 0.2}
]
var tower_types: Array[String] = ["shooter", "wall", "slow"]

@onready var coin_label = $VBoxContainer/CoinLabel
@onready var refresh_button = $VBoxContainer/ButtonsContainer/RefreshButton
@onready var confirm_button = $VBoxContainer/ButtonsContainer/ConfirmButton
@onready var item_containers = [
	$VBoxContainer/ItemsContainer/Item1,
	$VBoxContainer/ItemsContainer/Item2,
	$VBoxContainer/ItemsContainer/Item3,
	$VBoxContainer/ItemsContainer/Item4
]

func _ready() -> void:
	refresh_button.pressed.connect(on_refresh_pressed)
	confirm_button.pressed.connect(on_confirm_pressed)
	
	# 连接购买按钮
	for i in range(4):
		var buy_button = item_containers[i].get_node("BuyButton" if i == 0 else "BuyButton2")
		buy_button.pressed.connect(buy_item.bind(i))
	
	refresh_shop()
	update_ui()

func refresh_shop() -> void:
	shop_items = []
	for i in range(4):
		var rand = randf()
		if rand < 0.6:  # 60% 被动属性
			var passive = passive_upgrades.pick_random().duplicate()
			passive["cost"] = randi_range(
				GameConfig.shop.passive_price_min,
				GameConfig.shop.passive_price_max
			)
			shop_items.append(passive)
		elif rand < 0.9:  # 30% 植物塔
			var tower_type = tower_types.pick_random()
			var td: TowerData = GameConfig.towers[tower_type]
			var tower_item = {
				"name": td.display_name,
				"type": tower_type,
				"cost": randi_range(td.shop_price_min, td.shop_price_max)
			}
			shop_items.append(tower_item)
		else:  # 10% 消耗品
			var consumable = {
				"name": "医疗包",
				"effect": "heal",
				"value": GameConfig.shop.heal_amount,
				"cost": GameConfig.shop.heal_price
			}
			shop_items.append(consumable)

	display_items()

func display_items() -> void:
	for i in range(4):
		var item = shop_items[i]
		var name_label = item_containers[i].get_node("NameLabel" if i == 0 else "NameLabel2")
		var price_label = item_containers[i].get_node("PriceLabel" if i == 0 else "PriceLabel2")
		var buy_button = item_containers[i].get_node("BuyButton" if i == 0 else "BuyButton2")
		
		name_label.text = item["name"]
		price_label.text = "价格: %d" % item["cost"]
		buy_button.disabled = GameData.coins < item["cost"]

func buy_item(index: int) -> void:
	var item: Dictionary = shop_items[index]
	if GameData.coins < item["cost"]:
		return

	GameData.coins -= item["cost"]

	if item.has("stat"):  # 被动属性升级
		GameData.player_stats[item["stat"]] += item["value"]
	elif item.has("type"):  # 植物塔
		GameData.purchased_towers.append(item["type"])
	elif item.has("effect"):  # 消耗品
		apply_consumable(item)

	update_ui()

func apply_consumable(item: Dictionary) -> void:
	if item["effect"] == "heal":
		GameData.pending_heal += item["value"]

func on_refresh_pressed() -> void:
	if GameData.coins < GameConfig.shop.refresh_cost:
		return
	GameData.coins -= GameConfig.shop.refresh_cost
	refresh_shop()
	update_ui()

func on_confirm_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/placement.tscn")

func start_next_wave() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")

func update_ui() -> void:
	coin_label.text = "金币: %d" % GameData.coins
	refresh_button.disabled = GameData.coins < GameConfig.shop.refresh_cost
	display_items()
