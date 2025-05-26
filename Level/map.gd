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
	bomb.set_explosion_radius(96.0) # 设置为64 * 1.5，刚好覆盖3x3范围
	bomb.set_damage(2) # 固定的伤害值
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
	var tile_data = get_cell_tile_data(tile_pos)
	return tile_data != null

# 在指定位置执行挖掘
func dig_at(tile_pos: Vector2i) -> bool:
	if not can_dig_at(tile_pos):
		return false
	current_dig_pos = tile_pos
	can_dig = false
	cooldown_timer.start()

	var tile_data = get_cell_tile_data(tile_pos)
	if not tile_data:
		return false

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
		
		# 获取当前地图的atlas_map配置
		var world_node = get_parent()
		var is_chest = false
		var is_boom = false
		
		# 检查是否是宝箱或炸药
		if "atlas_map" in world_node and "CHEST1" in world_node and "CHEST2" in world_node and "CHEST3" in world_node and "BOOM" in world_node:
			is_chest = [
				world_node.atlas_map[world_node.CHEST1],
				world_node.atlas_map[world_node.CHEST2],
				world_node.atlas_map[world_node.CHEST3]
			].has(atlas_coords)
			is_boom = (atlas_coords == world_node.atlas_map[world_node.BOOM]) # 检查是否是炸药
			print("[Map] 检查炸药块: atlas_coords=", atlas_coords, " boom_coords=", world_node.atlas_map[world_node.BOOM], " is_boom=", is_boom)
		else:
			# 回退到默认值
			is_chest = [Vector2i(2, 1), Vector2i(0, 2), Vector2i(3, 6)].has(atlas_coords)
			is_boom = (atlas_coords == Vector2i(7, 5))
		if current > 0:
			# 如果这是炸药块，每次受伤都会引爆
			if is_boom:
				erase_cell(tile_pos)
				health_manager.remove_health_bar(tile_pos)
				tile_max_health.erase(tile_pos)
				# 触发爆炸效果
				var explosion_radius = value # 使用value字段作为爆炸范围
				trigger_explosion(tile_pos, explosion_radius)
				return true
			else:
				tile_data.set_custom_data_by_layer_id(health_layer_id, current)
				health_manager.update_tile_health(tile_pos, current, total)
				return true
		else:
			erase_cell(tile_pos)
			health_manager.remove_health_bar(tile_pos)
			tile_max_health.erase(tile_pos)
			if is_chest:
				Global.currency += value # 挖掉宝箱加钱
			elif is_boom:
				# 触发爆炸效果
				var explosion_radius = value # 使用value字段作为爆炸范围
				var Bomb = load("res://Items/Bomb.tscn")
				var bomb = Bomb.instantiate()
				get_parent().add_child(bomb)
				
				# 计算炸药块的全局位置
				var local_pos = map_to_local(tile_pos)
				var global_pos = to_global(local_pos)
				bomb.global_position = global_pos
				print("[Map] 炸药爆炸: 瓦片坐标=", tile_pos, " 全局位置=", global_pos)
				
				# 设置爆炸范围
				bomb.set_explosion_radius(explosion_radius)
				# 立即引爆
				bomb.explode()
			return true
	return false
