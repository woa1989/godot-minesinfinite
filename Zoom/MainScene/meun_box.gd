extends VBoxContainer

@onready var PlayBut: Button = $Play
@onready var ExitBut: Button = $Exit

func _ready() -> void:
	PlayBut.pressed.connect(_on_PlayBut_Pressed)
	ExitBut.pressed.connect(_on_ExitBut_Pressed)
	
func _on_PlayBut_Pressed():
	# 重置游戏状态，确保开始新游戏时有正确的初始值
	GlobalVars.reset_game()
	get_tree().change_scene_to_packed(preload("res://Zoom/Level/Level_1.tscn"))

func _on_ExitBut_Pressed():
	get_tree().quit()
	pass
