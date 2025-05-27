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
@export_range(0.0, 1.0) var cave_threshold: float = 0.4 # 洞穴生成阈值（越小空洞越多）
@export_range(0.0, 0.1) var depth_factor_rate: float = 0.0001 # 深度影响因子（越大深处空洞越多）
@export_range(0.0, 1.0) var max_depth_effect: float = 0.1 # 深度最大影响值

# === 地图尺寸常量 ===
const TILE_SIZE := 64 # 单个瓦片像素大小
const CHUNK_SIZE := 16 # 区块大小（瓦片数）
const LOAD_DISTANCE := 3 # 加载区块距离
const UNLOAD_DISTANCE := 5 # 卸载区块距离
const SCREEN_WIDTH := 1920 # 屏幕宽度

# === TileSet数据 ===
var _layers = {} # dirt层的自定义数据层ID缓存
var _props_layers = {} # props层的自定义数据层ID缓存
var atlas_map = {} # 当前地图的图块映射表
var current_map_id = "mine" # 当前地图ID

# === 节点引用 ===
@onready var dirt := $Dirt as TileMapLayer
@onready var props := $Props as TileMapLayer
@onready var player := %Player

# === 区块管理 ===
var loaded_chunks = {} # 已加载区块表 {Vector2i: bool}
var current_chunk = Vector2i.ZERO # 当前玩家所在区块

# === 地图初始化 ===
func _ready() -> void:
	_configure_noise()
	set_current_map(current_map_id) # 不需要await
	player.dig.connect(_on_player_dig)
	_init_map_loading()

# === 噪声配置 ===
func _configure_noise() -> void:
	if not noise:
		noise = FastNoiseLite.new()
	
	# 配置噪声参数
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi() # 随机种子
	noise.frequency = 0.6 # 控制噪声的"粒度"，值越大，变化越剧烈
	noise.fractal_octaves = 2 # 使用较少的叠加层，让洞穴形状更简单
	noise.fractal_gain = 0.3 # 降低细节的影响
	noise.fractal_lacunarity = 2.0 # 控制不同层级之间的频率变化

# === 地图设置 ===
func set_current_map(map_id: String) -> void:
	print("[World] 设置当前地图为: ", map_id)
	current_map_id = map_id
	
	if not MapData.MAPS_CHUNKS.has(map_id):
		MapData.MAPS_CHUNKS[map_id] = {}
	loaded_chunks = MapData.MAPS_CHUNKS[map_id]
	
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
	dirt.tile_set = new_tileset
	props.tile_set = new_tileset.duplicate(true)
	
	# 等待加载完成
	await get_tree().process_frame
	await get_tree().process_frame
	
	if _validate_tilesets():
		_init_custom_data_layers()

# === 自定义数据层管理 ===
func get_custom_data_layers() -> Dictionary:
	if not dirt.tile_set:
		push_error("[World] dirt tileset 未初始化!")
		return {}
		
	if _layers and _layers.has("health_id") and _layers.has("value_id"):
		return _layers
		
	if TileSetDataHelper.validate_custom_data(dirt.tile_set):
		var layers = {}
		for i in range(dirt.tile_set.get_custom_data_layers_count()):
			var layer_name = dirt.tile_set.get_custom_data_layer_name(i)
			if layer_name == "health":
				layers["health_id"] = i
			elif layer_name == "value":
				layers["value_id"] = i
		return layers
	
	return {}

# === 验证函数 ===
func _validate_tilesets() -> bool:
	if not dirt.tile_set or not props.tile_set:
		push_error("[World] tileset加载失败!")
		return false
		
	var dirt_source_count = dirt.tile_set.get_source_count()
	var props_source_count = props.tile_set.get_source_count()
	if dirt_source_count == 0 or props_source_count == 0:
		push_error("[World] tileset没有任何源!")
		return false
		
	print("[World] tileset加载成功，dirt源数量: ", dirt_source_count,
		  ", props源数量: ", props_source_count)
	return true

