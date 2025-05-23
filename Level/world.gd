extends Node2D

# 载入自定义数据助手
const TileSetDataHelper = preload("res://Level/tileset_custom_data.gd")

# 图块类型枚举
enum {EMPTY, DIRT, CHEST1, CHEST2, CHEST3, GROUND, BOOM}

# 图块类型与图集坐标映射
var atlas_map := {
	EMPTY: null,
	DIRT: Vector2i(5, 0),
	CHEST1: Vector2i(2, 1),
	CHEST2: Vector2i(0, 2),
	CHEST3: Vector2i(3, 6),
	GROUND: Vector2i(0, 7),
	BOOM: Vector2i(7, 5)
}

# 地图参数
const TILE_SIZE := 64 # 单个瓦片像素
const CHUNK_SIZE := 16 # 区块大小（瓦片数）
const LOAD_DISTANCE := 3 # 加载玩家周围多少区块
const UNLOAD_DISTANCE := 5 # 超过这个距离的区块会被卸载
const SCREEN_WIDTH := 1920 # 屏幕宽度

@export var world_position := Vector2(-TILE_SIZE, 0) # 地图初始偏移
@onready var dirt := $Dirt as TileMapLayer # 地形TileMap
@onready var player := %Player # 玩家节点

# 区块管理
var loaded_chunks = {} # 已加载区块 {Vector2i: bool}
var current_chunk = Vector2i.ZERO # 当前玩家所在区块

func _ready() -> void:
	# 初始化TileSet自定义数据层
	var tileset = dirt.tile_set
	if tileset:
		TileSetDataHelper.init_custom_data(tileset)
	# 连接玩家挖掘信号
	player.dig.connect(_on_player_dig)
	
	# 如果已有缓存的地图，则加载它
	if Global.has_existing_mine:
		load_cached_chunks()
		player.global_position = Global.player_last_mine_position
	else:
		# 初始加载区块
		update_chunks()
		Global.has_existing_mine = true
	
func _exit_tree() -> void:
	# 在离开场景时保存地图状态
	save_chunks_to_cache()
	# 保存玩家位置
	Global.player_last_mine_position = player.global_position

# 保存所有已加载区块到缓存
func save_chunks_to_cache():
	Global.loaded_chunks_cache.clear()
	for chunk_pos in loaded_chunks.keys():
		var chunk_data = {}
		var start_x = chunk_pos.x * CHUNK_SIZE
		var start_y = chunk_pos.y * CHUNK_SIZE
		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var world_x = start_x + x
				var world_y = start_y + y
				var pos = Vector2i(world_x, world_y)
				var tile_data = dirt.get_cell_tile_data(pos)
				if tile_data:
					var atlas_coords = dirt.get_cell_atlas_coords(pos)
					var health = tile_data.get_custom_data("health")
					var value = tile_data.get_custom_data("value")
					chunk_data[pos] = {
						"atlas_coords": atlas_coords,
						"health": health,
						"value": value
					}
		if not chunk_data.is_empty():
			Global.loaded_chunks_cache[chunk_pos] = chunk_data

# 从缓存加载区块
func load_cached_chunks():
	loaded_chunks.clear()
	for chunk_pos in Global.loaded_chunks_cache:
		var chunk_data = Global.loaded_chunks_cache[chunk_pos]
		for pos in chunk_data:
			var tile_info = chunk_data[pos]
			dirt.set_cell(pos, 0, tile_info.atlas_coords)
			var tile_data = dirt.get_cell_tile_data(pos)
			if tile_data:
				tile_data.set_custom_data("health", tile_info.health)
				tile_data.set_custom_data("value", tile_info.value)
		loaded_chunks[chunk_pos] = true

# 世界坐标转区块坐标
func world_to_chunk(world_pos: Vector2) -> Vector2i:
	var tile_pos = dirt.local_to_map(dirt.to_local(world_pos))
	return Vector2i(floor(tile_pos.x / float(CHUNK_SIZE)), floor(tile_pos.y / float(CHUNK_SIZE)))

