class_name TileSetCustomData
extends RefCounted

# 初始化TileSet的自定义数据层
static func init_custom_data(tileset: TileSet) -> Dictionary:
	if not tileset:
		push_error("[TileSetDataHelper] Tileset为空!")
		return {}
	

	
	# 获取或创建自定义数据层
	var health_layer_id = -1
	var value_layer_id = -1
	
	# 检查是否已存在所需的数据层
	for i in range(tileset.get_custom_data_layers_count()):
		var layer_name = tileset.get_custom_data_layer_name(i)
		if layer_name == "health":
			health_layer_id = i
		elif layer_name == "value":
			value_layer_id = i
	
	# 如果health层不存在，创建它
	if health_layer_id == -1:
		health_layer_id = tileset.get_custom_data_layers_count()
		tileset.add_custom_data_layer()
		tileset.set_custom_data_layer_name(health_layer_id, "health")
		tileset.set_custom_data_layer_type(health_layer_id, TYPE_INT)

	else:
		print("[TileSetDataHelper] 找到现有的health层，ID: ", health_layer_id)
	
	# 如果value层不存在，创建它
	if value_layer_id == -1:
		value_layer_id = tileset.get_custom_data_layers_count()
		tileset.add_custom_data_layer()
		tileset.set_custom_data_layer_name(value_layer_id, "value")
		tileset.set_custom_data_layer_type(value_layer_id, TYPE_INT)
		print("[TileSetDataHelper] 已创建value层，ID: ", value_layer_id)
	else:
		print("[TileSetDataHelper] 找到现有的value层，ID: ", value_layer_id)
	
	# 获取所有源
	var source_count = tileset.get_source_count()
	if source_count == 0:
		push_error("[TileSetDataHelper] 没有找到任何源!")
		return {}
	
	print("[TileSetDataHelper] 共找到 ", source_count, " 个源")
	
	# 遍历所有源
	for source_index in range(source_count):
		var source_id = tileset.get_source_id(source_index)
		var source = tileset.get_source(source_id)
		if not source is TileSetAtlasSource:
			continue
			
		var atlas_source = source as TileSetAtlasSource
		print("[TileSetDataHelper] 处理源 ", source_index, " (ID: ", source_id, ")")
		
		# 获取所有图块
		var tile_count = 0
		for x in range(atlas_source.texture.get_width() / atlas_source.texture_region_size.x):
			for y in range(atlas_source.texture.get_height() / atlas_source.texture_region_size.y):
				var tile_pos = Vector2i(x, y)
				if atlas_source.has_tile(tile_pos):
					var tile_data = atlas_source.get_tile_data(tile_pos, 0)
					if tile_data:
						# 设置默认值
						tile_data.set_custom_data_by_layer_id(health_layer_id, 1)
						tile_data.set_custom_data_by_layer_id(value_layer_id, 1)
						tile_count += 1
		print("[TileSetDataHelper] 在源 ", source_id, " 中找到 ", tile_count, " 个图块")
	
	print("[TileSetDataHelper] 成功初始化tileset自定义数据层")
	return {"health_id": health_layer_id, "value_id": value_layer_id}

# 验证tileset是否有所需的自定义数据
static func validate_custom_data(tileset: TileSet) -> bool:
	if not tileset:
		return false
	
	# 获取第一个源
	var source_id = tileset.get_source_id(0)
	if source_id < 0:
		return false
		
	var source = tileset.get_source(source_id) as TileSetAtlasSource
	if not source:
		return false
	
	# 确保至少有两个自定义数据层
	if tileset.get_custom_data_layers_count() < 2:
		return false
		
	# 获取health和value层的ID
	var health_layer_id = -1
	var value_layer_id = -1
	for i in range(tileset.get_custom_data_layers_count()):
		var layer_name = tileset.get_custom_data_layer_name(i)
		if layer_name == "health":
			health_layer_id = i
		elif layer_name == "value":
			value_layer_id = i
	
	if health_layer_id == -1 or value_layer_id == -1:
		return false
		
	# 遍历找到第一个有效的图块
	var found_valid_tile = false
	for y in range(16): # 假设图块集不会超过16x16
		for x in range(16):
			var pos = Vector2i(x, y)
			if source.has_tile(pos):
				var tile_data = source.get_tile_data(pos, 0)
				if tile_data:
					# 检查是否能获取自定义数据
					var health = tile_data.get_custom_data_by_layer_id(health_layer_id)
					var value = tile_data.get_custom_data_by_layer_id(value_layer_id)
					if health != null and value != null:
						found_valid_tile = true
						break
		if found_valid_tile:
			break
			
	return found_valid_tile