# === 自定义数据层初始化 ===
func _init_custom_data_layers() -> void:
	_layers = TileSetDataHelper.init_custom_data(dirt.tile_set)
	var props_layers = TileSetDataHelper.init_custom_data(props.tile_set)
	
	if _layers.is_empty() or props_layers.is_empty():
		push_error("[World] 初始化tileset数据层失败!")
		_layers = TileSetDataHelper.init_custom_data(dirt.tile_set)
		props_layers = TileSetDataHelper.init_custom_data(props.tile_set)
		
		if _layers.is_empty() or props_layers.is_empty():
			push_error("[World] 初始化tileset数据层第二次尝试也失败!")
			return
			
	_props_layers = props_layers
	print("[World] 成功初始化两个tileset和数据层")

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

func _load_chunk_data(chunk_pos: Vector2i, source_id: int, chunk_data: Dictionary) -> void:
	for pos in chunk_data:
		var tile_info = chunk_data[pos]
		dirt.set_cell(pos, source_id, tile_info.atlas_coords)
		var tile_data = dirt.get_cell_tile_data(pos)
		if tile_data:
			tile_data.set_custom_data("health", tile_info.health)
			tile_data.set_custom_data("value", tile_info.value)
	loaded_chunks[chunk_pos] = true

func _generate_new_chunk(chunk_pos: Vector2i) -> void:
	var custom_data_layers = get_custom_data_layers()
	if not custom_data_layers:
		return
		
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			generate_tile(Vector2i(start_x + x, start_y + y), custom_data_layers)
			
	loaded_chunks[chunk_pos] = true

# === 图块生成 ===
func generate_tile(pos: Vector2i, layers: Dictionary) -> void:
	var world_y = pos.y
	
	if world_y == 0:
		_generate_ground_tile(pos, layers)
	else:
		_generate_underground_tile(pos, world_y)

func _generate_ground_tile(pos: Vector2i, layers: Dictionary) -> void:
	var source_id = _get_valid_source_id()
	if source_id != -1:
		dirt.set_cell(pos, source_id, atlas_map[GROUND])
		var tile_data = dirt.get_cell_tile_data(pos)
		if tile_data and layers.has("health_id") and layers.has("value_id"):
			tile_data.set_custom_data_by_layer_id(layers["health_id"], 1)
			tile_data.set_custom_data_by_layer_id(layers["value_id"], 1)

func _generate_underground_tile(pos: Vector2i, world_y: int) -> void:
	var should_generate = _should_generate_block(world_y, pos)
	
	if should_generate:
		var source_id = _get_valid_source_id()
		if source_id != -1:
			_create_dirt_block(pos, source_id, world_y)

# === 方块生成逻辑 ===
func _should_generate_block(world_y: int, pos: Vector2i = Vector2i.ZERO) -> bool:
	# 地表以上不生成方块
	if world_y < 0:
		return false
		
	# 地表到浅层（5格以内）总是生成方块
	if world_y <= 1:
		return true
		
	# 深层使用噪声生成洞穴
	if enable_caves and noise:
		var noise_value = (noise.get_noise_2d(pos.x, pos.y) + 1) * 0.5
		var depth = min(50, world_y)
		var depth_factor = min(max_depth_effect, depth * depth_factor_rate)
		var threshold = cave_threshold - depth_factor
		return noise_value > threshold
		
	return true

func _create_dirt_block(pos: Vector2i, source_id: int, world_y: int) -> void:
	dirt.set_cell(pos, source_id, atlas_map[DIRT])
	var tile_data = dirt.get_cell_tile_data(pos)
	if tile_data and _layers:
		tile_data.set_custom_data_by_layer_id(_layers["health_id"], 1)
		tile_data.set_custom_data_by_layer_id(_layers["value_id"], 1)
	
	# 生成特殊方块
	var rand_val = randf()
	if world_y > 5:
		if rand_val > 0.99:
			generate_chest(pos, _layers, rand_val)
		elif rand_val > 0.97:
			generate_boom(pos, _layers)

# === 特殊方块生成 ===
func generate_chest(pos: Vector2i, _unused_layers: Dictionary, rand_val: float) -> void:
	var chest_type = _determine_chest_type(rand_val)
	var chest_health = 3
	var chest_value = _determine_chest_value(chest_type)
	
	_create_props_block(pos, chest_type, chest_health, chest_value)

