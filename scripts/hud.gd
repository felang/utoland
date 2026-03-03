extends CanvasLayer

@onready var hp_label = $HPLabel
@onready var timer_label = $TimerLabel

var player: Node2D = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("HUD: Player node not found in 'player' group")

func _process(_delta):
	if player:
		hp_label.text = "HP: %.0f" % player.current_hp
