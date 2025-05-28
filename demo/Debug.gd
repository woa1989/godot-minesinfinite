extends Control

@onready var player = $Label_Player
@onready var down = $Label_Bottom
@onready var left = $Label_Left
@onready var right = $Label_Right

const names = ["NONE", "COPPER", "IRON", "SILVER", "GOLD", "PLATINUM",\
		"URANIUM", "RADINIUM", "LAVERDARNIUM", "JASMINIUM"]


func update():
	player.text = "Player Pos:\n" + str(Global.player_location)
	down.text = "Tile Below:\n" + tile_name(Global.tile_below)
	left.text = "Tile Left:\n" + tile_name(Global.tile_left)
	right.text = "Tile Right:\n" + tile_name(Global.tile_right)
	
	$Resources_Label2.text = "\n" + str(Global.minerals_collected)\
		.replace(",","\n").replace("[", "").replace("]","")


func tile_name(tile) -> String:
	match tile.tile_type:
		Global.TileType.DIRT:
			return "Dirt"
		Global.TileType.EMPTY:
			return "Empty"
		Global.TileType.ROCK:
			return "Rock"
		Global.TileType.LAVA:
			return "Lava"
		Global.TileType.MINERAL:
			return names[tile.mineral_type]
		_:
			return "Unknown"
