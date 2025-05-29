extends Node2D

# === 常量和预加载 ===
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
@export_range(0.1, 1.0) var cave_threshold := 0.3 # 洞穴生成阈值（越小洞穴越多，参考demo默认0.25）
@export_range(0.0, 0.1) var depth_factor_rate: float = 0.005 # 深度影响系数（每层增加洞穴概率）

# === 缓存系统 ===
var chunk_cave_cache := {} # 缓存每个区块的洞穴数据

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
	set_current_map(current_map_id)
	player.dig.connect(_on_player_dig)
	_init_map_loading()

# === 噪声配置 ===
func _configure_noise() -> void:
	if not noise:
		noise = FastNoiseLite.new()
	
	# 确保 noise_seed 持久化
	if not Global.has_existing_mine:
		# 仅在第一次生成地图时设置新的随机种子
		Global.noise_seed = randi()
		print("[World] 为新地图生成噪声种子:", Global.noise_seed)
	else:
		print("[World] 使用已存在的噪声种子:", Global.noise_seed)
	
	# 配置噪声参数
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = Global.noise_seed # 使用持久化的种子
	noise.frequency = 0.1
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

# === 地图加载 ===
func set_current_map(map_id: String) -> void:
	current_map_id = map_id
	Global.current_map_id = map_id
	print("[World] 设置当前地图为: ", map_id)
	_load_map_config(map_id)

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
			_configure_tileset(map_data)
			break

# === TileSet配置 ===
func _configure_tileset(map_data: Dictionary) -> void:
	atlas_map = map_data.atlas_map.duplicate()
	print("[World] 设置atlas_map: ", atlas_map)
	
	var new_tileset = map_data.tilemap.duplicate(true)
	if new_tileset:
		_setup_tilesets(new_tileset)
	else:
		push_error("[World] 无法克隆tileset!")

func _setup_tilesets(new_tileset) -> void:
	print("[World] 开始设置tileset...")
	map.tile_set = new_tileset
	print("[World] tileset已设置到map")
	
	# 简化初始化流程，直接初始化自定义数据层
	_init_custom_data_layers()
	
	if _validate_tilesets():
		print("[World] tileset初始化和验证成功")
	else:
		push_error("[World] TileSet验证失败，但继续运行")

# === 自定义数据层管理 ===
func get_custom_data_layers() -> Dictionary:
	if not map.tile_set:
		push_error("[World] map tileset 未初始化!")
		return {}
		
	if _layers and _layers.has("health_id") and _layers.has("value_id"):
		# 验证缓存的layer_id是否仍然有效
		var tileset = map.tile_set
		var health_id = _layers["health_id"]
		var value_id = _layers["value_id"]
		if tileset.get_custom_data_layers_count() > max(health_id, value_id):
			print("[World] 使用缓存的数据层: ", _layers)
			return _layers
		else:
			print("[World] 缓存的数据层无效，重新获取...")
			_layers = {}
		
	print("[World] 尝试重新获取自定义数据层...")
	
	# 直接尝试获取数据层，不依赖验证
	var layers = {}
	var layer_count = map.tile_set.get_custom_data_layers_count()
	print("[World] TileSet自定义数据层数量: ", layer_count)
	
	for i in range(layer_count):
		var layer_name = map.tile_set.get_custom_data_layer_name(i)
		print("[World] 数据层 ", i, ": ", layer_name)
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
	var cave_count = 0 # 统计洞穴数量
	var total_positions = 0 # 统计总位置数
	
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
				# 统计地下部分
				if world_y > 0:
					total_positions += 1
					var should_generate = _should_generate_block(world_y, pos)
					if not should_generate:
						cave_count += 1
					else:
						_generate_underground_tile(pos, world_y)
						var tile_type = _get_tile_type_at(pos, world_y)
						if tile_type != EMPTY:
							var health = _get_tile_health(tile_type)
							var value = _get_tile_value(tile_type)
							_save_tile_to_cache(chunk_data, pos, tile_type, health, value)
	
	# 输出洞穴生成统计（仅对地下区块，且为调试模式时）
	if total_positions > 0 and chunk_pos.y > 0 and OS.is_debug_build():
		var cave_percentage = float(cave_count) / float(total_positions) * 100.0
		print("[Cave Debug] 区块 %s: 洞穴率 %.1f%% (%d/%d), 深度范围: %d-%d" % [
			chunk_pos, cave_percentage, cave_count, total_positions,
			chunk_pos.y * CHUNK_SIZE, (chunk_pos.y + 1) * CHUNK_SIZE - 1
		])
	
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
	
	# 炸弹生成调试信息
	if block_type == BOOM:
		print("[World] 成功创建炸弹在位置: ", pos, " 深度: ", world_y, " 使用图块: ", atlas_map[BOOM])
	
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
	var depth_factor = min(world_y / 50.0, 1.0)

	# 特殊深度增加炸弹几率
	if world_y > 0 and world_y % 8 == 0 and rand_val < 0.4:
		print("[World] 在特殊深度 ", world_y, " 生成炸弹")
		return BOOM

	# 较高炸弹生成概率，较低宝箱概率
	if rand_val < 0.20 + depth_factor * 0.15: # 炸弹 - 较高概率20%~35%
		print("[World] 生成炸弹在深度 ", world_y)
		return BOOM
	elif rand_val < 0.22 + depth_factor * 0.03: # 高级宝箱（稀有）2%~5%
		return CHEST3
	elif rand_val < 0.26 + depth_factor * 0.03: # 中级宝箱（较少）4%~7%
		return CHEST2
	elif rand_val < 0.32 + depth_factor * 0.04: # 低级宝箱（更少）6%~10%
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

func _should_generate_block(world_y: int, pos: Vector2i = Vector2i.ZERO) -> bool:
	# 地表以上不生成方块
	if world_y < 0:
		return false
		
	# 地表就是地表，总是生成
	if world_y == 0:
		return true
		
	# 使用demo风格的洞穴生成系统
	if enable_caves:
		# 计算深度影响（越深洞穴越多，但有上限）
		var depth_factor = min(world_y * depth_factor_rate, 0.2)
		var final_threshold = cave_threshold + depth_factor # 深度越深，阈值越高，洞穴越多
		
		# 使用与demo相同的逻辑：noise值小于阈值时生成洞穴
		var noise_value = noise.get_noise_2d(pos.x, pos.y) + 1.0 # 范围 [0, 2]
		
		# 如果噪声值小于阈值，生成洞穴（不生成方块）
		# 这与demo的逻辑完全一致：(noise.get_noise_2d(x, y) + 1) < cave_threshold
		return noise_value >= final_threshold
	
	return true

# 保存瓦片到缓存
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
