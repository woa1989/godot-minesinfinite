extends Node2D

enum {CAVES, DIRT, COPPER, IRON, SILVER, GOLD, \
		PLATINUM, URANIUM, RADINIUM, LAVERDARNIUM, JASMINIUM, \
		 ROCK, LAVA, DEBRIS0, DEBRIS1, DEBRIS2, DEBRIS3}

var atlas_map := {
	CAVES: null,
	DIRT: Vector2i(4, 1),
	COPPER: Vector2i(0, 0),
	IRON: Vector2i(1, 0),
	SILVER: Vector2i(2, 0),
	GOLD: Vector2i(3, 0),
	PLATINUM: Vector2i(4, 0),
	URANIUM: Vector2i(0, 1),
	RADINIUM: Vector2i(1, 1),
	LAVERDARNIUM: Vector2i(2, 1),
	JASMINIUM: Vector2i(3, 1),
	ROCK: Vector2i(5, 0),
	LAVA: Vector2i(5, 1),
	DEBRIS0: Vector2i(6, 0),
	DEBRIS1: Vector2i(7, 0),
	DEBRIS2: Vector2i(6, 1),
	DEBRIS3: Vector2i(7, 1)
}

signal world_load_complete
signal world_load_progress

@export var world_size := Vector2(40, 600)
@export var scroll_speed := 30 # (float, 100, 5000)
@export var noise: FastNoiseLite
@export var cave_threshold := 0.25 # (float, 0, 2)
@export var mineral_rates := [] # (Array, Resource)

@onready var dirt := $Dirt
@onready var minerals := $Minerals
@onready var lava := $Lava
@onready var camera = $LoadingCamera

var scroll = true

	


func _process(delta):
	if scroll:
		camera.position.y += scroll_speed * delta


func get_tile_index(position: Vector2):
	return dirt.local_to_map(dirt.to_local(position))


func get_tile_contents(index: Vector2):
	var tile = Global.Tile.new()
	var dirt_value = atlas_map.find_key(dirt.get_cell_atlas_coords(0, index))
	var mineral_value = atlas_map.find_key(minerals.get_cell_atlas_coords(0, index))
	
	# Empty unless proven otherwise
	tile.tile_type = Global.TileType.EMPTY
	tile.mineral_type = Global.Mineral.NONE
	
	if dirt_value == DIRT:
		tile.tile_type = Global.TileType.DIRT
	
	match mineral_value:
		ROCK:
			tile.tile_type = Global.TileType.ROCK
		LAVA:
			tile.tile_type = Global.TileType.LAVA
		COPPER, IRON, SILVER, GOLD, PLATINUM, \
		URANIUM, RADINIUM, LAVERDARNIUM, JASMINIUM:
			tile.tile_type = Global.TileType.MINERAL
			tile.mineral_type = mineral_value - 1
	
	return tile


func mine_tile(index: Vector2):
	dirt.set_cells_terrain_connect(0, [index], 0, 0)
	minerals.erase_cell(0, index)


func clear_terrain():
	dirt.clear()
	minerals.clear()
	camera.position.y = 4128 # Below the store and player
	camera.make_current()


func generate_terrain():
	noise.seed = randi()
	clear_terrain()
	scroll = true
	
	# Generate one row per frame so we don't have to wait for the game to load.
	for y in world_size.y:
		for x in world_size.x:
			if (noise.get_noise_2d(x, y) + 1) < cave_threshold:
				dirt.set_cells_terrain_connect(0, [Vector2i(x, y)], 0, 0)
			else:
				dirt.set_cell(0, Vector2i(x, y), 0, atlas_map[DIRT])
				place_mineral(x, y)
		
		emit_signal("world_load_progress", (y * 100) / world_size.y)
		await get_tree().process_frame
	
	await get_tree().process_frame
	for x in world_size.x:
		dirt.set_cell(0, Vector2i(x, -1), 0, atlas_map[DIRT])
		minerals.set_cell(0, Vector2i(x, -1), 0, atlas_map[ROCK])
		dirt.set_cell(0, Vector2i(x, world_size.y), 0, atlas_map[DIRT])
		minerals.set_cell(0, Vector2i(x, world_size.y), 0, atlas_map[ROCK])
	await get_tree().process_frame
	for y in world_size.y:
		dirt.set_cell(0, Vector2i(-1, y), 0, atlas_map[DIRT])
		minerals.set_cell(0, Vector2i(-1, y), 0, atlas_map[ROCK])
		dirt.set_cell(0, Vector2i(world_size.x, y), 0, atlas_map[DIRT])
		minerals.set_cell(0, Vector2i(world_size.x, y), 0, atlas_map[ROCK])
	
	await get_tree().process_frame
	for y in world_size.y:
		for x in range(-11, -1):
			lava.set_cell(0, Vector2i(x, y), 0, atlas_map[LAVA])
		for x in range(1, 11):
			lava.set_cell(0, Vector2i(world_size.x + x, y), 0, atlas_map[LAVA])
	await get_tree().process_frame
	for x in range(-11, world_size.x + 10):
		for y in range(-11, -1):
			lava.set_cell(0, Vector2i(x, y), 0, atlas_map[LAVA])
		for y in range(1, 11):
			lava.set_cell(0, Vector2i(x, world_size.y + y), 0, atlas_map[LAVA])
	
	_add_boring_machine(Vector2(25, 3))

	scroll = false
	position = Vector2.ZERO
	emit_signal("world_load_complete")


func place_mineral(x: int, y: int):
	# Evaluate the region and place an appropriate mineral or hazard.
	# Place a lava pocket.
	if _check_set(LAVA, x, y):
		return
	
	# Place a rock.
	if _check_set(ROCK, x, y):
		return
	
	# Iterate through minerals, from the rarest to least rare.
	var i = JASMINIUM
	while i >= COPPER:
		if _check_set(i, x, y):
			return
		i -= 1

	# Place a decorative debris.
	var random_debris = DEBRIS0 + (randi() % 4)
	if _check_set(random_debris, x, y):
		return
	
	# Skip placing a thing, just let dirt be dirt.
	return


func _add_boring_machine(pos: Vector2i):
	for x in range(0, 4):
		for y in range(0, 4):
			dirt.set_cells_terrain_connect(0, [Vector2i(pos.x + x, pos.y + y)], 0, 0)
			minerals.erase_cell(0, Vector2i(pos.x + x, pos.y + y))
	minerals.set_cell(0, Vector2i(pos.x + 3, pos.y + 4), ROCK)
	minerals.set_cell(0, Vector2i(pos.x + 1, pos.y + 4), ROCK)


func _check_set(mineral: int, x: int, y: int) -> bool:
	if mineral_rates[mineral].can_spawn(y, world_size.y):
		if mineral_rates[mineral].rotate:
			minerals.set_cell(0, Vector2i(x, y), 0, atlas_map[mineral])
			# TODO: ROTATE!
		else:
			minerals.set_cell(0, Vector2i(x, y), 0, atlas_map[mineral])
		return true
	return false


func _randb() -> bool:
	return randf() < 0.5
