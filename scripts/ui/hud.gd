extends CanvasLayer

@onready var hp_label = $HPLabel
@onready var timer_label = $TimerLabel

var player: Node2D = null
var _wave_time_left: float = 0.0
var _is_wave_active: bool = false

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("HUD: Player node not found in 'player' group")
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)

func _process(delta):
	if player and is_instance_valid(player):
		hp_label.text = "HP: %.0f | Coins: %d" % [player.current_hp, player.coins]

	if _is_wave_active:
		_wave_time_left -= delta
		if _wave_time_left < 0:
			_wave_time_left = 0.0
	timer_label.text = "Wave: %d/10 | Time: %.0f" % [GameData.current_wave, _wave_time_left]

func _on_wave_started(wave_number: int, wave_config: Dictionary) -> void:
	_is_wave_active = true
	_wave_time_left = wave_config.get("duration", 0.0)

func _on_wave_completed(_wave_number: int) -> void:
	_is_wave_active = false
