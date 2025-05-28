extends TileMapLayer

# 可挖掘的图层索引
const DIGGABLE_LAYER = 0
# 挖掘冷却时间（秒）
const DIG_COOLDOWN = 0.5
#set_cells_terrain_connect # 是否连接相邻瓦片的地形
var can_dig := true # 是否可以挖掘
var cooldown_timer: Timer # 冷却计时器
var health_manager: Node2D # 血条管理器
var current_dig_pos: Vector2i = Vector2i.ZERO # 当前正在挖掘的位置
var tile_max_health = {} # 存储每个位置的最大血量

# 防重复爆炸机制
var exploding_tiles: Dictionary = {} # 正在爆炸的瓦片位置

# 新增：触发炸药爆炸
func trigger_explosion(tile_pos: Vector2i, _radius: float):
	var Bomb = load("res://Items/Bomb.tscn")
	var bomb = Bomb.instantiate()
	get_parent().add_child(bomb)
	# 使用正确的坐标转换
	var local_pos = map_to_local(tile_pos)
	var global_pos = to_global(local_pos)
	bomb.global_position = global_pos
	print("[Map] 触发炸药爆炸: 瓦片位置=", tile_pos, " 全局位置=", global_pos)
	# 设置固定的爆炸范围和伤害
	# 设置炸弹配置
	var config = BombConfig.new()
	config.explosion_radius = 96.0 # 设置为64 * 1.5，刚好覆盖3x3范围
	config.damage = 2 # 固定的伤害值
	config.chain_explosion_multiplier = 1.2 # 连锁爆炸倍数
	bomb.config = config # 应用配置
	# 立即引爆
	bomb.explode()

func _ready():
	# 创建冷却计时器
	cooldown_timer = Timer.new()
	cooldown_timer.wait_time = DIG_COOLDOWN
	cooldown_timer.one_shot = true
	cooldown_timer.connect("timeout", Callable(self, "_on_cooldown_timeout"))
	add_child(cooldown_timer)

	# 创建血条管理器（用于显示每个格子的血量）
	health_manager = Node2D.new()
	health_manager.set_script(load("res://Level/UI/tile_health_manager.gd"))
	add_child(health_manager)

# 冷却计时器超时回调，允许再次挖掘
func _on_cooldown_timeout():
	can_dig = true
	current_dig_pos = Vector2i.ZERO

# 检查指定位置是否可以挖掘
func can_dig_at(tile_pos: Vector2i) -> bool:
	if not can_dig:
		return false
	# 检查单层地图是否有瓦片
	var tile_data = get_cell_tile_data(tile_pos)
	return tile_data != null

# 在指定位置执行挖掘
func dig_at(tile_pos: Vector2i) -> bool:
	if not can_dig_at(tile_pos):
		return false
		
	current_dig_pos = tile_pos
	can_dig = false
	cooldown_timer.start()
	
	# 获取单层地图的瓦片数据
	var tile_data = get_cell_tile_data(tile_pos)
	
	# 处理瓦片伤害
	if tile_data:
		return await process_tile_damage(tile_pos, self, tile_data)
	
	return false

# 处理瓦片伤害
func process_tile_damage(tile_pos: Vector2i, _layer: TileMapLayer, tile_data: TileData) -> bool:
	# 获取自定义数据层id
	var tileset = tile_set
	var health_layer_id = -1
	var value_layer_id = -1
	for i in range(tileset.get_custom_data_layers_count()):
		var layer_name = tileset.get_custom_data_layer_name(i)
		if layer_name == "health":
			health_layer_id = i
		elif layer_name == "value":
			value_layer_id = i
	
	# 读取血量和价值
	if health_layer_id >= 0 and value_layer_id >= 0:
		var health = tile_data.get_custom_data_by_layer_id(health_layer_id)
		var value = tile_data.get_custom_data_by_layer_id(value_layer_id)
		if not tile_max_health.has(tile_pos):
			tile_max_health[tile_pos] = health
		var total = tile_max_health[tile_pos]
		var current = health - 1
		if health < 0:
			return false # 不可破坏
			
		var atlas_coords = get_cell_atlas_coords(tile_pos)
		var world_node = get_parent()
		
		# 检查是否是宝箱或炸药
		var is_chest = false
		var is_boom = false
		
		if "atlas_map" in world_node:
			# 使用枚举值检查宝箱和炸药类型
			var CHEST1 = 2 # 根据map_data.gd中的枚举
			var CHEST2 = 3
			var CHEST3 = 4
			var BOOM = 6
			
			var chest_coords = [
				world_node.atlas_map[CHEST1],
				world_node.atlas_map[CHEST2],
				world_node.atlas_map[CHEST3]
			]
			is_chest = chest_coords.has(atlas_coords)
			is_boom = (atlas_coords == world_node.atlas_map[BOOM])
		
		if current > 0:
			# 如果这是炸药块，每次受伤都会引爆
			if is_boom:
				# 检查是否已经在爆炸中，防止重复触发
				if exploding_tiles.has(tile_pos):
					print("[Map] 跳过重复爆炸: ", tile_pos)
					return true
				
				# 标记为正在爆炸
				exploding_tiles[tile_pos] = true
				
				# 清除单层地图的瓦片
				erase_cell(tile_pos)
				health_manager.remove_health_bar(tile_pos)
				tile_max_health.erase(tile_pos)
				# 触发爆炸效果
				var explosion_radius = value
				trigger_explosion(tile_pos, explosion_radius)
				
				# 延时清除爆炸标记
				await get_tree().create_timer(0.5).timeout
				exploding_tiles.erase(tile_pos)
				return true
			# 如果是宝箱且血量变成1，生成gold
			elif is_chest and current == 1:
				print("[Map] 宝箱转换为金币 - 位置:", tile_pos, " 价值:", value)
				# 清除宝箱瓦片
				erase_cell(tile_pos)
				health_manager.remove_health_bar(tile_pos)
				tile_max_health.erase(tile_pos)
				
				# 生成gold物品
				_spawn_gold(tile_pos, value)
				return true
			else:
				tile_data.set_custom_data_by_layer_id(health_layer_id, current)
				health_manager.update_tile_health(tile_pos, current, total)
				return true
		else:
			# 清除单层地图的瓦片
			erase_cell(tile_pos)
			health_manager.remove_health_bar(tile_pos)
			tile_max_health.erase(tile_pos)
			
			if is_chest:
				Global.currency += value
				print("[Map] 宝箱被摧毁，获得金币: ", value)
			elif is_boom:
				var explosion_radius = value
				trigger_explosion(tile_pos, explosion_radius)
			return true
			
	return false

# 生成金币物品
func _spawn_gold(tile_pos: Vector2i, value: int):
	var Gold = preload("res://Gold/Gold.tscn")
	var gold_instance = Gold.instantiate()
	
	# 使用单层地图的坐标转换
	var local_pos = map_to_local(tile_pos)
	# 设置金币的本地位置（相对于World节点）
	gold_instance.position = local_pos
	gold_instance.value = value
	
	# 将金币添加到世界节点，这样金币会受到相同的变换
	get_parent().add_child(gold_instance)
	print("[Map] 在位置 ", tile_pos, " 生成了价值 ", value, " 的金币，坐标:", local_pos)
