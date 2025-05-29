extends Node2D

# === 常量和预加载 ===
const TileSetDataHelper = preload("res://Level/tileset_custom_data.gd")
const MapData = preload("res://Level/map_data.gd")

# === 地图类型枚举(从MapData同步) ===
enum {
	EMPTY = MapData.EMPTY,
	DIRT = MapData.DIRT,
	CHEST1 = MapData.CHEST1,
	CHEST2 = MapData.CHEST2,
	CHEST3 = MapData.CHEST3,
	GROUND = MapData.GROUND,
	BOOM = MapData.BOOM
}

# === 导出变量 ===
@export var noise: FastNoiseLite # 噪声生成器
@export_group("洞穴生成参数")
@export var enable_caves: bool = true # 是否启用洞穴生成
@export_range(0.0, 1.0) var cave_threshold: float = 0.1 # 洞穴生成阈值（越小空洞越多）
@export_range(0.0, 0.1) var depth_factor_rate: float = 0.002 # 深度影响因子（越大深处空洞越多）
@export_range(0.0, 1.0) var max_depth_effect: float = 0.3 # 深度最大影响值

# === 地图尺寸常量 ===
const TILE_SIZE := 64 # 单个瓦片像素大小
const CHUNK_SIZE := 16 # 区块大小（瓦片数）
const LOAD_DISTANCE := 3 # 加载区块距离
const UNLOAD_DISTANCE := 5 # 卸载区块距离
const SCREEN_WIDTH := 1920 # 屏幕宽度

# === TileSet数据 ===
var _layers = {} # 地图层的自定义数据层ID缓存
var atlas_map = {} # 当前地图的图块映射表
var current_map_id = "mine" # 当前地图ID

# === 节点引用 ===
@onready var map := $Map as TileMapLayer
@onready var player := %Player

# === 区块管理 ===
var loaded_chunks = {} # 已加载区块表 {Vector2i: bool}
var current_chunk = Vector2i.ZERO # 当前玩家所在区块

# === 地图初始化 ===
func _ready() -> void:
	_configure_noise()
	player.dig.connect(_on_player_dig)
	
	# 异步初始化地图，确保tileset完全加载后再开始地图生成
	await set_current_map(current_map_id)
	_init_map_loading()

# === 噪声配置 ===
func _configure_noise() -> void:
	if not noise:
		noise = FastNoiseLite.new()
	
	# 配置噪声参数
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi() # 使用随机种子
	noise.frequency = 0.03
	noise.fractal_octaves = 2
	noise.fractal_gain = 0.4

# === 地图加载 ===
func set_current_map(map_id: String) -> void:
	current_map_id = map_id
	Global.current_map_id = map_id
	print("[World] 设置当前地图为: ", map_id)
	await _load_map_config(map_id)

func _init_map_loading() -> void:
	if Global.has_existing_mine:
		_load_cached_chunks()
		player.global_position = Global.player_last_mine_position
	else:
		# 先生成地形
		update_chunks()
		
		# 设置玩家初始位置在地面以上
		var ground_pos = Vector2.ZERO
		# ground_pos.y = -128
		ground_pos.x = -100
		player.global_position = ground_pos
		
		Global.has_existing_mine = true

func _load_map_config(map_id: String) -> void:
	for map_name in MapData.MAPS:
		var map_data = MapData.MAPS[map_name]
		if map_data.id == map_id:
			await _configure_tileset(map_data)
			break

# === TileSet配置 ===
func _configure_tileset(map_data: Dictionary) -> void:
	atlas_map = map_data.atlas_map.duplicate()
	print("[World] 设置atlas_map: ", atlas_map)
	
	var new_tileset = map_data.tilemap.duplicate(true)
	if new_tileset:
		await _setup_tilesets(new_tileset)
	else:
		push_error("[World] 无法克隆tileset!")

func _setup_tilesets(new_tileset) -> void:
	map.tile_set = new_tileset
	
	# 等待加载完成
	await get_tree().process_frame
	await get_tree().process_frame
	
	if _validate_tilesets():
		_init_custom_data_layers()
		print("[World] Tileset完全初始化完成")
	else:
		push_error("[World] Tileset验证失败!")

