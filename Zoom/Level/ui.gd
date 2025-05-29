extends Control

@onready var AmmoLabel: Label = $ItemList/Label
@onready var KillLabel: Label = $ItemList/Label2
@onready var StatusLabel: Label = $ItemList/Label3

func _process(_delta: float) -> void:
	if AmmoLabel:
		AmmoLabel.text = "AMMO LEFT: " + str(GlobalVars.bullets)
	
	if KillLabel:
		KillLabel.text = "ZOMBIES KILLED: " + str(GlobalVars.zombies_killed) + "/" + str(GlobalVars.total_zombies)
	
	if StatusLabel:
		# 显示游戏状态
		if GlobalVars.total_zombies > 0 and GlobalVars.zombies_killed >= GlobalVars.total_zombies:
			StatusLabel.text = "VICTORY! ALL ZOMBIES ELIMINATED!"
			StatusLabel.modulate = Color.GREEN
		elif GlobalVars.bullets <= 0 and GlobalVars.zombies_killed < GlobalVars.total_zombies:
			StatusLabel.text = "GAME OVER! NO AMMO LEFT!"
			StatusLabel.modulate = Color.RED
		else:
			StatusLabel.text = "ELIMINATE ALL ZOMBIES!"
			StatusLabel.modulate = Color.WHITE
