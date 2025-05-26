extends RigidBody2D

signal exploded

var time_left = 3.0
var explosion_radius: float = 96.0 # 设置为64 * 1.5，刚好覆盖3x3范围
var damage: int = 2
var dirt: TileMapLayer # 使用 TileMapLayer 类型
var world: Node2D
var is_exploding = false # 防止重复爆炸
var show_debug = false # 调试模式开关

func _ready():
	# 添加到炸弹组便于追踪
	add_to_group("bombs")
	
	# 获取World节点引用
	world = get_parent()
	# 尝试获取Dirt节点（TileMapLayer）
	dirt = get_node_or_null("/root/Level/World/Dirt") as TileMapLayer
	if not dirt:
		push_error("无法找到Dirt节点，请确认节点路径是否正确")
		return
	
	# 设置物理属性
	mass = 1.0 # 设置质量
	linear_damp = 2.0 # 设置线性阻尼，使炸弹更快停止
	
	# 创建并设置物理材质
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = 1.0 # 设置摩擦力系数
	physics_material_override = physics_material
	
	# 连接信号
	if not $Timer.timeout.is_connected(_on_timer_timeout):
		$Timer.timeout.connect(_on_timer_timeout)
	$CountdownLabel.text = str(ceil(time_left))
	
	# 启用处理函数
	set_process(show_debug)
	queue_redraw()

func _draw():
	if show_debug and not is_exploding:
		# 使用瓦片大小来转换半径，确保显示和实际效果一致
		var cell_size = 64 # 每个瓦片是64x64像素
		var radius_in_tiles = explosion_radius / cell_size
		var display_radius = radius_in_tiles * cell_size
		
		draw_arc(Vector2.ZERO, display_radius, 0, TAU, 32, Color(1, 0, 0, 0.3), 2.0)
		draw_circle(Vector2.ZERO, 2, Color(1, 0, 0)) # 中心点
		# 绘制爆炸范围的半径线
		for i in 4:
			var angle = i * PI / 2
			var end = Vector2(cos(angle), sin(angle)) * display_radius
			draw_line(Vector2.ZERO, end, Color(1, 0, 0, 0.5), 1.0)

func set_explosion_radius(radius: float):
	explosion_radius = radius

func set_damage(new_damage: int):
	damage = new_damage

func explode():
	if is_exploding:
		return
		
	is_exploding = true
	
	if dirt and world:
		print("[Bomb] 开始爆炸处理...")
		# 将全局位置转换为瓦片坐标
		var center_tile = dirt.local_to_map(dirt.to_local(global_position))
		print("[Bomb] 爆炸中心瓦片坐标: ", center_tile)
		
		var affected_tiles = []
		
		# 获取3x3范围内的所有瓦片
		for x in range(-1, 2): # -1, 0, 1 刚好是3x3范围
			for y in range(-1, 2): # -1, 0, 1 刚好是3x3范围
				affected_tiles.append(Vector2i(x, y))
		
		# 按距离排序，使爆炸从中心向外扩散
		affected_tiles.sort_custom(func(a, b): return a.length_squared() < b.length_squared())
		
		# 遍历范围内的所有方块
		for offset in affected_tiles:
			var tile_pos = center_tile + offset
			print("[Bomb] 检查坐标: ", tile_pos)
			
			# 检查该位置是否有瓦片
			var source_id = dirt.get_cell_source_id(tile_pos)
			if source_id != -1: # -1 表示该位置没有瓦片
				print("[Bomb] 发现方块: ", tile_pos)
				
				# 获取瓦片的数据和属性
				var tile_data = dirt.get_cell_tile_data(tile_pos)
				var atlas_coords = dirt.get_cell_atlas_coords(tile_pos)
				var boom_coords = world.atlas_map[world.BOOM] if "atlas_map" in world and "BOOM" in world else Vector2i(7, 5)
				var is_boom = atlas_coords == boom_coords
				
				# 检查该位置是否有其他炸弹
				var bombs = get_tree().get_nodes_in_group("bombs")
				var bomb_at_pos = null
				for bomb in bombs:
					if dirt.local_to_map(dirt.to_local(bomb.global_position)) == tile_pos and bomb != self:
						bomb_at_pos = bomb
						break
						
				# 先处理炸弹
				if bomb_at_pos:
					print("[Bomb] 引爆其他炸弹: ", tile_pos)
					bomb_at_pos.explode()
					continue
				
				# 对方块造成伤害
				var health = tile_data.get_custom_data("health") if tile_data else 1
				health = health - damage
				print("[Bomb] 方块血量变化: ", tile_pos, " ", health + damage, " -> ", health)
				
				if health <= 0:
					# 清除方块
					dirt.erase_cell(tile_pos)
					# 移除血条
					if "health_manager" in dirt:
						dirt.health_manager.remove_health_bar(tile_pos)
					print("[Bomb] 销毁方块: ", tile_pos)
					
					# 如果是炸药块，创建新的爆炸
					if is_boom:
						print("[Bomb] 引爆炸药块: ", tile_pos)
						var new_bomb = load("res://Items/Bomb.tscn").instantiate()
						get_parent().add_child(new_bomb)
						new_bomb.global_position = dirt.to_global(dirt.map_to_local(tile_pos))
						# 设置更大的爆炸范围
						new_bomb.explosion_radius = explosion_radius * 1.2 # 增加20%的爆炸范围
						# 使用 call_deferred 防止堆栈溢出
						new_bomb.call_deferred("explode")
				else:
					# 更新方块血量
					tile_data.set_custom_data("health", health)
					# 更新血条显示
					if "health_manager" in dirt and tile_data:
						# 获取或设置最大血量
						if not dirt.tile_max_health.has(tile_pos):
							dirt.tile_max_health[tile_pos] = tile_data.get_custom_data("health") + damage
						var total = dirt.tile_max_health[tile_pos]
						# 更新血条
						dirt.health_manager.update_tile_health(tile_pos, health, total)
	
	# 播放爆炸效果
	$ColorRect.hide()
	$CountdownLabel.text = "BOOM!"
	
	# 触发爆炸粒子效果
	$Boom.emitting = true
	$Boom.one_shot = true
	
	# 触发碎片粒子效果
	$Debris.emitting = true
	$Debris.one_shot = true
	
	# 等待粒子效果完成
	await get_tree().create_timer(1.2).timeout
	
	# 移除炸弹
	emit_signal("exploded")
	queue_free()

func _process(delta):
	# 如果倒计时已经结束，不执行任何操作
	if time_left <= 0:
		return

	if show_debug:
		queue_redraw()

	time_left -= delta
	# 确保倒计时不会显示负数
	var display_time = max(0, time_left)
	$CountdownLabel.text = str(ceil(display_time))
	
	# 检查是否应该触发爆炸
	if time_left <= 0 and not $Timer.is_stopped():
		$Timer.stop()
		_on_timer_timeout()
	# 最后一秒闪烁提示
	elif time_left <= 1.0:
		$ColorRect.color.a = 0.5 + sin(time_left * 10) * 0.5

func _exit_tree():
	if show_debug:
		queue_redraw()

# 计算瓦片受到的伤害值
func calculate_tile_damage(_distance: float, _radius: float) -> int:
	# 固定伤害值为1
	return 1

func _on_timer_timeout():
	# 启用爆炸区域碰撞
	$ExplosionArea/CollisionShape2D.disabled = false
	
	# 直接调用爆炸函数
	explode()