# === 自定义数据层管理 ===
func get_custom_data_layers() -> Dictionary:
	if not map.tile_set:
		push_error("[World] map tileset 未初始化!")
		return {}
		
	if _layers and _layers.has("health_id") and _layers.has("value_id"):
		print("[World] 使用缓存的数据层: ", _layers)
		return _layers
		
	print("[World] 尝试重新获取自定义数据层...")
	
	# 直接尝试获取数据层，不依赖验证
	var layers = {}
	for i in range(map.tile_set.get_custom_data_layers_count()):
		var layer_name = map.tile_set.get_custom_data_layer_name(i)
		if layer_name == "health":
			layers["health_id"] = i
		elif layer_name == "value":
			layers["value_id"] = i
	
	if layers.has("health_id") and layers.has("value_id"):
		_layers = layers
		print("[World] 成功获取数据层: ", layers)
		return layers
	else:
		print("[World] 数据层数量: ", map.tile_set.get_custom_data_layers_count())
		print("[World] 数据层不完整，尝试重新初始化: ", layers)
		# 如果数据层不完整，尝试重新初始化
		_init_custom_data_layers()
		
		# 重新尝试获取
		layers = {}
		for i in range(map.tile_set.get_custom_data_layers_count()):
			var layer_name = map.tile_set.get_custom_data_layer_name(i)
			if layer_name == "health":
				layers["health_id"] = i
			elif layer_name == "value":
				layers["value_id"] = i
		
		if layers.has("health_id") and layers.has("value_id"):
			_layers = layers
			print("[World] 重新初始化后成功获取数据层: ", layers)
			return layers
	
	print("[World] 最终获取数据层失败")
	return {}

# === 验证函数 ===
func _validate_tilesets() -> bool:
	if not map.tile_set:
		push_error("[World] tileset加载失败!")
		return false
		
	var map_source_count = map.tile_set.get_source_count()
	if map_source_count == 0:
		push_error("[World] tileset没有任何源!")
		return false
		
	print("[World] tileset加载成功，map源数量: ", map_source_count)
	return true

# === 自定义数据层初始化 ===
func _init_custom_data_layers() -> void:
	_layers = TileSetCustomData.init_custom_data(map.tile_set)
	
	if _layers.is_empty():
		push_error("[World] 初始化tileset数据层失败!")
		_layers = TileSetCustomData.init_custom_data(map.tile_set)
		if _layers.is_empty():
			push_error("[World] 初始化tileset数据层第二次尝试也失败!")
			return
			
	print("[World] 成功初始化tileset和数据层")

# === 区块生成与管理 ===
func generate_chunk(chunk_pos: Vector2i) -> void:
	if loaded_chunks.has(chunk_pos):
		return
		
	if _try_load_from_cache(chunk_pos):
		return
		
	_generate_new_chunk(chunk_pos)

func _try_load_from_cache(chunk_pos: Vector2i) -> bool:
	if Global.loaded_chunks_cache.has(chunk_pos):
		var source_id = _get_valid_source_id()
		if source_id != -1:
			var chunk_data = Global.loaded_chunks_cache[chunk_pos]
			_load_chunk_data(chunk_pos, source_id, chunk_data)
			return true
	return false

func _load_chunk_data(_chunk_pos: Vector2i, source_id: int, chunk_data: Dictionary) -> void:
	for pos in chunk_data:
		var tile_info = chunk_data[pos]
		map.set_cell(pos, source_id, tile_info.atlas_coords)
		var tile_data = map.get_cell_tile_data(pos)
		if tile_data and _layers:
			# 验证自定义数据层是否存在
			var tileset = map.tile_set
			if tileset and tileset.get_custom_data_layers_count() > 0:
				var health_id = _layers.get("health_id", -1)
				var value_id = _layers.get("value_id", -1)
				# 确保layer_id在有效范围内
				if health_id >= 0 and health_id < tileset.get_custom_data_layers_count():
					tile_data.set_custom_data_by_layer_id(health_id, tile_info.health)
				if value_id >= 0 and value_id < tileset.get_custom_data_layers_count():
					tile_data.set_custom_data_by_layer_id(value_id, tile_info.value)

func _generate_new_chunk(chunk_pos: Vector2i) -> void:
	var layers = get_custom_data_layers()
	if layers.is_empty():
		push_error("[World] 无法获取自定义数据层,跳过区块生成: ", chunk_pos)
		return
		
	var chunk_data = {}
	
	# 生成区块内的每个瓦片
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var world_x = chunk_pos.x * CHUNK_SIZE + x
			var world_y = chunk_pos.y * CHUNK_SIZE + y
			var pos = Vector2i(world_x, world_y)
			
			# 地表层生成逻辑
			if world_y == 0:
				_generate_ground_tile(pos, layers)
				_save_tile_to_cache(chunk_data, pos, GROUND, 1, 1)
			else:
				_generate_underground_tile(pos, world_y)
				var tile_type = _get_tile_type_at(pos, world_y)
				if tile_type != EMPTY:
					var health = _get_tile_health(tile_type)
					var value = _get_tile_value(tile_type)
					_save_tile_to_cache(chunk_data, pos, tile_type, health, value)
	
	# 缓存生成的区块数据
	if not chunk_data.is_empty():
		Global.loaded_chunks_cache[chunk_pos] = chunk_data
	
	loaded_chunks[chunk_pos] = true

