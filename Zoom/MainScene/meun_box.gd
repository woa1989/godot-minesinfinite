extends VBoxContainer

@onready var PlayBut: Button = $Play
@onready var ExitBut: Button = $Exit

func _ready() -> void:
	PlayBut.pressed.connect(_on_PlayBut_Pressed)
	ExitBut.pressed.connect(_on_ExitBut_Pressed)
	
func _on_PlayBut_Pressed():
	print("s")
	#get_tree().change_scene_to_packed()

func _on_ExitBut_Pressed():
	get_tree().quit()
	pass
