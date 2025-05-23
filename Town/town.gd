extends Node2D

@onready var shop_ui = $CanvasLayer/ShopUI
@onready var status_label = $CanvasLayer/ShopUI/Panel/VBoxContainer/StatusLabel
@onready var currency_label = $CanvasLayer/ShopUI/CurrencyLabel

func _ready():
	# 连接按钮信号
	var health_btn = $CanvasLayer/ShopUI/Panel/VBoxContainer/HealthPotion
	var fuel_btn = $CanvasLayer/ShopUI/Panel/VBoxContainer/FuelTank
	var dynamite_btn = $CanvasLayer/ShopUI/Panel/VBoxContainer/Dynamite
	var cargo_btn = $CanvasLayer/ShopUI/Panel/VBoxContainer/CargoUpgrade
	var mine_btn = $CanvasLayer/ShopUI/Panel/VBoxContainer/ToMine
	
	health_btn.pressed.connect(func(): buy_item(Global.ShopItem.HEALTH_POTION))
	fuel_btn.pressed.connect(func(): buy_item(Global.ShopItem.FUEL_TANK))
	dynamite_btn.pressed.connect(func(): buy_item(Global.ShopItem.DYNAMITE))
	cargo_btn.pressed.connect(func(): buy_item(Global.ShopItem.CARGO_UPGRADE))
	mine_btn.pressed.connect(to_mine)
	
	Global.in_store = true

func _process(_delta):
	currency_label.text = "金币: %d" % Global.currency

func buy_item(item: Global.ShopItem):
	if Global.buy_item(item):
		status_label.text = "购买成功!"
	else:
		status_label.text = "金币不足!"
	
func to_mine():
	Global.in_store = false
	get_tree().change_scene_to_file("res://Level/level.tscn")
