extends Node2D

# 自定义数据助手引用
const TileSetDataHelper = preload("res://Level/tileset_custom_data.gd")

enum {EMPTY, DIRT, CHEST1, CHEST2, CHEST3, LEFT_WALL, RIGHT_WALL, GROUND}

var atlas_map := {
	EMPTY: null,
	DIRT: Vector2i(5, 0),
	CHEST1: Vector2i(2, 1),
	CHEST2: Vector2i(0, 2),
	CHEST3: Vector2i(3, 6),
	LEFT_WALL: Vector2i(7, 0),
	RIGHT_WALL: Vector2i(1, 4),
	GROUND: Vector2i(0, 7)
}

signal world_load_complete
signal world_load_progress

# 地图设置
const TILE_SIZE := 64
const CHUNK_SIZE := 16 # 每个区块的大小
const LOAD_DISTANCE := 3 # 加载玩家周围多少个区块，增大以确保可见性
const UNLOAD_DISTANCE := 5 # 超过这个距离的区块会被卸载
const SCREEN_WIDTH := 1920 # 屏幕宽度

@export var world_position := Vector2(-TILE_SIZE, 0) # 向左偏移一个瓦片，确保左侧可见
@onready var dirt := $Dirt as TileMapLayer
@onready var player := %Player

# 区块管理
var loaded_chunks = {} # 已加载的区块 {Vector2i: bool}
var current_chunk = Vector2i.ZERO

func _ready() -> void:
	# 计算初始位置，确保左墙在屏幕最左边
	world_position = Vector2(-TILE_SIZE, 0) # 向左偏移一个瓦片的距离，确保左墙在屏幕最左边
	
	# 如果Global有设置位置，则使用Global的位置
	if Global.default_map_position != Vector2.ZERO:
		world_position = Global.default_map_position
	else:
		# 初始化全局位置
		Global.default_map_position = world_position
	
	# 初始化TileSet的自定义数据层
	var tileset = dirt.tile_set
	if tileset:
		TileSetDataHelper.init_custom_data(tileset)
	
	# 只连接dig信号
	player.dig.connect(_on_player_dig)
	
	# 调整地图位置
	position = world_position
	
	# 将玩家放置在安全位置
	# 计算一个安全的位置，确保不会生成在地形内部
	var safe_y = find_safe_spawn_position()
	player.global_position = Vector2(TILE_SIZE * 5, safe_y)
	Global.default_player_position = player.global_position # 保存到全局变量
	
	# 初始加载玩家周围的区块
	update_chunks()

func get_tile_index(pos: Vector2):
	# 使用to_global将世界坐标转换为全局坐标，然后使用TileMap的map_to_local方法
	var local_pos = dirt.to_local(pos)
	var tile_pos = dirt.local_to_map(local_pos)
	
	return tile_pos

func get_tile_contents(index: Vector2):
	var tile = Global.Tile.new()
	var cell_coords = dirt.get_cell_atlas_coords(index)
	
	# 如果没有单元格，返回空
	if cell_coords == Vector2i(-1, -1):
		tile.tile_type = Global.TileType.EMPTY
		return tile
		
	# 查找对应的图块类型并设置
	var dirt_value = atlas_map.find_key(cell_coords)
	match dirt_value:
		DIRT:
			tile.tile_type = Global.TileType.DIRT
		LEFT_WALL:
			tile.tile_type = Global.TileType.LEFT_WALL
		RIGHT_WALL:
			tile.tile_type = Global.TileType.RIGHT_WALL
		CHEST1:
			tile.tile_type = Global.TileType.CHEST1
		CHEST2:
			tile.tile_type = Global.TileType.CHEST2
		CHEST3:
			tile.tile_type = Global.TileType.CHEST3
		_:
			tile.tile_type = Global.TileType.EMPTY
	
	return tile

func mine_tile(index: Vector2):
	# 只需要操作单层dirt图层
	dirt.erase_cell(index)

func clear_terrain():
	dirt.clear()

# 根据世界坐标获取区块坐标
func world_to_chunk(world_pos: Vector2) -> Vector2i:
	var tile_pos = dirt.local_to_map(dirt.to_local(world_pos))
	return Vector2i(floor(tile_pos.x / float(CHUNK_SIZE)), floor(tile_pos.y / float(CHUNK_SIZE)))

