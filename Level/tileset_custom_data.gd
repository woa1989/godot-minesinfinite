class_name TileSetCustomData
extends RefCounted

# 初始化TileSet的自定义数据层
static func init_custom_data(tileset: TileSet):
	# 检查是否已存在自定义数据层
	var has_health_layer = false
	var has_value_layer = false
	var health_layer_id = -1
	var value_layer_id = -1
	
	# 查找是否已有自定义数据层
	for i in range(tileset.get_custom_data_layers_count()):
		var layer_name = tileset.get_custom_data_layer_name(i)
		if layer_name == "health":
			has_health_layer = true
			health_layer_id = i
		elif layer_name == "value":
			has_value_layer = true
			value_layer_id = i
	
	# 添加血量层（如果不存在）
	if not has_health_layer:
		tileset.add_custom_data_layer()
		health_layer_id = tileset.get_custom_data_layers_count() - 1
		tileset.set_custom_data_layer_name(health_layer_id, "health")
		tileset.set_custom_data_layer_type(health_layer_id, TYPE_INT)
		print("[TileSet] 添加了自定义数据层: health")
	
	# 添加价值层（如果不存在）
	if not has_value_layer:
		tileset.add_custom_data_layer()
		value_layer_id = tileset.get_custom_data_layers_count() - 1
		tileset.set_custom_data_layer_name(value_layer_id, "value")
		tileset.set_custom_data_layer_type(value_layer_id, TYPE_INT)
		print("[TileSet] 添加了自定义数据层: value")
	
	return {"health_id": health_layer_id, "value_id": value_layer_id}

# 获取自定义数据层的ID
static func get_custom_data_layer_ids(tileset: TileSet) -> Dictionary:
	var result = {
		"health": - 1,
		"value": - 1
	}
	
	# 查找自定义数据层
	for i in range(tileset.get_custom_data_layers_count()):
		var layer_name = tileset.get_custom_data_layer_name(i)
		if layer_name == "health":
			result.health = i
		elif layer_name == "value":
			result.value = i
	
	return result
