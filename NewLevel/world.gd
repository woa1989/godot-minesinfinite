extends Node2D

const MapData = preload("res://Level/map_data.gd")

@onready var dirt := $Dirt
@onready var player := get_node("/root/Game/Player") # 玩家节点

# 地图参数
const TILE_SIZE := 256 # 单个瓦片像素
const CHUNK_SIZE := 16 # 区块大小（瓦片数）
const LOAD_DISTANCE := 3 # 加载玩家周围多少区块
const UNLOAD_DISTANCE := 5 # 超过这个距离的区块会被卸载

# 区块管理
var loaded_chunks = {} # 已加载区块 {Vector2i: bool}
var current_chunk = Vector2i.ZERO # 当前玩家所在区块


var atlas_map = {} # 图块映射

# 从MapData中获取枚举值 - 只保留所需的土和宝箱类型
enum {EMPTY = MapData.EMPTY, DIRT = MapData.DIRT, CHEST1 = MapData.CHEST1,
	  CHEST2 = MapData.CHEST2, CHEST3 = MapData.CHEST3, GROUND = MapData.GROUND}

func _ready():
	# 设置图块映射
	setup_atlas_map()
	
	# 等待两帧确保资源加载完成
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 连接玩家挖掘信号
	if player:
		player.dig.connect(_on_player_dig)
	
	# 初始加载区块
	update_chunks()

func _process(_delta):
	# 持续更新区块
	update_chunks()

# 设置图块映射
func setup_atlas_map():
	# 基本图块映射从MapData获取
	for map_name in MapData.MAPS:
		var map_data = MapData.MAPS[map_name]
		if map_data.id == "mine": # 使用基础矿洞的配置
			atlas_map = map_data.atlas_map.duplicate()
			break

# 获取瓦片的世界位置
func get_tile_index(pos: Vector2):
	return dirt.local_to_map(dirt.to_local(pos))

# 获取瓦片内容
func get_tile_contents(index: Vector2):
	var tile = {
		"tile_type": "empty",
	}
	
	var dirt_value = -1
	var dirt_coords = dirt.get_cell_atlas_coords(0, index)
	for key in atlas_map.keys():
		if atlas_map[key] == dirt_coords:
			dirt_value = key
			break
	
	if dirt_value == DIRT:
		tile.tile_type = "dirt"
	elif dirt_value in [CHEST1, CHEST2, CHEST3]:
		tile.tile_type = "chest"
	
	return tile

# 挖掘指定位置的瓦片
func mine_tile(index: Vector2):
	dirt.erase_cell(index)

# 清除地形
func clear_terrain():
	dirt.clear()
	loaded_chunks.clear()
	print("[World] 已清除地形")

# 世界坐标转区块坐标
func world_to_chunk(world_pos: Vector2) -> Vector2i:
	var tile_pos = dirt.local_to_map(dirt.to_local(world_pos))
	return Vector2i(floor(tile_pos.x / float(CHUNK_SIZE)), floor(tile_pos.y / float(CHUNK_SIZE)))

# 加载/卸载玩家周围的区块
func update_chunks():
	if not player:
		return
		
	var player_chunk = world_to_chunk(player.global_position)
	if player_chunk != current_chunk:
		current_chunk = player_chunk
	
	# 加载玩家周围的区块
	for y in range(-1, LOAD_DISTANCE + 1):
		for x in range(-LOAD_DISTANCE, LOAD_DISTANCE + 1):
			var chunk_pos = Vector2i(player_chunk.x + x, player_chunk.y + y)
			if not loaded_chunks.has(chunk_pos):
				generate_chunk(chunk_pos)
	
	# 卸载远离玩家的区块
	var chunks_to_unload = []
	for chunk_pos in loaded_chunks.keys():
		var distance = (Vector2(chunk_pos) - Vector2(player_chunk)).length()
		if distance > UNLOAD_DISTANCE:
			chunks_to_unload.append(chunk_pos)
	
	for chunk_pos in chunks_to_unload:
		unload_chunk(chunk_pos)

# 生成单个区块
func generate_chunk(chunk_pos: Vector2i):
	if loaded_chunks.has(chunk_pos):
		return
		
	# 获取有效的源ID
	var source_id = 0
	var source_count = dirt.tile_set.get_source_count()
	if source_count > 0:
		source_id = dirt.tile_set.get_source_id(0)
	else:
		push_error("[World] 无法获取有效的源ID!")
		return
	
	# 生成区块内容
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x = start_x + x
			var world_y = start_y + y
			var pos = Vector2i(world_x, world_y)
			
			# 地面层生成GROUND
			if world_y == 0:
				_set_cell(dirt, pos, source_id, atlas_map[GROUND])
			# 地下生成内容
			elif world_y > 0:
				# 全部填充土块
				_set_cell(dirt, pos, source_id, atlas_map[DIRT])
				
				# 随机生成宝箱（1%概率）
				if world_y > 5 and randf() > 0.99:
					generate_chest(pos)
	
	loaded_chunks[chunk_pos] = true
	print("[World] 生成区块: ", chunk_pos)

# 卸载区块
func unload_chunk(chunk_pos: Vector2i):
	if not loaded_chunks.has(chunk_pos):
		return
		
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x = start_x + x
			var world_y = start_y + y
			var pos = Vector2i(world_x, world_y)
			dirt.erase_cell(pos)
			
	loaded_chunks.erase(chunk_pos)
	print("[World] 卸载区块: ", chunk_pos)

# 玩家挖掘信号回调
func _on_player_dig(tile_pos: Vector2i, _direction: String):
	mine_tile(tile_pos)

# 生成宝箱
func generate_chest(pos: Vector2i):
	var chest_type = CHEST1
	var rand_val = randf()
	
	if rand_val > 0.95:
		chest_type = CHEST3
	elif rand_val > 0.8:
		chest_type = CHEST2
	
	# 获取有效的源ID
	var source_id = 0
	var source_count = dirt.tile_set.get_source_count()
	if source_count > 0:
		source_id = dirt.tile_set.get_source_id(0)
	else:
		push_error("[World] 无法获取有效的源ID!")
		return
	
	# 设置宝箱图块
	_set_cell(dirt, pos, source_id, atlas_map[chest_type])

# 辅助函数：设置单元格，根据 Level/world.gd 中的使用方式
func _set_cell(tilemap: TileMapLayer, coords: Vector2i, source_id: int, atlas_coord: Vector2i, _alternative_tile: int = 0) -> void:
	# 在这个项目中，set_cell 的预期参数格式是 (pos, source_id, atlas_coords)
	tilemap.set_cell(coords, source_id, atlas_coord)

# 辅助函数：设置地形连接单元格
func _set_cells_terrain_connect(tilemap: TileMapLayer, cell: Vector2i, _terrain_set: int, _terrain: int) -> void:
	# 当前版本中可能不支持 set_cells_terrain_connect，使用替代方案
	# 简单地使用 erase_cell 清除单元格，模拟洞穴效果
	tilemap.erase_cell(cell)
