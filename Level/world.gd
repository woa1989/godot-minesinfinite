extends Node2D

# 载入自定义数据助手
const TileSetDataHelper = preload("res://Level/tileset_custom_data.gd")
const MapData = preload("res://Level/map_data.gd")

@export var noise: FastNoiseLite
@export_group("洞穴生成参数")
@export var enable_caves: bool = true # 是否启用洞穴生成
@export_range(0.0, 1.0) var cave_threshold: float = 0.3 # 洞穴生成阈值（越小空洞越多）
@export_range(0.0, 0.1) var depth_factor_rate: float = 0.0005 # 深度影响因子（越大深处空洞越多）
@export_range(0.0, 1.0) var max_depth_effect: float = 0 # 深度最大影响值

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

# 自定义数据层
var _layers = {} # 存储dirt层的自定义数据层ID
var _props_layers = {} # 存储props层的自定义数据层ID

@onready var dirt := $Dirt as TileMapLayer # 地形TileMap
@onready var props := $Props as TileMapLayer # 道具TileMap
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
			
			# 首先设置atlas_map
			atlas_map = map_data.atlas_map.duplicate()
			print("[World] 设置atlas_map: ", atlas_map)
			print("[World] 炸药坐标: ", atlas_map[BOOM])
			
			# 克隆tileset并确保它是完整的副本
			var new_tileset = map_data.tilemap.duplicate(true)
			if not new_tileset:
				push_error("[World] 无法克隆tileset!")
				return
			
			# 为dirt和props层设置相同的tileset
			dirt.tile_set = new_tileset
			props.tile_set = new_tileset.duplicate(true) # 为props创建独立的副本
			
			# 等待两个帧以确保tileset加载完成
			await get_tree().process_frame
			await get_tree().process_frame
			
			# 验证两个tileset是否有效
			if not dirt.tile_set or not props.tile_set:
				push_error("[World] tileset加载失败!")
				return
			
			# 检查是否有任何可用的源ID
			var dirt_source_count = dirt.tile_set.get_source_count()
			var props_source_count = props.tile_set.get_source_count()
			if dirt_source_count == 0 or props_source_count == 0:
				push_error("[World] tileset没有任何源!")
				return
			
			print("[World] tileset加载成功，dirt源数量: ", dirt_source_count, ", props源数量: ", props_source_count)
			
			# 为两个层都初始化自定义数据层
			_layers = TileSetDataHelper.init_custom_data(dirt.tile_set)
			var props_layers = TileSetDataHelper.init_custom_data(props.tile_set)
			
			if _layers.is_empty() or props_layers.is_empty():
				push_error("[World] 初始化tileset数据层失败!")
				# 尝试再次初始化
				_layers = TileSetDataHelper.init_custom_data(dirt.tile_set)
				props_layers = TileSetDataHelper.init_custom_data(props.tile_set)
				
				if _layers.is_empty() or props_layers.is_empty():
					push_error("[World] 初始化tileset数据层第二次尝试也失败!")
					return
			
			# 保存props的自定义数据层ID
			_props_layers = props_layers
			
			print("[World] 成功初始化两个tileset和数据层")
			print("[World] dirt layers: ", _layers)
			print("[World] props layers: ", _props_layers)
			
			# 验证地图配置
			if not validate_map_config():
				push_error("[World] 地图配置验证失败!")
				return
			
			break

func _ready() -> void:
	# 初始化噪声对象（如果未设置）
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi() # 随机种子
		noise.frequency = 0.03 # 调整噪声频率，降低频率使洞穴更大更少
		noise.fractal_octaves = 2 # 设置分形噪声的八度数，降低值使洞穴形态更简单
		noise.fractal_lacunarity = 2.0 # 设置分形噪声的频率增益
		noise.fractal_gain = 0.4 # 设置分形噪声的振幅增益，降低增益使分布更均匀
		print("[World] 已初始化默认噪声配置")
	
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

