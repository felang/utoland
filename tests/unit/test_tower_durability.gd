extends GutTest

var test_scene: Node2D
var _received_deploy_id: int = -1

func before_each():
	test_scene = Node2D.new()
	add_child_autofree(test_scene)
	_received_deploy_id = -1

func _on_tower_destroyed(_type: String, _pos: Vector2, did: int) -> void:
	_received_deploy_id = did

func test_tower_has_deploy_id():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	assert_eq(tower.deploy_id, -1, "deploy_id 默认应为 -1")
	tower.deploy_id = 42
	assert_eq(tower.deploy_id, 42, "deploy_id 应可设置")

func test_tower_destroyed_emits_deploy_id():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	tower.deploy_id = 7
	EventBus.tower_destroyed.connect(_on_tower_destroyed)
	tower.take_damage(tower.health.max_hp + 10)
	assert_eq(_received_deploy_id, 7, "tower_destroyed 应携带 deploy_id")
	EventBus.tower_destroyed.disconnect(_on_tower_destroyed)

func test_inventory_remove_destroyed_tower():
	InventoryManager.reset()
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 10})
	InventoryManager.deployed_towers.append({id = "ice_flower", level = 1, grid_pos = Vector2i(6, 6), deploy_id = 11})
	assert_eq(InventoryManager.deployed_towers.size(), 2)
	InventoryManager.remove_destroyed_tower(10)
	assert_eq(InventoryManager.deployed_towers.size(), 1)
	assert_eq(InventoryManager.deployed_towers[0].deploy_id, 11, "只移除 deploy_id=10 的塔")

func test_inventory_remove_destroyed_tower_nonexistent():
	InventoryManager.reset()
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 10})
	InventoryManager.remove_destroyed_tower(999)
	assert_eq(InventoryManager.deployed_towers.size(), 1, "不存在的 deploy_id 不影响数组")

func test_tower_low_hp_tint():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	await wait_frames(2)
	assert_eq(tower.visual.modulate, Color.WHITE, "满血时 modulate 应为白色")
	var low_hp_damage: float = tower.health.max_hp * 0.75
	tower.take_damage(low_hp_damage)
	assert_eq(tower.visual.modulate, Color(1, 0.5, 0.5), "HP < 30% 时应变红")

func test_tower_tint_recovers_on_heal():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	await wait_frames(2)
	tower.take_damage(tower.health.max_hp * 0.75)
	assert_eq(tower.visual.modulate, Color(1, 0.5, 0.5), "低血应变红")
	tower.heal(tower.health.max_hp * 0.5)
	assert_eq(tower.visual.modulate, Color.WHITE, "恢复后应恢复白色")

func test_health_component_heal_clamps():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	var max_hp: float = tower.health.max_hp
	tower.take_damage(10.0)
	tower.health.heal(max_hp)
	assert_almost_eq(tower.health.current_hp, max_hp, 0.01, "heal 不应超过 max_hp")
