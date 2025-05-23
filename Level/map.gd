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
		var is_chest = [Vector2i(2, 1), Vector2i(0, 2), Vector2i(3, 6)].has(atlas_coords)
		var is_boom = (atlas_coords == Vector2i(7, 5)) # 检查是否是炸药
		if current > 0:
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
				bomb.position = map_to_local(tile_pos)
				# 设置爆炸范围
				bomb.set_explosion_radius(explosion_radius)
				# 立即引爆
				bomb.explode()
			return true
	return false
