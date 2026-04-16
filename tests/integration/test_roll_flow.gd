extends GutTest

# 集成测试 — Roll 流程

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	InventoryManager.coins = 100

func test_roll_pick_three_times_fills_queue() -> void:
	for i in 3:
		assert_true(InventoryManager.roll_tower())
		# 确认 offer 有 3 个候选
		assert_eq(InventoryManager.get_current_roll_offer().size(), 3)
		InventoryManager.confirm_roll_pick(0)
	assert_eq(InventoryManager.pending_towers.size(), 3)

func test_roll_blocked_when_queue_full() -> void:
	for i in 3:
		InventoryManager.roll_tower()
		InventoryManager.confirm_roll_pick(0)
	# 第 4 次应被阻止
	assert_false(InventoryManager.roll_tower())
	assert_false(InventoryManager.can_roll())

func test_consume_pending_after_full_allows_more_roll() -> void:
	for i in 3:
		InventoryManager.roll_tower()
		InventoryManager.confirm_roll_pick(0)
	InventoryManager.consume_pending(0)
	# 现在可以再 roll
	assert_true(InventoryManager.can_roll())

func test_cancel_refunds_full_cost() -> void:
	var pre: int = InventoryManager.coins
	InventoryManager.roll_tower()
	InventoryManager.cancel_roll()
	assert_eq(InventoryManager.coins, pre)
