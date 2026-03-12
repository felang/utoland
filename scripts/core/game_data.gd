extends Node

# 角色系统
var current_character: String = Enums.Character.DORA  # 当前选择的角色
var character_max_hp: float = 0.0
var character_speed: float = 0.0
var character_damage_mult: float = 1.0
var character_attack_speed_mult: float = 1.0
var character_move_speed_mult: float = 1.0
var character_hp_regen: float = 0.0

var selected_weapon: String = Enums.WeaponId.RIFLE
var selected_map: String = Enums.Map.FOREST  # 当前选择的地图，默认森林
var player_stats: Dictionary = {
	Enums.Stat.MAX_HP: 100.0,
	Enums.Stat.HP_MULT: 1.0,
	Enums.Stat.HP_REGEN: 0.0,
	Enums.Stat.DAMAGE_MULT: 1.0,
	Enums.Stat.ATTACK_SPEED_MULT: 1.0,
	Enums.Stat.MOVE_SPEED_MULT: 1.0,
	Enums.Stat.TOWER_MULT: 1.0
}
var coins: int = GameConfig.PLAYER["initial_coins"]
var current_wave: int = 0
var tower_inventory: Array = []  # 已布置的塔 {type, position}
var purchased_towers: Array = []  # 商店购买的塔类型（字符串数组）
var pending_heal: int = 0  # 待应用的治疗量

## 本局已购买的物品 id → 购买次数
var purchased_items: Dictionary = {}
## 本局可用的金矿加成（每波额外金币）
var wave_gold_bonus: int = 0
## 穿甲弹穿透数（0 = 不穿透）
var pierce_count: int = 0
## 弹幕激活（true = 3发）及伤害倍率
var multishot_active: bool = false
var multishot_damage_mult: float = 1.0
## 吸血比例（0.0 = 未激活）
var lifesteal_ratio: float = 0.0
## 蓄力当前层数
var kill_stack_count: int = 0
var kill_stack_max: int = 0
var kill_stack_damage_per_stack: float = 0.0
## 联动系统：每塔玩家伤害加成
var tower_link_damage_per_tower: float = 0.0
## 战场维修：每波塔HP回复比例
var wave_tower_heal_ratio: float = 0.0
## 纳米修复已激活
var tower_regen_active: bool = false
var tower_regen_hp: float = 0.0
var tower_regen_interval: float = 5.0
## 共生：低血量塔伤害加成
var symbiosis_hp_threshold: float = 0.0
var symbiosis_tower_bonus: float = 0.0
## 战争机器激活
var war_machine_active: bool = false
var war_machine_wave_hp_cost: int = 0
## 额外塔属性倍率
var tower_hp_mult: float = 1.0
var tower_range_mult: float = 1.0
var tower_attack_speed_mult: float = 1.0
var tower_cost_mult: float = 1.0
## 弹速倍率（1.0 = 不变）
var bullet_speed_mult: float = 1.0
## 武器射程倍率
var weapon_range_mult: float = 1.0
## 暴击率（0.0-1.0）
var crit_chance: float = 0.0
## 暴击伤害倍率
var crit_damage_mult: float = 2.0
## 弹道分裂数（0 = 不分裂）
var split_count: int = 0
## 分裂弹伤害倍率
var split_damage_mult: float = 0.5
## 每波护盾层数（每波开始重置）
var wave_shield_count: int = 0
## 当前护盾层数
var current_shield: int = 0
## 每波回血比例（最大HP的百分比）
var wave_heal_ratio: float = 0.0
## 减伤比例（0.0-1.0）
var damage_reduction: float = 0.0
## 闪避率（0.0-1.0）
var dodge_chance: float = 0.0
## 金币磁铁范围倍率
var coin_magnet_mult: float = 1.0
## 减速光环
var slow_aura_active: bool = false
var slow_aura_ratio: float = 0.0
var slow_aura_range: float = 100.0
## 自动冲刺
var auto_dash_active: bool = false
var auto_dash_interval: float = 10.0
var auto_dash_distance: float = 80.0

## ===== 本局统计 =====
var total_kills: int = 0
var total_coins_earned: int = 0
var total_damage_taken: float = 0.0
var max_kill_streak: int = 0
var current_kill_streak: int = 0
var purchased_item_list: Array[String] = []

