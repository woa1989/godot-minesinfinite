extends TileMapLayer

# 定义可挖掘的图层索引
const DIGGABLE_LAYER = 0

# 定义挖掘冷却时间（秒）
const DIG_COOLDOWN = 0.5

# 是否可以挖掘
var can_dig = true
var cooldown_timer = null
var health_manager: Node2D

# 当前正在挖掘的位置
var current_dig_pos: Vector2i = Vector2i.ZERO

# 存储每个位置的最大血量
var tile_max_health = {}

func _ready():
	# 创建冷却计时器
	cooldown_timer = Timer.new()
	cooldown_timer.wait_time = DIG_COOLDOWN
	cooldown_timer.one_shot = true
	cooldown_timer.connect("timeout", Callable(self, "_on_cooldown_timeout"))
	add_child(cooldown_timer)
	
	# 创建血条管理器
	health_manager = Node2D.new()
	health_manager.set_script(load("res://Level/UI/tile_health_manager.gd"))
	add_child(health_manager)

func _on_cooldown_timeout():
	can_dig = true
	current_dig_pos = Vector2i.ZERO # 重置挖掘位置
	print("[DEBUG] 挖掘冷却结束")

# 检查指定位置是否可以挖掘
func can_dig_at(tile_pos: Vector2i) -> bool:
	if not can_dig:
		print("[DEBUG] 挖掘冷却中")
		return false
	# 获取指定位置的图块数据
	var tile_data = get_cell_tile_data(tile_pos)
	print("[DEBUG] 位置 ", tile_pos, " 的图块数据: ", tile_data)
	return tile_data != null

# 在指定位置挖掘
func dig_at(tile_pos: Vector2i) -> bool:
	if not can_dig_at(tile_pos):
		return false
	current_dig_pos = tile_pos
	can_dig = false
	cooldown_timer.start()
	var tile_data = get_cell_tile_data(tile_pos)
	if not tile_data:
		return false
	var tileset = tile_set
	var health_layer_id = -1
	var value_layer_id = -1
	for i in range(tileset.get_custom_data_layers_count()):
		var layer_name = tileset.get_custom_data_layer_name(i)
		if layer_name == "health":
			health_layer_id = i
		elif layer_name == "value":
			value_layer_id = i
	if health_layer_id >= 0 and value_layer_id >= 0:
		var health = tile_data.get_custom_data_by_layer_id(health_layer_id)
		var value = tile_data.get_custom_data_by_layer_id(value_layer_id)
		if not tile_max_health.has(tile_pos):
			tile_max_health[tile_pos] = health
		var total = tile_max_health[tile_pos]
		var current = health - 1
		if health < 0:
			print("[DEBUG] 位置 ", tile_pos, " 的瓦片不可破坏")
			return false
		var atlas_coords = get_cell_atlas_coords(tile_pos)
		var is_chest = [Vector2i(2, 1), Vector2i(0, 2), Vector2i(3, 6)].has(atlas_coords)
		if current > 0:
			tile_data.set_custom_data_by_layer_id(health_layer_id, current)
			health_manager.update_tile_health(tile_pos, current, total)
			if is_chest:
				print("[DEBUG] 宝箱血量: ", current, "/", total)
			return true
		else:
			erase_cell(tile_pos)
			health_manager.remove_health_bar(tile_pos)
			tile_max_health.erase(tile_pos)
			if is_chest:
				Global.currency += value
			return true
			
	return false
