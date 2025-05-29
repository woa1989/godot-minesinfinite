extends Control

@onready var AmmoLabel: Label = $Label
var KillLabel: Label
var StatusLabel: Label

func _ready() -> void:
	# 创建击杀标签
	KillLabel = Label.new()
	add_child(KillLabel)
	KillLabel.position = Vector2(10, 40)
	KillLabel.name = "KillLabel"
	KillLabel.add_theme_font_size_override("font_size", 16)
		
	# 创建状态标签
	StatusLabel = Label.new()
	add_child(StatusLabel)
	StatusLabel.position = Vector2(10, 70)
	StatusLabel.name = "StatusLabel"
	StatusLabel.add_theme_font_size_override("font_size", 16)

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