# 新增：重新配置噪声参数
func configure_noise(new_seed: int = -1, freq: float = 0.05, octaves: int = 4,
					lac: float = 2.0, gain: float = 0.5) -> void:
	if not noise:
		noise = FastNoiseLite.new()
	
	# 如果seed为-1，使用随机种子
	if new_seed == -1:
		new_seed = randi()
	
	# 配置噪声参数
	noise.seed = new_seed
	noise.frequency = freq
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lac
	noise.fractal_gain = gain
	
	print("[World] 噪声参数已重新配置:")
	print("- 种子: ", new_seed)
	print("- 频率: ", freq)
	print("- 八度: ", octaves)
	print("- 频率增益: ", lac)
	print("- 振幅增益: ", gain)

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
		push_error("[World] dirt tileset 未初始化!")
		return layers
		
	# 如果已经有缓存的数据层ID，直接返回它
	if _layers and _layers.has("health_id") and _layers.has("value_id"):
		return _layers
		
	# 先尝试验证现有数据层
	if TileSetDataHelper.validate_custom_data(dirt.tile_set):
		# 如果验证通过，直接获取层ID
		for i in range(dirt.tile_set.get_custom_data_layers_count()):
			var layer_name = dirt.tile_set.get_custom_data_layer_name(i)
			if layer_name == "health":
				layers["health_id"] = i
			elif layer_name == "value":
				layers["value_id"] = i
		
		# 缓存获取到的层ID
		if layers.has("health_id") and layers.has("value_id"):
			_layers = layers.duplicate()
			print("[World] 使用现有的自定义数据层: ", layers)
			return layers
	
	# 如果验证失败，则初始化数据层
	push_warning("[World] 自定义数据层验证失败，尝试初始化...")
	
	# 第一次尝试初始化
	var result = TileSetDataHelper.init_custom_data(dirt.tile_set)
	if result and result.has("health_id") and result.has("value_id"):
		print("[World] 成功初始化自定义数据层: ", result)
		_layers = result.duplicate()
		return result
	
	# 再试一次，有时第一次初始化可能不成功
	print("[World] 第一次初始化失败，再次尝试...")
	result = TileSetDataHelper.init_custom_data(dirt.tile_set)
	if result and result.has("health_id") and result.has("value_id"):
		print("[World] 第二次尝试成功初始化自定义数据层: ", result)
		_layers = result.duplicate()
		return result
	
	push_error("[World] 无法初始化自定义数据层!")
	return {}

# 生成单个瓦片
func generate_tile(pos: Vector2i, layers: Dictionary):
	var world_y = pos.y
	var world_x = pos.x
	
	# 右边界不生成墙壁
	var is_right_edge = (world_x > 0 and world_x % (CHUNK_SIZE * 10) == (CHUNK_SIZE * 10) - 1)
	if is_right_edge:
		return
		
	# 地面上方不生成
	if world_y < 0:
		return
		
	# 获取有效的源ID
	var source_id = dirt.tile_set.get_source_id(0)
	
	# 地面层生成GROUND
	if world_y == 0:
		dirt.set_cell(pos, source_id, atlas_map[GROUND])
		var tile_data = dirt.get_cell_tile_data(pos)
		if tile_data and layers.has("health_id") and layers.has("value_id"):
			tile_data.set_custom_data_by_layer_id(layers["health_id"], 1)
			tile_data.set_custom_data_by_layer_id(layers["value_id"], 1)
	# 地下生成内容
	else:
		var should_generate_block = true
		
		# 如果启用了洞穴生成，使用噪声决定是否生成土块
		if enable_caves and noise:
			# 使用简单的噪声值判断,不需要取绝对值
			var noise_value = (noise.get_noise_2d(world_x, world_y) + 1) * 0.5
			
			# 计算深度影响
			var depth = min(50, world_y)
			var depth_factor = min(max_depth_effect, depth * depth_factor_rate)
			
			# 调整阈值
			var threshold = cave_threshold - depth_factor
			
			# 当噪声值小于阈值时不生成方块(形成洞穴)
			should_generate_block = noise_value > threshold
			
			# 顶部5层总是生成方块
			if world_y <= 5:
				should_generate_block = true
		
		# 如果应该生成方块
		if should_generate_block:
			create_dirt_block(pos, source_id, randf(), world_y)

