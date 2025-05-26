extends Node2D

# 载入自定义数据助手
const TileSetDataHelper = preload("res://Level/tileset_custom_data.gd")
const MapData = preload("res://Level/map_data.gd")

# 从MapData中获取枚举值
enum {EMPTY = MapData.EMPTY, DIRT = MapData.DIRT, CHEST1 = MapData.CHEST1,
	  CHEST2 = MapData.CHEST2, CHEST3 = MapData.CHEST3, GROUND = MapData.GROUND,
	  BOOM = MapData.BOOM}

var atlas_map = {} # 当前地图的图块映射
var current_map_id = "mine" # 当前地图ID

# 新增：获取当前地图数据的辅助方法
func get_current_map_data():
	for map_name in MapData.MAPS:
		var map_data = MapData.MAPS[map_name]
		if map_data.id == current_map_id:
			return map_data
	return null

# 地图参数
const TILE_SIZE := 64 # 单个瓦片像素
const CHUNK_SIZE := 16 # 区块大小（瓦片数）
const LOAD_DISTANCE := 3 # 加载玩家周围多少区块
const UNLOAD_DISTANCE := 5 # 超过这个距离的区块会被卸载
const SCREEN_WIDTH := 1920 # 屏幕宽度

@onready var dirt := $Dirt as TileMapLayer # 地形TileMap
@onready var player := %Player # 玩家节点

# 区块管理
var loaded_chunks = {} # 已加载区块 {Vector2i: bool}
var current_chunk = Vector2i.ZERO # 当前玩家所在区块

# 设置当前地图
func set_current_map(map_id: String) -> void:
	print("[World] 设置当前地图为: ", map_id)
	current_map_id = map_id
	if not MapData.MAPS_CHUNKS.has(map_id):
		MapData.MAPS_CHUNKS[map_id] = {}
	loaded_chunks = MapData.MAPS_CHUNKS[map_id]
	
	# 设置正确的atlas_map和tileset
	for map_name in MapData.MAPS:
		var map_data = MapData.MAPS[map_name]
		if map_data.id == map_id:
			print("[World] 找到地图数据: ", map_name)
			print("[World] 找到地图数据: ", map_name)
			
			# 首先设置atlas_map
			atlas_map = map_data.atlas_map.duplicate()
			print("[World] 设置atlas_map: ", atlas_map)
			print("[World] 炸药坐标: ", atlas_map[BOOM])
			
			# 克隆tileset并确保它是完整的副本
			var new_tileset = map_data.tilemap.duplicate(true)
			if not new_tileset:
				push_error("[World] 无法克隆tileset!")
				return
				
			# 设置tileset并等待它加载
			dirt.tile_set = new_tileset
			await get_tree().process_frame
			await get_tree().process_frame
			
			# 验证tileset是否有效
			if not dirt.tile_set:
				push_error("[World] tileset加载失败!")
				return
				
			# 检查是否有任何可用的源ID
			var source_count = dirt.tile_set.get_source_count()
			if source_count == 0:
				push_error("[World] tileset没有任何源!")
				return
				
			print("[World] tileset加载成功，源数量: ", source_count)
			
			# 初始化自定义数据层
			var result = TileSetDataHelper.init_custom_data(dirt.tile_set)
			if not result:
				push_error("[World] 初始化tileset数据层失败!")
				return
				
			print("[World] 成功初始化tileset和数据层")
			
			# 验证地图配置
			if not validate_map_config():
				push_error("[World] 地图配置验证失败!")
				return
				
			break

func _ready() -> void:
	# 初始化当前地图的区块数据
	await set_current_map(current_map_id)
	
	# 连接玩家挖掘信号
	player.dig.connect(_on_player_dig)
	
	# 如果已有缓存的地图，则加载它
	if Global.has_existing_mine:
		await load_cached_chunks()
		player.global_position = Global.player_last_mine_position
	else:
		# 初始加载区块
		update_chunks()
		Global.has_existing_mine = true