# 加载/卸载玩家周围的区块
func update_chunks():
	var player_chunk = world_to_chunk(player.global_position)
	if player_chunk != current_chunk:
		current_chunk = player_chunk
	# 计算水平加载距离
	var load_distance_x = max(LOAD_DISTANCE, int(SCREEN_WIDTH / (TILE_SIZE * CHUNK_SIZE * 1.0)) + 1)
	# 确保左边界区块总是被加载
	var leftmost_chunk = Vector2i(0, player_chunk.y)
	if not loaded_chunks.has(leftmost_chunk):
		generate_chunk(leftmost_chunk)
	# 加载玩家周围的区块
	for y in range(-1, LOAD_DISTANCE + 3):
		for x in range(-load_distance_x, load_distance_x + 1):
			var chunk_pos = Vector2i(player_chunk.x + x, player_chunk.y + y)
			if not loaded_chunks.has(chunk_pos):
				generate_chunk(chunk_pos)
	# 卸载远离玩家的区块
	var chunks_to_unload = []
	for chunk_pos in loaded_chunks.keys():
		var distance_x = abs(chunk_pos.x - player_chunk.x)
		var distance_y = chunk_pos.y - player_chunk.y
		if chunk_pos.x != 0 and (distance_x > load_distance_x + 2 or distance_y < -2 or distance_y > UNLOAD_DISTANCE + 3):
			chunks_to_unload.append(chunk_pos)
	for chunk_pos in chunks_to_unload:
		unload_chunk(chunk_pos)

# 生成单个区块
func generate_chunk(chunk_pos: Vector2i):
	if loaded_chunks.has(chunk_pos):
		return
	# 如果缓存中有这个区块，就从缓存加载
	if Global.loaded_chunks_cache.has(chunk_pos):
		var chunk_data = Global.loaded_chunks_cache[chunk_pos]
		for pos in chunk_data:
			var tile_info = chunk_data[pos]
			dirt.set_cell(pos, 0, tile_info.atlas_coords)
			var tile_data = dirt.get_cell_tile_data(pos)
			if tile_data:
				tile_data.set_custom_data("health", tile_info.health)
				tile_data.set_custom_data("value", tile_info.value)
		loaded_chunks[chunk_pos] = true
		return
		
	# 否则生成新区块
	var tileset = dirt.tile_set
	var custom_data_layers = {}
	for i in range(tileset.get_custom_data_layers_count()):
		var layer_name = tileset.get_custom_data_layer_name(i)
		custom_data_layers[layer_name] = i
	var health_layer = custom_data_layers.get("health", -1)
	var value_layer = custom_data_layers.get("value", -1)
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x = start_x + x
			var world_y = start_y + y
			var pos = Vector2i(world_x, world_y)
			var rand_val = randf()
			# 右边界不生成墙壁
			var is_right_edge = (world_x > 0 and world_x % (CHUNK_SIZE * 10) == (CHUNK_SIZE * 10) - 1)
			if is_right_edge:
				continue
			# 地面上方不生成
			if world_y < 0:
				continue
			# 地面层生成GROUND
			if world_y == 0:
				dirt.set_cell(pos, 0, atlas_map[GROUND])
				var tile_data = dirt.get_cell_tile_data(pos)
				if tile_data and health_layer >= 0 and value_layer >= 0:
					tile_data.set_custom_data_by_layer_id(health_layer, 1)
					tile_data.set_custom_data_by_layer_id(value_layer, 1)
			# 地下生成内容
			else:
				if rand_val < 0.9:
					dirt.set_cell(pos, 0, atlas_map[DIRT])
					var tile_data = dirt.get_cell_tile_data(pos)
					if tile_data and health_layer >= 0 and value_layer >= 0:
						tile_data.set_custom_data_by_layer_id(health_layer, 1)
						tile_data.set_custom_data_by_layer_id(value_layer, 1)
				# 1%概率生成宝箱
				if world_y > 5 and rand_val > 0.99:
					var chest_type = CHEST1
					var chest_health = 3
					var chest_value = 50
					if rand_val > 0.95:
						chest_type = CHEST3
						chest_health = 5
						chest_value = 200
					elif rand_val > 0.8:
						chest_type = CHEST2
						chest_health = 4
						chest_value = 100
					dirt.set_cell(pos, 0, atlas_map[chest_type])
					var tile_data = dirt.get_cell_tile_data(pos)
					if tile_data and health_layer >= 0 and value_layer >= 0:
						tile_data.set_custom_data_by_layer_id(health_layer, chest_health)
						tile_data.set_custom_data_by_layer_id(value_layer, chest_value)
				# 3%概率生成炸药
				elif world_y > 3 and rand_val > 0.97:
					dirt.set_cell(pos, 0, atlas_map[BOOM])
					var tile_data = dirt.get_cell_tile_data(pos)
					if tile_data and health_layer >= 0 and value_layer >= 0:
						tile_data.set_custom_data_by_layer_id(health_layer, 1) # 血量设为1
						tile_data.set_custom_data_by_layer_id(value_layer, 96) # value用于存储爆炸范围
	loaded_chunks[chunk_pos] = true
	

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

# 玩家挖掘信号回调
func _on_player_dig(tile_pos: Vector2i, _direction: String):
	dirt.dig_at(tile_pos)

func _process(_delta):
	# 持续更新区块
	update_chunks()
