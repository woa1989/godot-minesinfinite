extends Node2D

func _ready():
	$CanvasLayer/ToTownButton.pressed.connect(to_town)
	
func to_town():
	get_tree().change_scene_to_file("res://Town/Town.tscn")
