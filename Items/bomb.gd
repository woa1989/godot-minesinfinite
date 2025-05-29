extends RigidBody2D

# === 基础属性 ===
var time_left: float = 3.0 # 剩余时间（与场景中Timer的配置保持一致）
var damage: int = 2 # 爆炸伤害
var is_thrown: bool = false # 标记是否为投掷的炸弹

# === 引用节点 ===
var map: TileMapLayer # 地图层
var world: Node2D # 世界节点

# === 物理常量 ===
const FRICTION: float = 5.0 # 摩擦系数
const LINEAR_DAMP: float = 2.0 # 线性阻尼
const MASS: float = 2.0 # 质量

# === 状态标志 ===
var is_exploding := false # 防止重复爆炸

# === 初始化 ===
func _ready() -> void:
	print("[Bomb] _ready() - 初始化开始")
	# 设置物理属性
	mass = MASS
	linear_damp = LINEAR_DAMP
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = FRICTION
	physics_material_override = physics_material
	
	add_to_group("bombs") # 添加到炸弹组
	_init_nodes() # 初始化节点引用
	_init_ui() # 初始化界面
	
	# 使用信号连接语法确保Timer信号一定会连接
	if not $Timer.timeout.is_connected(_on_timer_timeout):
		$Timer.timeout.connect(_on_timer_timeout)
		print("[Bomb] Timer信号连接成功")
	
	print("[Bomb] _ready() - 初始化完成")

# === 节点初始化 ===
func _init_nodes() -> void:
	# 优先查找父节点，确保是 Node2D 类型
	var parent = get_parent()
	world = parent if parent is Node2D else null
	
	# 从父节点开始向上查找 TileMapLayer
	var node = get_parent()
	while node:
		# 优先在子节点中查找 Map
		var map_node = node.get_node_or_null("Map")
		if map_node and map_node is TileMapLayer:
			map = map_node
			print("[Bomb] 找到Map节点: ", map)
			break
			
		# 向上递归查找
		node = node.get_parent()
		if node is Window: # 如果到达了Window节点，停止搜索
			break
	
	# 如果还找不到，尝试全局路径
	if not map:
		var global_map = get_node_or_null("/root/Level/World/Map")
		if global_map:
			map = global_map
			print("[Bomb] 使用全局路径找到Map节点")
		else:
			push_error("[Bomb] 无法找到Map节点，炸弹将不能破坏地形!")
			
	# 确保world节点设置正确
	if not world:
		node = self
		while node:
			node = node.get_parent()
			if node is Node2D and not node is TileMapLayer:
				world = node
				print("[Bomb] 找到World节点: ", world)
				break
			if node is Window:
				break

# === UI初始化 ===
func _init_ui() -> void:
	$CountdownLabel.text = str(ceil(time_left))
	set_process(true) # 设置为true以启用_process

# === 信号回调 ===
func _on_timer_timeout() -> void:
	print("[Bomb] Timer超时 - 立即触发爆炸")
	if not is_exploding: # 加一个安全检查
		$ExplosionArea/CollisionShape2D.disabled = false
		call_deferred("explode") # 使用 call_deferred 确保安全调用

# === 主要功能函数 ===
## 爆炸主函数
func explode() -> void:
	print("[Bomb] explode() 开始执行")
	if is_exploding:
		print("[Bomb] 已经在爆炸中，跳过")
		return
	is_exploding = true
	
	# 停止计时器和进程
	$Timer.stop()
	set_process(false)
	print("[Bomb] Timer已停止，process已禁用")
	
	if map and world:
		print("[Bomb] 开始处理爆炸 - Map和World节点都有效")
		_handle_explosion()
		
	else:
		print("[Bomb] 爆炸处理失败 - Map:", map != null, " World:", world != null)
	_play_explosion_effects()