func _generate_ground_tile(pos: Vector2i, layers: Dictionary) -> void:
	var source_id = _get_valid_source_id()
	if source_id != -1:
		map.set_cell(pos, source_id, atlas_map[GROUND])
		var tile_data = map.get_cell_tile_data(pos)
		if tile_data and layers.has("health_id") and layers.has("value_id"):
			# 验证自定义数据层是否存在
			var tileset = map.tile_set
			if tileset and tileset.get_custom_data_layers_count() > 0:
				var health_id = layers["health_id"]
				var value_id = layers["value_id"]
				# 确保layer_id在有效范围内
				if health_id >= 0 and health_id < tileset.get_custom_data_layers_count():
					tile_data.set_custom_data_by_layer_id(health_id, 1)
				if value_id >= 0 and value_id < tileset.get_custom_data_layers_count():
					tile_data.set_custom_data_by_layer_id(value_id, 1)
			tile_data.set_custom_data_by_layer_id(layers["value_id"], 1)

func _generate_underground_tile(pos: Vector2i, world_y: int) -> void:
	var should_generate = _should_generate_block(world_y, pos)
	
	if should_generate:
		var source_id = _get_valid_source_id()
		if source_id != -1:
			_create_block(pos, source_id, world_y)

func _create_block(pos: Vector2i, source_id: int, world_y: int) -> void:
	# 确定生成什么类型的方块
	var block_type = _determine_block_type(world_y, pos)
	var health = _get_tile_health(block_type)
	var value = _get_tile_value(block_type)
	
	map.set_cell(pos, source_id, atlas_map[block_type])
	var tile_data = map.get_cell_tile_data(pos)
	if tile_data and _layers:
		# 验证自定义数据层是否存在
		var tileset = map.tile_set
		if tileset and tileset.get_custom_data_layers_count() > 0:
			var health_id = _layers.get("health_id", -1)
			var value_id = _layers.get("value_id", -1)
			# 确保layer_id在有效范围内
			if health_id >= 0 and health_id < tileset.get_custom_data_layers_count():
				tile_data.set_custom_data_by_layer_id(health_id, health)
			if value_id >= 0 and value_id < tileset.get_custom_data_layers_count():
				tile_data.set_custom_data_by_layer_id(value_id, value)

func _determine_block_type(world_y: int, _pos: Vector2i) -> int:
	# 基于深度和随机性决定方块类型
	var rand_val = randf()
	var depth_factor = min(world_y / 30.0, 1.0) # 调整深度因子，使深度影响更快显现
	
	# 调整生成概率：大幅增加炸弹数量，大幅减少宝箱数量
	if rand_val < 0.006 + depth_factor * 0.01: # 炸弹生成概率翻倍
		return BOOM
	# 宝箱生成概率减半
	elif rand_val < 0.001 + depth_factor * 0.0005: # 高级宝箱
		return CHEST3
	elif rand_val < 0.0035 + depth_factor * 0.001: # 中级宝箱
		return CHEST2
	elif rand_val < 0.0075 + depth_factor * 0.0015: # 低级宝箱
		return CHEST1
	else:
		return DIRT

func _get_tile_health(tile_type: int) -> int:
	match tile_type:
		DIRT: return 1
		CHEST1: return 2
		CHEST2: return 3
		CHEST3: return 4
		BOOM: return 1
		GROUND: return 1
		_: return 1

func _get_tile_value(tile_type: int) -> int:
	match tile_type:
		DIRT: return 1
		CHEST1: return 5
		CHEST2: return 10
		CHEST3: return 20
		BOOM: return 96 # 爆炸半径
		GROUND: return 1
		_: return 1

func _get_tile_type_at(pos: Vector2i, world_y: int) -> int:
	if not _should_generate_block(world_y, pos):
		return EMPTY
	return _determine_block_type(world_y, pos)