# 生成单个区块
func generate_chunk(chunk_pos: Vector2i):
	if loaded_chunks.has(chunk_pos):
		return
		
	# 确保有tileset并且有效
	if not is_valid_tileset():
		return
		
	# 如果缓存中有这个区块，就从缓存加载
	if Global.loaded_chunks_cache.has(chunk_pos):
		# 获取有效的源ID
		var source_id = 0
		var source_count = dirt.tile_set.get_source_count()
		if source_count > 0:
			source_id = dirt.tile_set.get_source_id(0)
		else:
			push_error("[World] 无法找到有效的tileset源！区块加载失败")
			return
			
		var chunk_data = Global.loaded_chunks_cache[chunk_pos]
		for pos in chunk_data:
			var tile_info = chunk_data[pos]
			if tile_info.atlas_coords:
				dirt.set_cell(pos, source_id, tile_info.atlas_coords)
				var tile_data = dirt.get_cell_tile_data(pos)
				if tile_data:
					tile_data.set_custom_data("health", tile_info.health)
					tile_data.set_custom_data("value", tile_info.value)
		loaded_chunks[chunk_pos] = true
		return
		
	# 获取数据层
	var custom_data_layers = get_custom_data_layers()
	if not custom_data_layers:
		return
		
	# 生成区块内容
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			generate_tile(Vector2i(start_x + x, start_y + y), custom_data_layers)
			
	loaded_chunks[chunk_pos] = true

# 新增：检查当前炸药块配置
func debug_boom_block():
	print("----------- 炸药块调试信息 -----------")
	print("当前地图ID: ", current_map_id)
	print("当前atlas_map: ", atlas_map)
	if atlas_map.has(BOOM):
		print("炸药块坐标: ", atlas_map[BOOM])
	else:
		print("错误: atlas_map中没有BOOM键")
	
	# 检查tileset是否有效
	var has_valid_source = is_valid_tileset()
	print("TileSet有效: ", has_valid_source)
	print("------------------------------------")

# 检查tileset是否有效
func is_valid_tileset() -> bool:
	if not dirt.tile_set:
		push_error("TileMap没有设置tileset!")
		return false
	
	# 检查是否有任何有效的源
	var has_valid_source = false
	
	# 获取可用的源ID
	var source_count = dirt.tile_set.get_source_count()
	for i in range(source_count):
		var source_id = dirt.tile_set.get_source_id(i)
		if dirt.tile_set.get_source(source_id):
			print("[World] 找到有效的源 ID:", source_id)
			has_valid_source = true
			break
	
	if not has_valid_source:
		push_error("Tileset没有有效的源! 尝试重新加载...")
		# 尝试从map_data重新加载
		for map_name in MapData.MAPS:
			var map_data = MapData.MAPS[map_name]
			if map_data.id == current_map_id:
				# 克隆tileset以确保获得完整的副本
				var new_tileset = map_data.tilemap.duplicate(true)
				if new_tileset and new_tileset.get_source_count() > 0:
					dirt.tile_set = new_tileset
					print("[World] 成功重新加载tileset")
					return true
				break
		push_error("无法加载有效的tileset!")
		return false
	
	return true

# 获取自定义数据层
func get_custom_data_layers() -> Dictionary:
	var layers = {}
	if not dirt.tile_set:
		return layers
		
	for i in range(dirt.tile_set.get_custom_data_layers_count()):
		var layer_name = dirt.tile_set.get_custom_data_layer_name(i)
		layers[layer_name] = i
	
	var health_layer = layers.get("health", -1)
	var value_layer = layers.get("value", -1)
	
	if health_layer == -1 or value_layer == -1:
		var result = TileSetDataHelper.init_custom_data(dirt.tile_set)
		if result:
			health_layer = result.health_id
			value_layer = result.value_id
		else:
			push_error("无法初始化数据层!")
			return {}
	
	return {"health": health_layer, "value": value_layer}

