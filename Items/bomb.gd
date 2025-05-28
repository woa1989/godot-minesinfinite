extends RigidBody2D

# === 配置资源 ===
@export var config: Resource # 炸弹配置资源

# === 基础属性 ===
var time_left: float # 剩余时间
var explosion_radius: float # 爆炸范围
var damage: int # 爆炸伤害

# === 引用节点 ===
var map: TileMapLayer # 地图层
var world: Node2D # 世界节点

# === 状态标志 ===
var is_exploding := false # 防止重复爆炸
var show_debug := false # 调试模式

# === 全局防重复爆炸 ===
static var exploding_tiles: Dictionary = {} # 正在爆炸的瓦片位置 {Vector2i: float(time)}
static var explosion_cleanup_timer: float = 0.0 # 清理计时器

# === 初始化 ===
func _ready() -> void:
	_load_config() # 加载配置
	add_to_group("bombs") # 添加到炸弹组
	_init_nodes() # 初始化节点引用
	_setup_physics() # 设置物理属性
	_init_ui() # 初始化界面

# === 配置加载 ===
func _load_config() -> void:
	if not config:
		push_error("未设置炸弹配置！使用默认值")
		config = preload("res://Items/default_bomb_config.tres")
	
	# 从配置加载属性
	time_left = config.time_left
	explosion_radius = config.explosion_radius
	damage = config.damage

# === 节点初始化 ===
func _init_nodes() -> void:
	world = get_parent()
	map = get_node_or_null("/root/Level/World/Map")
	
	if not map:
		push_error("无法找到Map节点，请确认节点路径是否正确")
		push_error("无法找到Props节点，请确认节点路径是否正确")

# === 物理属性设置 ===
func _setup_physics() -> void:
	mass = config.mass
	linear_damp = config.linear_damp
	
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = config.friction
	physics_material_override = physics_material

# === UI初始化 ===
func _init_ui() -> void:
	if not $Timer.timeout.is_connected(_on_timer_timeout):
		$Timer.timeout.connect(_on_timer_timeout)
	$CountdownLabel.text = str(ceil(time_left))
	
	$Timer.wait_time = time_left
	$Timer.start()
	set_process(true)

# === 主要功能函数 ===
## 爆炸主函数
func explode() -> void:
	if is_exploding:
		return
	
	is_exploding = true
	if map and world:
		_handle_explosion()
	_play_explosion_effects()

## 处理爆炸逻辑
func _handle_explosion() -> void:
	print("[Bomb] 开始爆炸处理...")
	var center_tile = map.local_to_map(map.to_local(global_position))
	print("[Bomb] 爆炸中心瓦片坐标: ", center_tile)
	
	# 定义爆炸范围（转换为瓦片单位）
	var tile_radius = ceil(explosion_radius / 64.0) # 假设瓦片大小为64
	
	# 遍历爆炸范围内的所有瓦片
	for y in range(-tile_radius, tile_radius + 1):
		for x in range(-tile_radius, tile_radius + 1):
			var tile_pos = center_tile + Vector2i(x, y)
			var distance = Vector2(x, y).length() * 64.0
			
			# 如果在爆炸半径内
			if distance <= explosion_radius:
				_process_explosion_tile(tile_pos)

## 处理爆炸范围内的单个瓦片
func _process_explosion_tile(tile_pos: Vector2i) -> void:
	print("[Bomb] 检查坐标: ", tile_pos)
	
	# 获取单层地图的瓦片数据
	var tile_data = _get_tile_data(map, tile_pos)
	
	# 如果没有方块，则返回
	if not tile_data:
		return
	
	# 优先处理炸药块（可能触发连锁反应）
	if _handle_explosives(tile_pos):
		return
	
	# 处理普通方块
	_handle_regular_block(tile_pos, tile_data, map)

## 处理爆炸物（炸弹和炸药块）
func _handle_explosives(tile_pos: Vector2i) -> bool:
	# 检查这个位置是否已经在爆炸中
	if exploding_tiles.has(tile_pos):
		print("[Bomb] 跳过重复爆炸: ", tile_pos)
		return true
	
	var boom_coords = _get_boom_coords()
	var boom_info = _check_boom_in_layers(tile_pos, boom_coords)
	
	if boom_info.found:
		# 标记这个位置正在爆炸
		exploding_tiles[tile_pos] = Time.get_unix_time_from_system() + 1.0
		_trigger_chain_explosion(tile_pos, boom_info.layer)
		return true
	return false

