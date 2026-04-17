extends CanvasLayer
## 战斗 HUD 主组件
##
## 包含:
##   - 底部中央: Roll 按钮 + 待建造栏(实例化 PendingQueuePanel.tscn)
##
## 外部依赖:drag_manager,由 main.gd 注入。

const ROLL_BTN_SIZE := Vector2(120, 36)
const PENDING_PANEL_SCENE := preload("res://scenes/ui/pending_queue_panel.tscn")

var drag_manager: Node = null

var _roll_button: Button
var _pending_panel: Control

func _ready() -> void:
	layer = 10
	_build_ui()
	_refresh_roll_button()
	EventBus.coins_changed.connect(func(_d: int, _t: int) -> void: _refresh_roll_button())
	EventBus.tower_added_to_queue.connect(func(_t: String) -> void: _refresh_roll_button())
	EventBus.tower_consumed_from_queue.connect(func(_i: int) -> void: _refresh_roll_button())
	EventBus.tower_roll_canceled.connect(func() -> void: _refresh_roll_button())

func _build_ui() -> void:
	# 底部:Roll 按钮 + 待建造栏
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	bottom.position.y = -100
	add_child(bottom)

	_roll_button = Button.new()
	_roll_button.custom_minimum_size = ROLL_BTN_SIZE
	_roll_button.pressed.connect(_on_roll_pressed)
	bottom.add_child(_roll_button)

	_pending_panel = PENDING_PANEL_SCENE.instantiate()
	bottom.add_child(_pending_panel)

func _refresh_roll_button() -> void:
	var cost: int = GameConfig.shop_config.roll_cost
	_roll_button.text = "Roll $%d" % cost
	_roll_button.disabled = not InventoryManager.can_roll()

func _on_roll_pressed() -> void:
	InventoryManager.roll_tower()
	_refresh_roll_button()

func set_drag_manager(dm: Node) -> void:
	drag_manager = dm
	if _pending_panel:
		_pending_panel.drag_manager = dm
