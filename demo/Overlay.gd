extends CanvasLayer

signal exit_store
signal generate_tileset




func _process(_delta):
	$HUD/Coins.text = _costify(Global.currency)
	if Global.in_store:
		$Store/Cash_left.text = _costify(Global.currency)
		$Store/VBoxContainer/Cargo/Cost.text = _costify(_calculate_cargo_cost())
		$Store/VBoxContainer/Fuel/Cost.text = _costify(int(Global.player_fuel_max - Global.player_fuel))
		$Store/VBoxContainer/Hull/Cost.text = _costify((Global.player_health_max - Global.player_health) * 10)
		$Store/VBoxContainer2/Cargo/Cost.text = _costify(_cargo_cost())
		$Store/VBoxContainer2/Fuel/Cost.text = _costify(_fuel_cost())
		$Store/VBoxContainer2/Hull/Cost.text = _costify(_hull_cost())
		$Store/Descriptors.text = "Cargo Size: %d\nMax Fuel: %d\nMax Hull: %d\nDynamite: %d" % \
			[Global.cargo_size, Global.player_fuel_max, Global.player_health_max, Global.dynamite_remaining]


func open_store():
	$Store.visible = true
	Global.in_store = true


func world_load(percent):
	$ProgressBar.visible = true
	$HUD.visible = false
	$ProgressBar.value = percent


func world_load_end():
	$ProgressBar.visible = false
	$HUD.visible = true


func _costify(i: int) -> String:
	return "$" + str(i)


func _calculate_cargo_cost() -> int:
	var c := 0
	for x in Global.minerals_collected.size():
		c += Global.minerals_collected[x] * Global.MineralCosts[x]
	return c


func _on_Store_Close_pressed():
	$Store.visible = false
	Global.in_store = false
	emit_signal("exit_store")


func _on_SellCargo_pressed():
	Global.currency += _calculate_cargo_cost()
	for x in Global.minerals_collected.size():
		Global.minerals_collected[x] = 0
	Global.cargo_collected = 0


func _fuel_cost() -> int:
	return int((Global.player_fuel_max - 85) * 50)


func _hull_cost() -> int:
	return (Global.player_health_max - 90) * 1000


func _cargo_cost() -> int:
	return (Global.cargo_size - 9) * 1000


func _on_BuyFuel_pressed():
	var fuel_needed = Global.player_fuel_max - Global.player_fuel
	if Global.currency < fuel_needed:
		fuel_needed = Global.currency
	
	Global.currency -= fuel_needed
	Global.player_fuel += fuel_needed


func _on_RepairHull_pressed():
	var hull_needed = Global.player_health_max - Global.player_health
	if Global.currency < hull_needed * 10:
		hull_needed = int(Global.currency / 10.0)
	
	Global.currency -= hull_needed * 10
	Global.player_health += hull_needed


func _on_BuyDynamite_pressed():
	if Global.currency >= 1000:
		Global.currency -= 1000
		Global.dynamite_remaining += 1


func _on_UpgradeHull_pressed():
	if Global.currency >= _hull_cost():
		Global.currency -= _hull_cost()
		Global.player_health_max += 10
		Global.player_health = Global.player_health_max


func _on_UpgradeFuel_pressed():
	if Global.currency >= _fuel_cost():
		Global.currency -= _fuel_cost()
		Global.player_fuel_max += 10
		Global.player_fuel = Global.player_fuel_max


func _on_UpgradeCargo_pressed():
	if Global.currency >= _cargo_cost():
		Global.currency -= _cargo_cost()
		Global.cargo_size += 1


func _add_dynamite():
	Global.dynamite_remaining += 10


func _add_health():
	Global.player_health_max += 100
	Global.player_health = Global.player_health_max


func _add_fuel():
	Global.player_fuel_max += 100
	Global.player_fuel = Global.player_fuel_max


func _add_cargo():
	Global.cargo_size += 10


func _on_GenerateTileset_pressed():
	emit_signal("generate_tileset")
