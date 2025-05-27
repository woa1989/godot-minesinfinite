extends TileMapLayer

# 可挖掘的图层索引
const DIGGABLE_LAYER = 0
# 挖掘冷却时间（秒）
const DIG_COOLDOWN = 0.5

var can_dig := true # 是否可以挖掘
var cooldown_timer: Timer # 冷却计时器
var health_manager: Node2D # 血条管理器
var current_dig_pos: Vector2i = Vector2i.ZERO # 当前正在挖掘的位置
var tile_max_health = {} # 存储每个位置的最大血量

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
	# 检查土壤层或道具层是否有瓦片
	var dirt_data = get_cell_tile_data(tile_pos)
	var props_layer = get_parent().get_node("Props") as TileMapLayer
	var props_data = props_layer.get_cell_tile_data(tile_pos) if props_layer else null
	return dirt_data != null or props_data != null

# 在指定位置执行挖掘
func dig_at(tile_pos: Vector2i) -> bool:
	if not can_dig_at(tile_pos):
		return false
		
	current_dig_pos = tile_pos
	can_dig = false
	cooldown_timer.start()
	
	# 获取道具层引用
	var props_layer = get_parent().get_node("Props") as TileMapLayer
	if not props_layer:
		push_error("无法找到Props层!")
		return false
	
	# 检查两个层的瓦片数据
	var dirt_data = get_cell_tile_data(tile_pos)
	var props_data = props_layer.get_cell_tile_data(tile_pos)
	
	# 优先处理道具层
	if props_data:
		return process_tile_damage(tile_pos, props_layer, props_data)
	# 如果没有道具，处理土壤层
	elif dirt_data:
		return process_tile_damage(tile_pos, self, dirt_data)
	
	return false

# 处理瓦片伤害
func process_tile_damage(tile_pos: Vector2i, layer: TileMapLayer, tile_data: TileData) -> bool:
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
			
		var atlas_coords = layer.get_cell_atlas_coords(tile_pos)
		var world_node = get_parent()
		
		# 检查是否是宝箱或炸药
		var is_chest = false
		var is_boom = false
		
		if "atlas_map" in world_node and "CHEST1" in world_node and "CHEST2" in world_node and "CHEST3" in world_node and "BOOM" in world_node:
			is_chest = [
				world_node.atlas_map[world_node.CHEST1],
				world_node.atlas_map[world_node.CHEST2],
				world_node.atlas_map[world_node.CHEST3]
			].has(atlas_coords)
			is_boom = (atlas_coords == world_node.atlas_map[world_node.BOOM])
			print("[Map] 检查炸药块: atlas_coords=", atlas_coords, " boom_coords=", world_node.atlas_map[world_node.BOOM], " is_boom=", is_boom)
		
		if current > 0:
			# 如果这是炸药块，每次受伤都会引爆
			if is_boom:
				# 清除两个层的瓦片
				layer.erase_cell(tile_pos)
				if layer != self:
					erase_cell(tile_pos)
				health_manager.remove_health_bar(tile_pos)
				tile_max_health.erase(tile_pos)
				# 触发爆炸效果
				var explosion_radius = value
				trigger_explosion(tile_pos, explosion_radius)
				return true
			else:
				tile_data.set_custom_data_by_layer_id(health_layer_id, current)
				health_manager.update_tile_health(tile_pos, current, total)
				return true
		else:
			# 清除两个层的瓦片
			layer.erase_cell(tile_pos)
			if layer != self:
				erase_cell(tile_pos)
			health_manager.remove_health_bar(tile_pos)
			tile_max_health.erase(tile_pos)
			
			if is_chest:
				Global.currency += value
				# 如果是Props层的宝箱被摧毁，同时清除Dirt层相同位置的土块
				if layer.name == "Props":
					var dirt_layer = get_parent().get_node("Dirt") as TileMapLayer
					if dirt_layer and dirt_layer.get_cell_source_id(tile_pos) != -1:
						dirt_layer.erase_cell(tile_pos)
						# 如果Dirt层有血条，也要移除
						if "health_manager" in dirt_layer:
							dirt_layer.health_manager.remove_health_bar(tile_pos)
						print("[Map] 宝箱被摧毁，同时清除同位置土块: ", tile_pos)
			elif is_boom:
				var explosion_radius = value
				trigger_explosion(tile_pos, explosion_radius)
			return true
			
	return false