func generate_boom(pos: Vector2i, _unused_layers: Dictionary) -> void:
	_create_props_block(pos, BOOM, 1, 64) # 炸药块生命值1，爆炸范围64

func _create_props_block(pos: Vector2i, block_type: int, health: int, value: int) -> void:
	if not props.tile_set:
		push_error("[World] props tileset未初始化!")
		return
	
	var source_id = _get_valid_source_id()
	if source_id == -1:
		push_error("[World] 无法获取有效的源ID!")
		return
	
	props.set_cell(pos, source_id, atlas_map[block_type])
	var tile_data = props.get_cell_tile_data(pos)
	if tile_data and _props_layers:
		tile_data.set_custom_data_by_layer_id(_props_layers["health_id"], health)
		tile_data.set_custom_data_by_layer_id(_props_layers["value_id"], value)

func _determine_chest_type(rand_val: float) -> int:
	if rand_val > 0.95:
		return CHEST3
	elif rand_val > 0.8:
		return CHEST2
	return CHEST1

func _determine_chest_value(chest_type: int) -> int:
	match chest_type:
		CHEST3: return 200
		CHEST2: return 100
		_: return 50

# === 区块更新 ===
func update_chunks() -> void:
	var player_chunk = world_to_chunk(player.global_position)
	if player_chunk != current_chunk:
		current_chunk = player_chunk
		_update_chunk_loading(player_chunk)

func _update_chunk_loading(player_chunk: Vector2i) -> void:
	var load_distance_x = max(LOAD_DISTANCE,
							int(SCREEN_WIDTH / (TILE_SIZE * CHUNK_SIZE * 1.0)) + 1)
	
	# 加载新区块
	for y in range(-1, LOAD_DISTANCE + 3):
		for x in range(-load_distance_x, load_distance_x + 1):
			var chunk_pos = Vector2i(player_chunk.x + x, player_chunk.y + y)
			if not loaded_chunks.has(chunk_pos):
				generate_chunk(chunk_pos)
	
	# 卸载远处区块
	var chunks_to_unload = []
	for chunk_pos in loaded_chunks.keys():
		var distance_x = abs(chunk_pos.x - player_chunk.x)
		var distance_y = chunk_pos.y - player_chunk.y
		if chunk_pos.x != 0 and (distance_x > load_distance_x + 2 or
								distance_y < -2 or
								distance_y > UNLOAD_DISTANCE + 3):
			chunks_to_unload.append(chunk_pos)
	
	for chunk_pos in chunks_to_unload:
		_unload_chunk(chunk_pos)

func _unload_chunk(chunk_pos: Vector2i) -> void:
	if not loaded_chunks.has(chunk_pos):
		return
	
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x = chunk_pos.x * CHUNK_SIZE + x
			var world_y = chunk_pos.y * CHUNK_SIZE + y
			var pos = Vector2i(world_x, world_y)
			dirt.erase_cell(pos)
			props.erase_cell(pos)
	
	loaded_chunks.erase(chunk_pos)

# === 缓存管理 ===
func _load_cached_chunks() -> void:
	loaded_chunks.clear()
	
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
	var tile_pos = dirt.local_to_map(dirt.to_local(world_pos))
	return Vector2i(floor(tile_pos.x / float(CHUNK_SIZE)),
				   floor(tile_pos.y / float(CHUNK_SIZE)))

func is_valid_tileset() -> bool:
	if not dirt.tile_set:
		push_error("TileMap没有设置tileset!")
		return false
		
	var source_id = _get_valid_source_id()
	return source_id != -1

func _get_valid_source_id() -> int:
	var source_count = dirt.tile_set.get_source_count()
	for i in range(source_count):
		var source_id = dirt.tile_set.get_source_id(i)
		if dirt.tile_set.get_source(source_id):
			return source_id
	return -1

# === 信号回调 ===
func _on_player_dig(tile_pos: Vector2i, _direction: String) -> void:
	var props_data = props.get_cell_tile_data(tile_pos)
	if props_data:
		props.dig_at(tile_pos)
	else:
		dirt.dig_at(tile_pos)

func _process(_delta: float) -> void:
	update_chunks()
