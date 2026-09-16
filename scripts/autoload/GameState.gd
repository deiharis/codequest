extends Node

var current_world_index: int = 0
var completed_worlds: Array[String] = []

func is_world_unlocked(order_index: int) -> bool:
	return order_index <= current_world_index

func complete_world(world_id: String):
	if not completed_worlds.has(world_id):
		completed_worlds.append(world_id)
	current_world_index += 1
