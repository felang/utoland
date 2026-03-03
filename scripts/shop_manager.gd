extends Control

const REFRESH_COST = 10

var shop_items = []
var passive_upgrades = [
	{"name": "最大生命值+20", "cost": 20, "stat": "max_hp", "value": 20},
	{"name": "生命回复+5/5秒", "cost": 15, "stat": "hp_regen", "value": 5},
	{"name": "伤害+10%", "cost": 25, "stat": "damage_mult", "value": 0.1},
	{"name": "攻击速度+15%", "cost": 20, "stat": "attack_speed_mult", "value": 0.15},
	{"name": "移动速度+10%", "cost": 15, "stat": "move_speed_mult", "value": 0.1},
	{"name": "工程学+20%", "cost": 30, "stat": "tower_mult", "value": 0.2}
]
var tower_items = [
	{"name": "豌豆射手", "cost": 25, "type": "shooter"},
	{"name": "坚果墙", "cost": 30, "type": "wall"},
	{"name": "冰雪菇", "cost": 28, "type": "slow"}
]
var consumables = [
	{"name": "医疗包", "cost": 12, "effect": "heal", "value": 50}
]

@onready var coin_label = $VBoxContainer/CoinLabel
@onready var refresh_button = $VBoxContainer/ButtonsContainer/RefreshButton
@onready var confirm_button = $VBoxContainer/ButtonsContainer/ConfirmButton
@onready var item_containers = [
	$VBoxContainer/ItemsContainer/Item1,
	$VBoxContainer/ItemsContainer/Item2,
	$VBoxContainer/ItemsContainer/Item3,
	$VBoxContainer/ItemsContainer/Item4
]

func _ready():
	refresh_button.pressed.connect(on_refresh_pressed)
	confirm_button.pressed.connect(on_confirm_pressed)
	
	# 连接购买按钮
	for i in range(4):
		var buy_button = item_containers[i].get_node("BuyButton" if i == 0 else "BuyButton2")
		buy_button.pressed.connect(buy_item.bind(i))
	
	refresh_shop()
	update_ui()

func refresh_shop():
	shop_items = []
	for i in range(4):
		var rand = randf()
		if rand < 0.6:  # 60% 被动属性
			shop_items.append(passive_upgrades.pick_random())
		elif rand < 0.9:  # 30% 植物塔
			shop_items.append(tower_items.pick_random())
		else:  # 10% 消耗品
			shop_items.append(consumables.pick_random())
	
	display_items()

func display_items():
	for i in range(4):
		var item = shop_items[i]
		var name_label = item_containers[i].get_node("NameLabel" if i == 0 else "NameLabel2")
		var price_label = item_containers[i].get_node("PriceLabel" if i == 0 else "PriceLabel2")
		var buy_button = item_containers[i].get_node("BuyButton" if i == 0 else "BuyButton2")
		
		name_label.text = item["name"]
		price_label.text = "价格: %d" % item["cost"]
		buy_button.disabled = GameData.coins < item["cost"]

func buy_item(index: int):
	var item = shop_items[index]
	if GameData.coins < item["cost"]:
		return
	
	GameData.coins -= item["cost"]
	
	if item.has("stat"):  # 被动属性
		if item["stat"].ends_with("_mult"):
			GameData.player_stats[item["stat"]] += item["value"]
		else:
			GameData.player_stats[item["stat"]] += item["value"]
	elif item.has("type"):  # 植物塔
		GameData.purchased_towers.append(item["type"])
	elif item.has("effect"):  # 消耗品
		apply_consumable(item)
	
	update_ui()

func apply_consumable(item):
	if item["effect"] == "heal":
		GameData.pending_heal += item["value"]

func on_refresh_pressed():
	if GameData.coins < REFRESH_COST:
		return
	GameData.coins -= REFRESH_COST
	refresh_shop()
	update_ui()

func on_confirm_pressed():
	get_tree().change_scene_to_file("res://scenes/placement.tscn")

func start_next_wave():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func update_ui():
	coin_label.text = "金币: %d" % GameData.coins
	refresh_button.disabled = GameData.coins < REFRESH_COST
	display_items()