# 生成单个土块
func create_dirt_block(pos: Vector2i, source_id: int, rand_val: float, world_y: int) -> void:
	dirt.set_cell(pos, source_id, atlas_map[DIRT])
	var tile_data = dirt.get_cell_tile_data(pos)
	if tile_data and _layers and _layers.has("health_id") and _layers.has("value_id"):
		tile_data.set_custom_data_by_layer_id(_layers["health_id"], 1)
		tile_data.set_custom_data_by_layer_id(_layers["value_id"], 1)
		
	# 在已有土块的位置上考虑生成特殊方块
	if world_y > 5 and rand_val > 0.99:
		generate_chest(pos, _layers, rand_val)
	elif world_y > 3 and rand_val > 0.97:
		generate_boom(pos, _layers)

# 生成宝箱
func generate_chest(pos: Vector2i, _unused_layers: Dictionary, rand_val: float):
	var chest_type = CHEST1
	var chest_health = 3 # 统一设置为3血
	var chest_value = 50

	if rand_val > 0.95:
		chest_type = CHEST3
		chest_value = 200
	elif rand_val > 0.8:
		chest_type = CHEST2
		chest_value = 100

	# 确保props的tileset有效
	if not props.tile_set:
		push_error("[World] props tileset未初始化!")
		return
		
	# 如果_props_layers没有初始化，尝试重新初始化
	if not _props_layers or not _props_layers.has("health_id") or not _props_layers.has("value_id"):
		push_warning("[World] props的自定义数据层不完整，尝试重新初始化...")
		var props_layers = TileSetDataHelper.init_custom_data(props.tile_set)
		if props_layers and not props_layers.is_empty():
			_props_layers = props_layers
			print("[World] 成功重新初始化props的自定义数据层: ", _props_layers)
		else:
			push_error("[World] props tileset自定义数据层初始化失败!")
			return

	# 获取有效的源ID
	var source_id = 0
	var source_count = props.tile_set.get_source_count()
	if source_count > 0:
		source_id = props.tile_set.get_source_id(0)
	else:
		push_error("[World] 无法获取props tileset的有效源ID!")
		return

	props.set_cell(pos, source_id, atlas_map[chest_type])
	var tile_data = props.get_cell_tile_data(pos)
	if tile_data:
		# 设置自定义数据
		tile_data.set_custom_data_by_layer_id(_props_layers["health_id"], chest_health)
		tile_data.set_custom_data_by_layer_id(_props_layers["value_id"], chest_value)
		print("[World] 成功设置宝箱瓦片，类型:", chest_type, "，ID:", pos)
	else:
		push_error("[World] 无法设置宝箱数据: 获取tile_data失败")

# 生成炸药
func generate_boom(pos: Vector2i, _unused_layers: Dictionary):
	# 确保props的tileset有自定义数据层
	if not props.tile_set:
		push_error("[World] props tileset未初始化!")
		return
		
	# 如果_props_layers没有初始化，尝试重新初始化
	if not _props_layers or not _props_layers.has("health_id") or not _props_layers.has("value_id"):
		push_warning("[World] props的自定义数据层不完整，尝试重新初始化...")
		var props_layers = TileSetDataHelper.init_custom_data(props.tile_set)
		if props_layers and not props_layers.is_empty():
			_props_layers = props_layers
			print("[World] 成功重新初始化props的自定义数据层: ", _props_layers)
		else:
			push_error("[World] props tileset自定义数据层初始化失败!")
			return
		
	# 获取有效的源ID
	var source_id = 0
	var source_count = props.tile_set.get_source_count()
	if source_count > 0:
		source_id = props.tile_set.get_source_id(0)
	else:
		push_error("[World] 无法获取props tileset的有效源ID!")
		return
		
	# 设置炸药瓦片
	props.set_cell(pos, source_id, atlas_map[BOOM])
	var tile_data = props.get_cell_tile_data(pos)
	if tile_data:
		tile_data.set_custom_data_by_layer_id(_props_layers["health_id"], 1) # 生命值设为1
		tile_data.set_custom_data_by_layer_id(_props_layers["value_id"], 64) # 爆炸范围设置为64
		print("[World] 成功设置炸药瓦片，ID:", pos)
	else:
		push_error("[World] 无法获取tile_data!")

