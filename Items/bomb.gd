extends RigidBody2D

signal exploded

var time_left = 3.0

func set_explosion_radius(radius: float):
	# 设置爆炸区域的半径
	$ExplosionArea/CollisionShape2D.shape.radius = radius

func explode():
	_on_timer_timeout()

func _ready():
	$Timer.timeout.connect(_on_timer_timeout)
	$CountdownLabel.text = str(ceil(time_left))
	
func _process(delta):
	# 如果倒计时已经结束，不执行任何操作
	if time_left <= 0:
		return
		
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
	
func _on_timer_timeout():
	# 启用爆炸区域碰撞
	$ExplosionArea/CollisionShape2D.disabled = false
	
	# 直接获取World节点中的Dirt节点
	var world = get_tree().get_root().get_node("Level/World")
	if world:
		var dirt = world.get_node("Dirt")
		if dirt:
			# 获取爆炸圆心的位置
			var center = global_position
			# 获取爆炸半径
			var radius = $ExplosionArea/CollisionShape2D.shape.radius
			# 计算可能受影响的瓦片范围
			var tile_radius = ceil(radius / 64.0) # 假设瓦片大小是64x64
			
			# 遍历爆炸范围内的所有瓦片
			var affected_tiles = [] # 存储受影响的瓦片，以便稍后处理
			for x in range(-tile_radius, tile_radius + 1):
				for y in range(-tile_radius, tile_radius + 1):
					var tile_pos = dirt.local_to_map(dirt.to_local(center))
					tile_pos += Vector2i(x, y)
					
					# 计算瓦片中心到爆炸中心的距离
					var tile_center = dirt.map_to_local(tile_pos)
					tile_center = dirt.to_global(tile_center)
					var distance = center.distance_to(tile_center)
					
					# 如果在爆炸半径内，处理瓦片
					if distance <= radius:
						affected_tiles.append(tile_pos)
			
			# 处理受影响的瓦片
			for tile_pos in affected_tiles:
				var tile_data = dirt.get_cell_tile_data(tile_pos)
				if tile_data:
					# 获取瓦片的atlas_coords以检查是否是炸药
					var atlas_coords = dirt.get_cell_atlas_coords(tile_pos)
					var is_boom = (atlas_coords == Vector2i(7, 5))
					
					if is_boom:
						# 如果是炸药，则触发其爆炸效果
						# 触发炸药爆炸，血量会在 damage_tile 中处理
						dirt.damage_tile(tile_pos, tile_data.get_custom_data_by_layer_id(dirt.health_layer_id))
					else:
						# 如果不是炸药，直接破坏
						dirt.erase_cell(tile_pos)
	
	# 播放爆炸效果
	$ColorRect.hide() # 隐藏炸弹图形
	$CountdownLabel.text = "BOOM!"
	
	# 触发爆炸粒子效果
	$Boom.emitting = true
	$Boom.one_shot = true
	
	# 触发碎片粒子效果
	$Debris.emitting = true
	$Debris.one_shot = true
	
	# 等待粒子效果完成（略微增加等待时间以适应新的粒子效果）
	await get_tree().create_timer(1.2).timeout
	
	# 移除炸弹
	emit_signal("exploded")
	queue_free()
