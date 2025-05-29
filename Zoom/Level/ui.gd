extends Control

@onready var AmmoLabel:Label = $Label

func _process(_delta: float) -> void:
	AmmoLabel.text = "AMMO LEFT: " + str(GlobalVars.bullets)
