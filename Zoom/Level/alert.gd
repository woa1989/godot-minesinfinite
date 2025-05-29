extends HBoxContainer

signal back_pressed
signal exit_pressed

@onready var BackBut: Button = $Back
@onready var ExitBut: Button = $Exit

func _ready() -> void:
	BackBut.pressed.connect(_on_BackBut_Pressed)
	ExitBut.pressed.connect(_on_ExitBut_Pressed)
	
func _on_BackBut_Pressed():
	back_pressed.emit()

func _on_ExitBut_Pressed():
	exit_pressed.emit()
