extends CanvasLayer

@onready var hp_label = $HPLabel
@onready var timer_label = $TimerLabel

var player: Node2D = null
var wave_manager: Node = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("HUD: Player node not found in 'player' group")
	wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if not wave_manager:
		push_warning("HUD: WaveManager node not found in 'wave_manager' group")

func _process(_delta):
	if player and is_instance_valid(player):
		hp_label.text = "HP: %.0f | Coins: %d" % [player.current_hp, player.coins]

	if not wave_manager or not is_instance_valid(wave_manager):
		wave_manager = get_tree().get_first_node_in_group("wave_manager")

	if wave_manager:
		timer_label.text = "Wave: %d/10 | Time: %.0f" % [wave_manager.current_wave, wave_manager.wave_time_left]
