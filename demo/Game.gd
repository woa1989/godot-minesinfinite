extends Node2D

@onready var world = $World
@onready var overlay = $Overlay
@onready var debug = $Overlay/Debug
@onready var health_bar = $Overlay/HUD/Health
@onready var fuel_bar = $Overlay/HUD/Fuel
@onready var cargo_bar = $Overlay/HUD/Cargo
@onready var player = $Player


# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	Global.debug_overlay_active = debug.visible
	
	Global.loading = true
	overlay.world_load(0)
	world.generate_terrain()


func _process(_delta):
	# Update the player position (tracked globally)
	_update_world_tracking()
	if Global.debug_overlay_active:
		debug.update()
	
	# Draw HUD.
	health_bar.max_value = Global.player_health_max
	health_bar.value = Global.player_health
	fuel_bar.max_value = Global.player_fuel_max
	fuel_bar.value = Global.player_fuel
	cargo_bar.max_value = Global.cargo_size
	cargo_bar.value = Global.cargo_collected


func _update_world_tracking():
	var player_pos = world.get_tile_index($Player.global_position)
	Global.player_location = player_pos
	
	Global.tile_below = world.get_tile_contents(player_pos + Vector2i.DOWN)
	Global.tile_left = world.get_tile_contents(player_pos + Vector2i.LEFT)
	Global.tile_right = world.get_tile_contents(player_pos + Vector2i.RIGHT)


func _toggle_debug():
	debug.visible = !debug.visible
	Global.debug_overlay_active = debug.visible


func _add_mineral_to_cargo(tile):
	if tile.tile_type == Global.TileType.MINERAL:
		if Global.cargo_collected < Global.cargo_size:
			Global.minerals_collected[tile.mineral_type - 1] += 1
			Global.cargo_collected += 1
	if tile.tile_type == Global.TileType.LAVA:
		Global.player_health -= 49
		if Global.player_health < 0:
			player.die()


func _on_World_load_complete():
	$Player/Camera2D.make_current()
	Global.loading = false
	overlay.world_load_end()


func _on_Player_dig_down():
	_add_mineral_to_cargo(Global.tile_below)
	world.mine_tile(Global.player_location + Vector2.DOWN)


func _on_Player_dig_left():
	_add_mineral_to_cargo(Global.tile_left)
	world.mine_tile(Global.player_location + Vector2.LEFT)


func _on_Player_dig_right():
	_add_mineral_to_cargo(Global.tile_right)
	world.mine_tile(Global.player_location + Vector2.RIGHT)


func _on_Player_dynamite():
	if Global.dynamite_remaining > 0:
		for x in range(-1,2):
			for y in range(-1,2):
				world.mine_tile(Global.player_location + Vector2(x, y))
		Global.dynamite_remaining -= 1


func _on_Store_player_entered():
	overlay.open_store()
	player.global_position = $World/Store/Player_Drop.global_position


func _on_Overlay_generate_tileset():
	player.global_position = $World/Store/Player_Drop.global_position
	Global.loading = true
	overlay.world_load(0)
	world.generate_terrain()


func _on_World_world_load_progress(percent):
	overlay.world_load(percent)


func _on_Player_died():
	player.global_position = $World/Store/Player_Drop.global_position
	Global.reset_player()
