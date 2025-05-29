extends Camera2D

func _process(_delta: float) -> void:
	global_position =  $"../Player".global_position