# 生成单个瓦片
func generate_tile(pos: Vector2i, layers: Dictionary):
	var world_y = pos.y
	var world_x = pos.x
	var rand_val = randf()
	
	# 右边界不生成墙壁
	var is_right_edge = (world_x > 0 and world_x % (CHUNK_SIZE * 10) == (CHUNK_SIZE * 10) - 1)
	if is_right_edge:
		return
		
	# 地面上方不生成
	if world_y < 0:
		return
		
	# 地面层生成GROUND
	if world_y == 0:
		# 确保有效的地图源ID
		var source_id = 0
		var source_count = dirt.tile_set.get_source_count()
		if source_count > 0:
			source_id = dirt.tile_set.get_source_id(0)
			
		dirt.set_cell(pos, source_id, atlas_map[GROUND])
		var tile_data = dirt.get_cell_tile_data(pos)
		if tile_data:
			tile_data.set_custom_data_by_layer_id(layers.health, 1)
			tile_data.set_custom_data_by_layer_id(layers.value, 1)
	# 地下生成内容
	else:
		if rand_val < 0.9:
			# 获取有效的源ID
			var source_id = 0
			var source_count = dirt.tile_set.get_source_count()
			if source_count > 0:
				source_id = dirt.tile_set.get_source_id(0)
				
			dirt.set_cell(pos, source_id, atlas_map[DIRT])
			var tile_data = dirt.get_cell_tile_data(pos)
			if tile_data:
				tile_data.set_custom_data_by_layer_id(layers.health, 1) # 土块固定1血量
				tile_data.set_custom_data_by_layer_id(layers.value, 1)
		# 1%概率生成宝箱
		if world_y > 5 and rand_val > 0.99:
			generate_chest(pos, layers, rand_val)
		# 3%概率生成炸药
		elif world_y > 3 and rand_val > 0.97:
			generate_boom(pos, layers)

# 生成宝箱
func generate_chest(pos: Vector2i, layers: Dictionary, rand_val: float):
	var chest_type = CHEST1
	var chest_health = 3 # 统一设置为3血
	var chest_value = 50
	
	if rand_val > 0.95:
		chest_type = CHEST3
		chest_value = 200
	elif rand_val > 0.8:
		chest_type = CHEST2
		chest_value = 100
	
	# 获取有效的源ID
	var source_id = 0
	var source_count = dirt.tile_set.get_source_count()
	if source_count > 0:
		source_id = dirt.tile_set.get_source_id(0)
		
	dirt.set_cell(pos, source_id, atlas_map[chest_type])
	var tile_data = dirt.get_cell_tile_data(pos)
	if tile_data:
		tile_data.set_custom_data_by_layer_id(layers.health, chest_health)
		tile_data.set_custom_data_by_layer_id(layers.value, chest_value)

# 生成炸药
func generate_boom(pos: Vector2i, layers: Dictionary):
	# 获取有效的源ID
	var source_id = 0
	var source_count = dirt.tile_set.get_source_count()
	if source_count > 0:
		source_id = dirt.tile_set.get_source_id(0)
		
	dirt.set_cell(pos, source_id, atlas_map[BOOM])
	var tile_data = dirt.get_cell_tile_data(pos)
	if tile_data:
		tile_data.set_custom_data_by_layer_id(layers.health, 1) # 生命值设为1
		tile_data.set_custom_data_by_layer_id(layers.value, 64) # 爆炸范围设置为1格

# 保存所有已加载区块到缓存
func save_chunks_to_cache():
	Global.loaded_chunks_cache.clear()
	# 确保保存到正确的地图缓存中
	MapData.MAPS_CHUNKS[current_map_id] = loaded_chunks.duplicate()
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
	
	# 获取有效的源ID
	var source_id = 0
	var source_count = dirt.tile_set.get_source_count()
	if source_count > 0:
		source_id = dirt.tile_set.get_source_id(0)
	else:
		push_error("[World] 无法找到有效的tileset源！缓存加载失败")
		return
		
	for chunk_pos in Global.loaded_chunks_cache:
		var chunk_data = Global.loaded_chunks_cache[chunk_pos]
		for pos in chunk_data:
			var tile_info = chunk_data[pos]
			dirt.set_cell(pos, source_id, tile_info.atlas_coords)
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

# 验证地图配置
func validate_map_config():
	print("[World] 验证当前地图配置...")
	
	# 1. 检查atlas_map是否正确设置
	if atlas_map.is_empty():
		push_error("[World] atlas_map为空!")
		return false
		
	# 2. 检查炸药块配置
	if not atlas_map.has(BOOM):
		push_error("[World] atlas_map中没有炸药块配置!")
		return false
	
	# 3. 检查tileset是否已设置
	if not is_valid_tileset():
		push_error("[World] TileSet无效!")
		return false
		
	# 4. 检查自定义数据层
	var layers = TileSetDataHelper.get_custom_data_layer_ids(dirt.tile_set)
	if not layers or layers.health < 0 or layers.value < 0:
		push_error("[World] 自定义数据层缺失!")
		return false
		
	print("[World] 地图配置验证通过!")
	return true
