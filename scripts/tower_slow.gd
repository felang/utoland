extends Tower

@export var slow_radius: float = 200.0
@export var slow_percent: float = 0.5

var slow_area: Area2D

func _ready():
	super._ready()
	
	# 创建减速光环
	slow_area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = slow_radius
	collision.shape = shape
	slow_area.add_child(collision)
	add_child(slow_area)
	
	# 连接信号
	slow_area.body_entered.connect(_on_enemy_entered)
	slow_area.body_exited.connect(_on_enemy_exited)

func _on_enemy_entered(body):
	if body.is_in_group("enemies"):
		body.speed *= (1.0 - slow_percent)

func _on_enemy_exited(body):
	if body.is_in_group("enemies"):
		body.speed /= (1.0 - slow_percent)