# 保存所有已加载区块到缓存
func save_chunks_to_cache():
	Global.loaded_chunks_cache.clear()
	# 确保保存到正确的地图缓存中
	MapData.MAPS_CHUNKS[current_map_id] = loaded_chunks.duplicate()
	
	# 获取自定义数据层ID
	var layers = get_custom_data_layers()
	if not layers:
		push_error("[World] 无法获取自定义数据层ID，缓存保存失败!")
		return
	
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
					var health = tile_data.get_custom_data_by_layer_id(layers.health_id)
					var value = tile_data.get_custom_data_by_layer_id(layers.value_id)
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
	
	# 获取自定义数据层ID
	var layers = get_custom_data_layers()
	if not layers:
		push_error("[World] 无法获取自定义数据层ID，缓存加载失败!")
		return
		
	for chunk_pos in Global.loaded_chunks_cache:
		var chunk_data = Global.loaded_chunks_cache[chunk_pos]
		for pos in chunk_data:
			var tile_info = chunk_data[pos]
			dirt.set_cell(pos, source_id, tile_info.atlas_coords)
			var tile_data = dirt.get_cell_tile_data(pos)
			if tile_data:
				tile_data.set_custom_data_by_layer_id(layers.health_id, tile_info.health)
				tile_data.set_custom_data_by_layer_id(layers.value_id, tile_info.value)
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
			props.erase_cell(pos)
	loaded_chunks.erase(chunk_pos)

# 玩家挖掘信号回调
func _on_player_dig(tile_pos: Vector2i, _direction: String):
	# 先检查props层（宝箱、炸药等）
	var props_data = props.get_cell_tile_data(tile_pos)
	if props_data:
		props.dig_at(tile_pos)
	else:
		# 如果props层没有方块，再检查dirt层
		dirt.dig_at(tile_pos)

func _process(_delta):
	# 持续更新区块
	update_chunks()

func validate_map_config() -> bool:
	print("[World] 开始验证地图配置...")
	
	# 验证 dirt 层
	if not dirt or not dirt.tile_set:
		push_error("[World] Dirt层或其tileset无效!")
		return false
	
	# 验证 props 层
	if not props or not props.tile_set:
		push_error("[World] Props层或其tileset无效!")
		return false
	
	# 验证atlas_map配置
	if not atlas_map:
		push_error("[World] atlas_map未初始化!")
		return false
	
	# 验证必要的图块类型
	var required_types = [GROUND, BOOM, CHEST1]
	for type in required_types:
		if not type in atlas_map or not atlas_map[type]:
			push_error("[World] 缺少必要的图块类型: " + str(type))
			return false
			
		# 检查图块坐标格式是否为Vector2i
		if not atlas_map[type] is Vector2i:
			push_error("[World] 图块类型 " + str(type) + " 的坐标格式不正确! 应为Vector2i")
			return false
	
	# 验证自定义数据层
	# 获取自定义数据层ID
	var layers = get_custom_data_layers()
	if not layers:
		push_error("[World] 无法获取自定义数据层ID!")
		return false
	
	for tilemap in [dirt, props]:
		var ts = tilemap.tile_set
		if not ts:
			push_error("[World] Tileset未初始化!")
			return false
			
		if ts.get_source_count() == 0:
			push_error("[World] Tileset没有任何源!")
			return false
			
		# 获取第一个有效的源和图块来检查自定义数据
		var source_id = ts.get_source_id(0)
		if source_id < 0:
			push_error("[World] 无法获取有效的源ID!")
			return false
			
		var source = ts.get_source(source_id)
		if not source:
			push_error("[World] 无法获取源!")
			return false
			
		# 遍历找到第一个有效的图块
		var found_valid_tile = false
		for y in range(16): # 假设图块集不会超过16x16
			for x in range(16):
				var test_pos = Vector2i(x, y)
				if source.has_tile(test_pos):
					var tile_data = source.get_tile_data(test_pos, 0)
					# 尝试通过get_custom_data_by_layer_id检查自定义数据是否存在
					if tile_data:
						var health = tile_data.get_custom_data_by_layer_id(layers["health_id"])
						var value = tile_data.get_custom_data_by_layer_id(layers["value_id"])
						if health != null and value != null:
							found_valid_tile = true
							break
			if found_valid_tile:
				break
				
		if not found_valid_tile:
			push_error("[World] Tileset缺少必要的自定义数据层!")
			return false
	
	print("[World] 地图配置验证通过")
	return true