## reset() 的唯一真值源 — 所有需要重置的字段及其默认值
const _DEFAULTS: Dictionary = {
	"current_wave": 0,
	"tower_inventory": [],
	"purchased_towers": [],
	"pending_heal": 0,
	"purchased_items": {},
	"wave_gold_bonus": 0,
	"pierce_count": 0,
	"multishot_active": false,
	"multishot_damage_mult": 1.0,
	"lifesteal_ratio": 0.0,
	"kill_stack_count": 0,
	"kill_stack_max": 0,
	"kill_stack_damage_per_stack": 0.0,
	"tower_link_damage_per_tower": 0.0,
	"wave_tower_heal_ratio": 0.0,
	"tower_regen_active": false,
	"tower_regen_hp": 0.0,
	"tower_regen_interval": 5.0,
	"symbiosis_hp_threshold": 0.0,
	"symbiosis_tower_bonus": 0.0,
	"war_machine_active": false,
	"war_machine_wave_hp_cost": 0,
	"tower_hp_mult": 1.0,
	"tower_range_mult": 1.0,
	"tower_attack_speed_mult": 1.0,
	"tower_cost_mult": 1.0,
	"bullet_speed_mult": 1.0,
	"weapon_range_mult": 1.0,
	"crit_chance": 0.0,
	"crit_damage_mult": 2.0,
	"split_count": 0,
	"split_damage_mult": 0.5,
	"wave_shield_count": 0,
	"current_shield": 0,
	"wave_heal_ratio": 0.0,
	"damage_reduction": 0.0,
	"dodge_chance": 0.0,
	"coin_magnet_mult": 1.0,
	"slow_aura_active": false,
	"slow_aura_ratio": 0.0,
	"slow_aura_range": 100.0,
	"auto_dash_active": false,
	"auto_dash_interval": 10.0,
	"auto_dash_distance": 80.0,
	"total_kills": 0,
	"total_coins_earned": 0,
	"total_damage_taken": 0.0,
	"max_kill_streak": 0,
	"current_kill_streak": 0,
}

func _ready() -> void:
	# 游戏启动时初始化默认角色
	init_character(current_character)

# 初始化角色属性
func init_character(character_id: String) -> void:
	if not GameConfig.characters.has(character_id):
		push_error("未知角色: " + character_id)
		character_id = Enums.Character.DORA  # 回退到默认角色

	current_character = character_id
	var char_data: CharacterData = GameConfig.characters[character_id]

	character_max_hp = char_data.max_hp
	character_speed = char_data.speed
	character_damage_mult = char_data.damage_mult
	character_attack_speed_mult = char_data.attack_speed_mult
	character_move_speed_mult = char_data.move_speed_mult
	character_hp_regen = char_data.hp_regen

	print("角色初始化: ", char_data.display_name, " (", character_id, ")")

func reset() -> void:
	# 初始化角色（使用当前选择的角色）
	init_character(current_character)

	# 从角色配置读取默认武器
	var char_data: CharacterData = GameConfig.characters[current_character]
	selected_weapon = char_data.default_weapon
	selected_map = Enums.Map.FOREST
	# 将角色属性同步到 player_stats
	player_stats = {
		Enums.Stat.MAX_HP: character_max_hp,
		Enums.Stat.HP_MULT: 1.0,
		Enums.Stat.HP_REGEN: character_hp_regen,
		Enums.Stat.DAMAGE_MULT: character_damage_mult,
		Enums.Stat.ATTACK_SPEED_MULT: character_attack_speed_mult,
		Enums.Stat.MOVE_SPEED_MULT: character_move_speed_mult,
		Enums.Stat.TOWER_MULT: 1.0
	}
	coins = GameConfig.PLAYER["initial_coins"]

	# 从 _DEFAULTS 批量重置所有字段（Array/Dictionary 需 duplicate 避免引用共享）
	for key: String in _DEFAULTS:
		var val: Variant = _DEFAULTS[key]
		if val is Array or val is Dictionary:
			set(key, val.duplicate())
		else:
			set(key, val)

	# typed Array[String] 无法放入无类型 Dictionary，单独重置
	purchased_item_list = []

func record_kill() -> void:
	total_kills += 1
	current_kill_streak += 1
	if current_kill_streak > max_kill_streak:
		max_kill_streak = current_kill_streak

func reset_kill_streak() -> void:
	current_kill_streak = 0

func record_damage_taken(amount: float) -> void:
	total_damage_taken += amount

func record_coins_earned(amount: int) -> void:
	total_coins_earned += amount

func record_item_purchased(item_id: String) -> void:
	purchased_item_list.append(item_id)
