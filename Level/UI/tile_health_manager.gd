extends Node2D

const TileHealthBar = preload("res://Level/UI/TileHealthBar.tscn")
@onready var tilemap = get_parent()
var health_bars = {} # 存储所有血条 {Vector2i: TileHealthBar}

# 创建或更新瓦片血条
func update_tile_health(tile_pos: Vector2i, current_health: int, max_health: int):
	if current_health <= 0:
		# 如果血量为0，移除血条
		remove_health_bar(tile_pos)
		return
		
	var health_bar
	if health_bars.has(tile_pos):
		health_bar = health_bars[tile_pos]
	else:
		health_bar = TileHealthBar.instantiate()
		add_child(health_bar)
		health_bars[tile_pos] = health_bar
		
		# 设置血条位置（根据瓦片地图坐标）
		var local_pos = tilemap.map_to_local(tile_pos)
		# 将血条定位在瓦片左上角偏移16单位的位置，x轴额外偏移10单位
		health_bar.position = local_pos + Vector2(4, 16)

	health_bar.set_health(current_health, max_health)

# 移除指定位置的血条
func remove_health_bar(tile_pos: Vector2i):
	if health_bars.has(tile_pos):
		var health_bar = health_bars[tile_pos]
		health_bars.erase(tile_pos)
		health_bar.queue_free()
