extends RigidBody2D

## 炸弹类
## 处理炸弹的行为，包括爆炸、连锁反应和方块伤害
##
## 主要功能:
## 1. 倒计时爆炸
## 2. 处理3x3范围的爆炸效果
## 3. 对方块造成伤害
## 4. 触发连锁爆炸
## 5. 支持配置系统

signal exploded # 爆炸信号

# 预加载默认配置
@export var config: BombConfig = preload("res://Items/default_bomb_config.tres") as BombConfig

# 运行时变量
var time_left: float # 爆炸倒计时
var explosion_radius: float # 爆炸范围
var damage: int # 爆炸伤害
var dirt: TileMapLayer # 地形层引用
var props: TileMapLayer # 道具层引用
var world: Node2D # 世界节点引用
var is_exploding := false # 防止重复爆炸
var show_debug := false # 调试模式开关

func _ready() -> void:
	# 从配置加载属性
	_load_config()
	
	# 添加到炸弹组便于追踪
	add_to_group("bombs")
	
	# 初始化节点引用
	_init_nodes()
	
	# 设置物理属性
	_setup_physics()
	
	# 初始化界面
	_init_ui()

## 从配置加载属性
func _load_config() -> void:
	if not config:
		push_error("未设置炸弹配置！使用默认值")
		config = preload("res://Items/default_bomb_config.tres")
	
	time_left = config.time_left
	explosion_radius = config.explosion_radius
	damage = config.damage

## 初始化节点引用
func _init_nodes() -> void:
	world = get_parent()
	dirt = get_node_or_null("/root/Level/World/Dirt") as TileMapLayer
	props = get_node_or_null("/root/Level/World/Props") as TileMapLayer
	if not dirt:
		push_error("无法找到Dirt节点，请确认节点路径是否正确")
	if not props:
		push_error("无法找到Props节点，请确认节点路径是否正确")

## 设置物理属性
func _setup_physics() -> void:
	mass = config.mass
	linear_damp = config.linear_damp
	
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = config.friction
	physics_material_override = physics_material

## 初始化界面
func _init_ui() -> void:
	if not $Timer.timeout.is_connected(_on_timer_timeout):
		$Timer.timeout.connect(_on_timer_timeout)
	$CountdownLabel.text = str(ceil(time_left))
	$Timer.wait_time = time_left # 设置定时器时间
	$Timer.start() # 启动定时器
	set_process(true) # 启用处理函数来更新倒计时


## 设置爆炸半径
func set_explosion_radius(radius: float) -> void:
	explosion_radius = radius

## 设置爆炸伤害
func set_damage(new_damage: int) -> void:
	damage = new_damage

## 爆炸主函数
func explode() -> void:
	if is_exploding:
		return
	
	is_exploding = true
	
	if dirt and world:
		_handle_explosion()
	
	_play_explosion_effects()

## 处理爆炸逻辑
func _handle_explosion() -> void:
	print("[Bomb] 开始爆炸处理...")
	var center_tile: Vector2i = dirt.local_to_map(dirt.to_local(global_position))
	print("[Bomb] 爆炸中心瓦片坐标: ", center_tile)
	
	var affected_tiles: Array[Vector2i] = _get_affected_tiles()
	
	# 处理受影响的瓦片
	for offset in affected_tiles:
		var tile_pos: Vector2i = center_tile + offset
		_process_tile(tile_pos)

## 获取受影响的瓦片
func _get_affected_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	# 获取3x3范围内的所有瓦片
	for x in range(-1, 2):
		for y in range(-1, 2):
			tiles.append(Vector2i(x, y))
	
	# 按距离排序，使爆炸从中心向外扩散
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared())
	return tiles

## 处理单个瓦片
func _process_tile(tile_pos: Vector2i) -> void:
	print("[Bomb] 检查坐标: ", tile_pos)
	
	# 检查props层（优先）
	var props_source_id: int = props.get_cell_source_id(tile_pos)
	var props_data: TileData = props.get_cell_tile_data(tile_pos) if props_source_id != -1 else null
	
	# 检查dirt层
	var dirt_source_id: int = dirt.get_cell_source_id(tile_pos)
	var dirt_data: TileData = dirt.get_cell_tile_data(tile_pos) if dirt_source_id != -1 else null
	
	# 如果两个层都没有方块，则返回
	if props_source_id == -1 and dirt_source_id == -1:
		return
	
	# 处理炸弹和炸药块（两个层都要检查）
	if _handle_explosives(tile_pos):
		return
	
	# 先处理props层的方块
	if props_data:
		_handle_regular_block(tile_pos, props_data, props)
	# 再处理dirt层的方块
	elif dirt_data:
		_handle_regular_block(tile_pos, dirt_data, dirt)

