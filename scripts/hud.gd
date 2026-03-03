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

func _process(_delta):
	if player:
		hp_label.text = "HP: %.0f" % player.current_hp
	if wave_manager:
		timer_label.text = "Time: %.0f" % wave_manager.time_remaining
