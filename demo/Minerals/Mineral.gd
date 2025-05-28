class_name Mineral_Limits
extends Resource

@export var rotate := false
@export var max_spawn_rate := 0.1 # (float, 0, 1)
@export var spawn_limits: Curve


func get_spawn_chance(depth: float, max_depth: float) -> float:
	return spawn_limits.sample(depth / max_depth) * max_spawn_rate


func can_spawn(depth: float, max_depth: float) -> bool:
	return randf() < get_spawn_chance(depth, max_depth)