# 更新玩家周围的区块
# 查找安全的生成位置
func find_safe_spawn_position() -> float:
	# 从屏幕中间开始向下找第一个非空瓦片
	var start_x = TILE_SIZE * 5 # 从第5个瓦片开始检查
	var start_y = - TILE_SIZE * 2 # 从屏幕上方开始检查
	var max_checks = 100 # 最大检查次数，防止无限循环
	var check_pos = Vector2(start_x, start_y)
	
	for i in range(max_checks):
		var tile_pos = dirt.local_to_map(dirt.to_local(check_pos))
		var cell_data = dirt.get_cell_tile_data(tile_pos)
		
		# 如果当前位置是空的，返回这个位置
		if not cell_data:
			return check_pos.y
		
		# 否则继续向下检查
		check_pos.y += TILE_SIZE
	
	# 如果没找到安全位置，返回默认值
	return TILE_SIZE * 5

func update_chunks():
	var player_chunk = world_to_chunk(player.global_position)
	
	# 如果玩家移动到了新的区块
	if player_chunk != current_chunk:
		current_chunk = player_chunk
	
	# 计算水平加载距离，确保左右都有足够区块
	var load_distance_x = max(LOAD_DISTANCE,
		int(SCREEN_WIDTH / (TILE_SIZE * CHUNK_SIZE * 1.0)) + 1)
	
	# 确保左边界区块总是被加载（包含x=0的区块）
	var leftmost_chunk = Vector2i(0, player_chunk.y)
	if not loaded_chunks.has(leftmost_chunk):
		generate_chunk(leftmost_chunk)
	
	# 加载玩家周围的区块，水平方向多加载一些，垂直方向只往下加载
	for y in range(-1, LOAD_DISTANCE + 3): # 上方只加载1个区块，下方多加载几个区块
		for x in range(-load_distance_x, load_distance_x + 1):
			var chunk_pos = Vector2i(player_chunk.x + x, player_chunk.y + y)
			if not loaded_chunks.has(chunk_pos):
				generate_chunk(chunk_pos)
	
	# 卸载远离玩家的区块，但永远不卸载左边界区块
	var chunks_to_unload = []
	for chunk_pos in loaded_chunks.keys():
		var distance_x = abs(chunk_pos.x - player_chunk.x)
		var distance_y = chunk_pos.y - player_chunk.y # 计算相对于玩家的垂直距离
		
		# 水平方向使用更大的卸载距离，但不卸载左边界
		# 上方区块较快卸载，下方区块保持更长时间
		if chunk_pos.x != 0 and (distance_x > load_distance_x + 2
			or distance_y < -2 # 上方只保留2个区块
			or distance_y > UNLOAD_DISTANCE + 3): # 下方多保留一些区块
			chunks_to_unload.append(chunk_pos)
	
	for chunk_pos in chunks_to_unload:
		unload_chunk(chunk_pos)

