extends Node2D

@export var map_start_position := Vector2(0, 0)
@export var player_start_position := Vector2(100, 50)

func _ready():
	# 使用Global配置或备用本地配置
	var map_pos = Global.default_map_position if Global.default_map_position != Vector2.ZERO else map_start_position
	var player_pos = Global.default_player_position if Global.default_player_position != Vector2.ZERO else player_start_position
	
	# 设置世界位置
	if has_node("World"):
		var world = $World
		world.world_position = map_pos
		world.position = map_pos
		
	# 设置玩家位置
	if has_node("Player"):
		var player = $Player
		player.position = player_pos
		
	# 连接世界加载完成信号
	if has_node("World"):
		var world = $World
		world.connect("world_load_complete", Callable(self, "_on_world_load_complete"))

# 当世界加载完成时，更新全局玩家位置
func _on_world_load_complete():
	if has_node("Player"):
		Global.player_location = $Player.position
		print("[Level Manager] 地图加载完成，玩家位置: ", $Player.position)
		
		# 确保玩家相机激活 - 调用玩家的专门方法
		if $Player.has_method("activate_player_camera"):
			$Player.activate_player_camera()
			print("[Level Manager] 通过玩家方法激活相机")
		# 备用方案 - 直接激活相机
		elif $Player.has_node("PlayerCamera2D"):
			$Player.get_node("PlayerCamera2D").make_current()
			print("[Level Manager] 玩家相机已激活")