# === 方块生成逻辑 ===
func _should_generate_block(world_y: int, pos: Vector2i = Vector2i.ZERO) -> bool:
	# 地表以上不生成方块
	if world_y < 0:
		return false
		
	# 地表到浅层（3格以内）总是生成方块
	if world_y <= 1:
		return true
		
	# 生成小空洞逻辑
	if enable_caves and noise:
		# 使用更小的噪声尺度来生成更多空洞
		var noise_scale = 0.9 # 增加噪声频率，使变化更快
		
		# 获取噪声值（范围在0-1之间）
		var noise_value = (noise.get_noise_2d(pos.x * noise_scale, pos.y * noise_scale) + 1.0) * 0.5
		
		# 添加适量随机性
		randomize()
		noise_value += randf_range(-0.08, 0.08) # 增加随机性范围
		noise_value = clamp(noise_value, 0.0, 1.0)
		
		# 基础阈值 - 增加这个值会增加空洞
		var threshold = 0.5 # 提高阈值，增加空洞
		
		# 深度影响 - 减小深度对空洞生成的影响
		var depth = min(100.0, float(world_y))
		var depth_factor = min(max_depth_effect * 0.3, depth * depth_factor_rate * 0.3) # 减小深度影响
		
		# 调整阈值 - 使空洞更少
		var adjusted_threshold = threshold - depth_factor
		
		# 输出调试信息（可以注释掉）
		#if world_y % 20 == 0 and pos.x == 0:
		#	print("Depth: ", world_y, " threshold: ", adjusted_threshold, " noise: ", noise_value)
		
		# 如果噪声值大于阈值，生成方块；否则生成空洞
		return noise_value > adjusted_threshold
		
	return true

func _save_tile_to_cache(chunk_data: Dictionary, pos: Vector2i, tile_type: int, health: int, value: int) -> void:
	chunk_data[pos] = {
		"atlas_coords": atlas_map[tile_type],
		"health": health,
		"value": value
	}

# === 区块更新系统 ===
func update_chunks() -> void:
	var player_chunk = world_to_chunk(player.global_position)
	
	if player_chunk != current_chunk:
		current_chunk = player_chunk
		_load_surrounding_chunks()
		_unload_distant_chunks()

func _load_surrounding_chunks() -> void:
	for x in range(-LOAD_DISTANCE, LOAD_DISTANCE + 1):
		for y in range(-LOAD_DISTANCE, LOAD_DISTANCE + 1):
			var chunk_pos = current_chunk + Vector2i(x, y)
			if not loaded_chunks.has(chunk_pos):
				generate_chunk(chunk_pos)

func _unload_distant_chunks() -> void:
	var chunks_to_unload = []
	for chunk_pos in loaded_chunks:
		var distance = max(abs(chunk_pos.x - current_chunk.x),
						  abs(chunk_pos.y - current_chunk.y))
		if distance > UNLOAD_DISTANCE:
			chunks_to_unload.append(chunk_pos)
	
	for chunk_pos in chunks_to_unload:
		_unload_chunk(chunk_pos)

func _unload_chunk(chunk_pos: Vector2i) -> void:
	# 清除视觉瓦片
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var world_x = chunk_pos.x * CHUNK_SIZE + x
			var world_y = chunk_pos.y * CHUNK_SIZE + y
			var pos = Vector2i(world_x, world_y)
			map.erase_cell(pos)
	
	loaded_chunks.erase(chunk_pos)

# === 缓存管理 ===
func _load_cached_chunks() -> void:
	print("[World] 正在加载缓存的区块数据...")
	var source_id = _get_valid_source_id()
	if source_id == -1:
		push_error("[World] 无法找到有效的tileset源！缓存加载失败")
		return
	
	var layers = get_custom_data_layers()
	if layers.is_empty():
		push_error("[World] 无法获取自定义数据层ID，缓存加载失败!")
		return
	
	for chunk_pos in Global.loaded_chunks_cache:
		var chunk_data = Global.loaded_chunks_cache[chunk_pos]
		_load_chunk_data(chunk_pos, source_id, chunk_data)

# === 工具函数 ===
func world_to_chunk(world_pos: Vector2) -> Vector2i:
	var tile_pos = map.local_to_map(map.to_local(world_pos))
	return Vector2i(floor(tile_pos.x / float(CHUNK_SIZE)),
				   floor(tile_pos.y / float(CHUNK_SIZE)))

func is_valid_tileset() -> bool:
	if not map.tile_set:
		push_error("TileMap没有设置tileset!")
		return false
		
	var source_id = _get_valid_source_id()
	return source_id != -1

func _get_valid_source_id() -> int:
	var source_count = map.tile_set.get_source_count()
	for i in range(source_count):
		var source_id = map.tile_set.get_source_id(i)
		if map.tile_set.get_source(source_id):
			return source_id
	return -1

# === 信号回调 ===
func _on_player_dig(tile_pos: Vector2i, _direction: String) -> void:
	# 单层系统中直接在map层上挖掘
	await map.dig_at(tile_pos)

func _process(_delta: float) -> void:
	update_chunks()