# 生成单个区块
func generate_chunk(chunk_pos: Vector2i):
	# 如果区块已加载，直接返回
	if loaded_chunks.has(chunk_pos):
		return
		
	# 获取自定义数据层ID
	var tileset = dirt.tile_set
	var custom_data_layers = {}
	for i in range(tileset.get_custom_data_layers_count()):
		var layer_name = tileset.get_custom_data_layer_name(i)
		custom_data_layers[layer_name] = i
	
	var health_layer = custom_data_layers.get("health", -1)
	var value_layer = custom_data_layers.get("value", -1)
	
	# 确定区块的世界坐标范围
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	
	# 生成区块内的瓦片
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x = start_x + x
			var world_y = start_y + y
			var pos = Vector2i(world_x, world_y)
			var rand_val = randf()
			
			# 确认当前位置是否是地图右边界
			var is_right_edge = (world_x > 0 and world_x % (CHUNK_SIZE * 10) == (CHUNK_SIZE * 10) - 1)
			
			# 处理右边界（不生成墙壁，使右侧能无限延伸）
			if is_right_edge:
				continue
			
			# 地面上方（y < 0）不生成任何东西
			if world_y < 0:
				continue
			
			# 地面层（y=0）生成 GROUND
			if world_y == 0:
				dirt.set_cell(pos, 0, atlas_map[GROUND])
				var tile_data = dirt.get_cell_tile_data(pos)
				if tile_data and health_layer >= 0 and value_layer >= 0:
					tile_data.set_custom_data_by_layer_id(health_layer, 1) # 1点生命值
					tile_data.set_custom_data_by_layer_id(value_layer, 1) # 1个金币
			# 地下（y > 0）生成内容
			else:
				# 90% 概率生成泥土，10% 概率生成空气
				if rand_val < 0.9: # 90% 概率生成泥土
					dirt.set_cell(pos, 0, atlas_map[DIRT])
					var tile_data = dirt.get_cell_tile_data(pos)
					if tile_data and health_layer >= 0 and value_layer >= 0:
						tile_data.set_custom_data_by_layer_id(health_layer, 1) # 1点生命值
						tile_data.set_custom_data_by_layer_id(value_layer, 1) # 1个金币
				# 在地下生成宝箱 (1% 概率)
				if world_y > 5 and rand_val > 0.99:
					# 1% 概率生成宝箱
					var chest_type = CHEST1
					var chest_health = 3 # 普通宝箱需要砍3下
					var chest_value = 50 # 基础价值
					
					if rand_val > 0.95:
						# 5% 概率生成稀有宝箱
						chest_type = CHEST3
						chest_health = 5 # 稀有宝箱需要砍5下
						chest_value = 200
					elif rand_val > 0.8:
						# 15% 概率生成高级宝箱
						chest_type = CHEST2
						chest_health = 4 # 高级宝箱需要砍4下
						chest_value = 100
						
					dirt.set_cell(pos, 0, atlas_map[chest_type])
					var tile_data = dirt.get_cell_tile_data(pos)
					if tile_data and health_layer >= 0 and value_layer >= 0:
						tile_data.set_custom_data_by_layer_id(health_layer, chest_health) # 设置生命值
						tile_data.set_custom_data_by_layer_id(value_layer, chest_value) # 设置宝箱价值
	
	# 标记区块为已加载
	loaded_chunks[chunk_pos] = true
	emit_signal("world_load_progress", loaded_chunks.size() * 10) # 简化进度通知
# 卸载区块
func unload_chunk(chunk_pos: Vector2i):
	if not loaded_chunks.has(chunk_pos):
		return
		
	# 计算区块的世界坐标范围
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	
	# 清除区块内的所有瓦片
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x = start_x + x
			var world_y = start_y + y
			var pos = Vector2i(world_x, world_y)
			dirt.erase_cell(pos)
	
	# 从已加载区块列表中移除
	loaded_chunks.erase(chunk_pos)

# 旧的生成函数，保留用于兼容
func generate_terrain():
	clear_terrain()
	
	# 使用区块系统生成地图
	var player_chunk = world_to_chunk(player.global_position)
	current_chunk = player_chunk
	
	# 先生成左边界区块（包含左墙）
	generate_chunk(Vector2i(0, player_chunk.y))
	
	# 再生成玩家周围的其他区块
	for y in range(-LOAD_DISTANCE, LOAD_DISTANCE + 1):
		for x in range(-LOAD_DISTANCE, LOAD_DISTANCE + 1):
			var chunk_pos = Vector2i(player_chunk.x + x, player_chunk.y + y)
			if not loaded_chunks.has(chunk_pos):
				generate_chunk(chunk_pos)
	
	emit_signal("world_load_complete")


func _add_boring_machine(pos: Vector2i):
	print("[DEBUG] 添加钻机在位置: ", pos)
	for x in range(0, 4):
		for y in range(0, 4):
			# 只需要清除dirt图层的瓦片
			dirt.erase_cell(Vector2i(pos.x + x, pos.y + y))

# 处理向下挖掘
func _on_player_dig(tile_pos: Vector2i, _direction: String):
	# direction: "down" "up" "left" "right"
	dirt.dig_at(tile_pos)

func _process(_delta):
	# 持续更新区块
	update_chunks()