## 处理普通方块
func _handle_regular_block(tile_pos: Vector2i, tile_data: TileData, layer: TileMapLayer) -> void:
	var current_health = tile_data.get_custom_data("health") if tile_data else 1
	var health = current_health - damage
	print("[Bomb] 方块血量变化: ", tile_pos, " ", health + damage, " -> ", health)
	
	if health <= 0:
		_destroy_block(tile_pos, layer)
	else:
		_update_block_health(tile_pos, tile_data, health, layer)

# === 辅助函数 ===
## 获取瓦片数据
func _get_tile_data(layer: TileMapLayer, pos: Vector2i) -> TileData:
	var source_id = layer.get_cell_source_id(pos)
	return layer.get_cell_tile_data(pos) if source_id != -1 else null

## 获取炸药块坐标
func _get_boom_coords() -> Vector2i:
	return world.atlas_map[world.BOOM] if "atlas_map" in world and "BOOM" in world else Vector2i(7, 5)

## 检查是否是炸药块
func _check_boom_in_layers(tile_pos: Vector2i, boom_coords: Vector2i) -> Dictionary:
	var result = {"found": false, "layer": null}
	
	# 检查单层地图
	if _is_boom_in_layer(map, tile_pos, boom_coords):
		result.found = true
		result.layer = map
		return result
	
	return result

func _is_boom_in_layer(layer: TileMapLayer, tile_pos: Vector2i, boom_coords: Vector2i) -> bool:
	var atlas_coords = layer.get_cell_atlas_coords(tile_pos)
	return layer.get_cell_source_id(tile_pos) != -1 and atlas_coords == boom_coords

## 触发连锁爆炸
func _trigger_chain_explosion(tile_pos: Vector2i, layer: TileMapLayer) -> void:
	var tile_data = _get_tile_data(layer, tile_pos)
	if tile_data:
		var chain_radius = tile_data.get_custom_data("value") * config.chain_explosion_multiplier
		_destroy_block(tile_pos, layer)
		
		# 使用延时触发连锁爆炸，避免同时爆炸导致的重复处理
		await get_tree().create_timer(0.1).timeout
		
		# 创建新的爆炸
		var new_bomb = load("res://Items/Bomb.tscn").instantiate()
		world.add_child(new_bomb)
		new_bomb.global_position = layer.map_to_local(tile_pos)
		new_bomb.explosion_radius = chain_radius
		new_bomb.damage = damage
		new_bomb.explode()

## 销毁方块
func _destroy_block(tile_pos: Vector2i, layer: TileMapLayer) -> void:
	layer.erase_cell(tile_pos)
	if "health_manager" in layer:
		layer.health_manager.remove_health_bar(tile_pos)
	print("[Bomb] 销毁方块: ", tile_pos)

## 更新方块血量
func _update_block_health(tile_pos: Vector2i, tile_data: TileData, health: int, layer: TileMapLayer = null) -> void:
	if layer == null:
		layer = map
		
	tile_data.set_custom_data("health", health)
	
	if "health_manager" in layer:
		if not layer.tile_max_health.has(tile_pos):
			layer.tile_max_health[tile_pos] = tile_data.get_custom_data("health") + damage
		var total = layer.tile_max_health[tile_pos]
		layer.health_manager.update_tile_health(tile_pos, health, total)

## 播放爆炸效果
func _play_explosion_effects() -> void:
	$ColorRect.hide()
	$CountdownLabel.text = "BOOM!"
	$Boom.emitting = true
	
	# 清理节点
	await get_tree().create_timer(1.0).timeout
	queue_free()

# === 处理函数 ===
func _process(delta: float) -> void:
	# 清理过期的爆炸标记
	_cleanup_explosion_markers()
	
	if is_exploding:
		return
		
	time_left -= delta
	$CountdownLabel.text = str(ceil(time_left))
	
	# 更新闪烁效果
	if time_left <= 1.0:
		$ColorRect.color.a = 0.5 + sin(time_left * 10) * 0.5

## 清理过期的爆炸标记
func _cleanup_explosion_markers() -> void:
	var current_time = Time.get_unix_time_from_system()
	var to_remove = []
	
	for tile_pos in exploding_tiles:
		if current_time > exploding_tiles[tile_pos]:
			to_remove.append(tile_pos)
	
	for tile_pos in to_remove:
		exploding_tiles.erase(tile_pos)

func _exit_tree() -> void:
	if show_debug:
		queue_redraw()

# === 伤害计算 ===
func calculate_tile_damage(_distance: float, _radius: float) -> int:
	return damage

# === 信号回调 ===
func _on_timer_timeout() -> void:
	$ExplosionArea/CollisionShape2D.disabled = false
	explode()