## 原始的地图炸弹爆炸处理(保持不变)
func _handle_explosion() -> void:
	var center_tile = map.local_to_map(map.to_local(global_position))
	print("[Bomb] 爆炸中心点: ", center_tile)
	var explosion_radius = 1 # 爆炸半径（九宫格）
	
	# 遍历爆炸范围内的所有瓦片
	for y in range(-explosion_radius, explosion_radius + 1):
		for x in range(-explosion_radius, explosion_radius + 1):
			var tile_pos = center_tile + Vector2i(x, y)
			var damage_dealt = damage # 所有位置造成相同的伤害
			
			print("[Bomb] 检查位置: ", tile_pos)
			
			# 1. 检查该瓦片上是否有其他炸弹
			var bombs = get_tree().get_nodes_in_group("bombs")
			for bomb in bombs:
				if bomb == self or bomb.is_queued_for_deletion():
					continue
				# 判断炸弹是否在该瓦片上
				var bomb_tile = map.local_to_map(map.to_local(bomb.global_position))
				if bomb_tile == tile_pos:
					print("[Bomb] 发现其他炸弹，触发连锁爆炸")
					bomb.take_damage(damage_dealt)
					continue
			
			# 2. 检查并伤害瓦片
			print("[Bomb] 尝试对瓦片造成伤害: ", tile_pos)
			_damage_tile(tile_pos, damage_dealt)

## 对瓦片造成伤害
func _damage_tile(tile_pos: Vector2i, damage_amount: int) -> void:
	var tile_data = map.get_cell_tile_data(tile_pos)
	if not tile_data:
		print("[Bomb] 位置 ", tile_pos, " 没有瓦片数据")
		return
		
	# 检查是否是宝箱或其他可破坏物
	var world_node = map.get_parent()
	var atlas_coords = map.get_cell_atlas_coords(tile_pos)
	print("[Bomb] 瓦片坐标: ", atlas_coords)

	# 获取瓦片类型
	if "atlas_map" in world_node:
		var DIRT = 1
		var CHEST1 = 2
		var CHEST2 = 3
		var CHEST3 = 4
		var GROUND = 5
		var BOOM = 6
		
		var chest_coords = [
			world_node.atlas_map[CHEST1],
			world_node.atlas_map[CHEST2],
			world_node.atlas_map[CHEST3]
		]
		
		var is_dirt = (atlas_coords == world_node.atlas_map[DIRT])
		var is_chest = chest_coords.has(atlas_coords)
		var is_boom = (atlas_coords == world_node.atlas_map[BOOM])
		var is_ground = (atlas_coords == world_node.atlas_map[GROUND])
		
		# 对土块、宝箱、炸药或地面造成伤害
		if is_dirt or is_chest or is_boom or is_ground:
			for _i in range(damage_amount):
				map.process_tile_damage(tile_pos, map, tile_data)
				# 如果瓦片被摧毁，停止伤害
				if map.get_cell_tile_data(tile_pos) == null:
					break

## 受到伤害
## 参数：
##   _amount - 伤害值（未使用，但保留参数以保持接口一致）
func take_damage(_amount: int) -> void:
	# 立即触发爆炸
	explode()

## 销毁方块
func _destroy_block(tile_pos: Vector2i, layer: TileMapLayer) -> void:
	layer.erase_cell(tile_pos)
	if "health_manager" in layer:
		layer.health_manager.remove_health_bar(tile_pos)
	print("[Bomb] 销毁方块: ", tile_pos)

## 播放爆炸效果
func _play_explosion_effects() -> void:
	$ColorRect.hide()
	$CountdownLabel.text = "BOOM!"
	$Boom.emitting = true
	await get_tree().create_timer(1.0).timeout
	queue_free()

func _process(delta: float) -> void:
	if is_exploding:
		return
		
	time_left = max(0, time_left - delta)
	$CountdownLabel.text = str(ceil(time_left))
	
	# 闪烁效果增加警示性
	if time_left <= 1.0:
		$ColorRect.color.a = 0.5 + sin(time_left * 10) * 0.5
	
	# 如果时间到了但Timer还没触发，手动调用爆炸
	if time_left <= 0 and not is_exploding:
		explode()

# === 伤害计算 ===
func calculate_tile_damage(_distance: float, _radius: float) -> int:
	return damage