## 处理爆炸物（炸弹和炸药块）
func _handle_explosives(tile_pos: Vector2i) -> bool:
	var boom_coords: Vector2i = world.atlas_map[world.BOOM] if "atlas_map" in world and "BOOM" in world else Vector2i(7, 5)
	var is_boom_in_dirt: bool = false
	var is_boom_in_props: bool = false
	var boom_layer: TileMapLayer = null
	
	# 检查dirt层是否是炸药块
	var dirt_atlas_coords: Vector2i = dirt.get_cell_atlas_coords(tile_pos)
	if dirt.get_cell_source_id(tile_pos) != -1:
		is_boom_in_dirt = (dirt_atlas_coords == boom_coords)
		if is_boom_in_dirt:
			boom_layer = dirt
	
	# 检查props层是否是炸药块
	var props_atlas_coords: Vector2i = props.get_cell_atlas_coords(tile_pos)
	if props.get_cell_source_id(tile_pos) != -1:
		is_boom_in_props = (props_atlas_coords == boom_coords)
		if is_boom_in_props:
			boom_layer = props
	
	# 检查该位置是否有其他炸弹
	var bomb_at_pos: Node = _find_bomb_at_position(tile_pos)
	
	if bomb_at_pos:
		print("[Bomb] 引爆其他炸弹: ", tile_pos)
		bomb_at_pos.explode()
		return true
	
	if is_boom_in_dirt or is_boom_in_props:
		_trigger_chain_explosion(tile_pos, boom_layer)
		return true
	
	return false

## 在指定位置查找炸弹
func _find_bomb_at_position(tile_pos: Vector2i) -> Node:
	var bombs: Array = get_tree().get_nodes_in_group("bombs")
	for bomb in bombs:
		var bomb_tile_pos = dirt.local_to_map(dirt.to_local(bomb.global_position))
		if bomb_tile_pos == tile_pos and bomb != self:
			return bomb
	return null

## 触发连锁爆炸
func _trigger_chain_explosion(tile_pos: Vector2i, layer: TileMapLayer = null) -> void:
	print("[Bomb] 引爆炸药块: ", tile_pos)
	
	# 如果没有指定层，默认使用dirt
	if layer == null:
		layer = dirt
	
	# 清除炸药块
	layer.erase_cell(tile_pos)
	
	var new_bomb: Node = load("res://Items/Bomb.tscn").instantiate()
	get_parent().add_child(new_bomb)
	new_bomb.global_position = layer.to_global(layer.map_to_local(tile_pos))
	
	# 设置更大的爆炸范围
	new_bomb.explosion_radius = explosion_radius * config.chain_explosion_multiplier
	new_bomb.call_deferred("explode")

## 处理普通方块
func _handle_regular_block(tile_pos: Vector2i, tile_data: TileData, layer: TileMapLayer = null) -> void:
	# 如果没有指定层，默认使用dirt
	if layer == null:
		layer = dirt
		
	# 对方块造成伤害
	var current_health: int = tile_data.get_custom_data("health") if tile_data else 1
	var health: int = current_health - damage
	print("[Bomb] 方块血量变化: ", tile_pos, " ", health + damage, " -> ", health)
	
	if health <= 0:
		_destroy_block(tile_pos, layer)
	else:
		_update_block_health(tile_pos, tile_data, health, layer)

## 销毁方块
func _destroy_block(tile_pos: Vector2i, layer: TileMapLayer = null) -> void:
	# 如果没有指定层，默认使用dirt
	if layer == null:
		layer = dirt
		
	layer.erase_cell(tile_pos)
	if "health_manager" in layer:
		layer.health_manager.remove_health_bar(tile_pos)
	print("[Bomb] 销毁方块: ", tile_pos)

## 更新方块血量
func _update_block_health(tile_pos: Vector2i, tile_data: TileData, health: int, layer: TileMapLayer = null) -> void:
	# 如果没有指定层，默认使用dirt
	if layer == null:
		layer = dirt
		
	tile_data.set_custom_data("health", health)
	
	# 更新血条显示
	if "health_manager" in layer:
		if not layer.tile_max_health.has(tile_pos):
			layer.tile_max_health[tile_pos] = tile_data.get_custom_data("health") + damage
		var total: int = layer.tile_max_health[tile_pos]
		layer.health_manager.update_tile_health(tile_pos, health, total)

## 播放爆炸效果
func _play_explosion_effects() -> void:
	$ColorRect.hide()
	$CountdownLabel.text = "BOOM!"
	
	$Boom.emitting = true
	$Boom.one_shot = true
	
	$Debris.emitting = true
	$Debris.one_shot = true
	
	# 等待粒子效果完成后销毁
	var timer = get_tree().create_timer(1.2)
	await timer.timeout
	
	emit_signal("exploded")
	queue_free()

## 处理倒计时
func _process(delta: float) -> void:
	# 只处理未爆炸的炸弹
	if is_exploding:
		return
		
	# 更新调试显示
	if show_debug:
		queue_redraw()
	
	# 更新倒计时
	time_left -= delta
	var display_time: float = max(0.0, time_left)
	$CountdownLabel.text = str(ceil(display_time))
	
	# 检查是否应该爆炸
	if time_left <= 0:
		if not $Timer.is_stopped():
			$Timer.stop()
			_on_timer_timeout()
	# 最后一秒闪烁提示
	elif time_left <= 1.0:
		$ColorRect.color.a = 0.5 + sin(time_left * 10) * 0.5

## 显示调试信息时重绘
func _exit_tree() -> void:
	if show_debug:
		queue_redraw()

## 计算瓦片受到的伤害值
func calculate_tile_damage(_distance: float, _radius: float) -> int:
	return damage

## 定时器超时回调
func _on_timer_timeout() -> void:
	$ExplosionArea/CollisionShape2D.disabled = false
	explode()
