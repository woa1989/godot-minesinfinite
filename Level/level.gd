extends Node2D

const MapData = preload("res://Level/map_data.gd")
const TileSetDataHelper = preload("res://Level/tileset_custom_data.gd")

func _ready():
	$CanvasLayer/ToTownButton.pressed.connect(to_town)
	# 初始化当前地图
	init_map()
	
func to_town():
	get_tree().change_scene_to_file("res://Town/Town.tscn")

func init_map():
	# 从Global获取当前地图ID
	var map_id = Global.current_map_id
	var map_data = null
	
	# 查找对应的地图数据
	for data in MapData.MAPS.values():
		if data.id == map_id:
			map_data = data
			break
			
	if map_data:
		# 先设置基本的tileset
		$World/Map.tile_set = map_data.tilemap
		# 等待两帧确保tileset完全加载
		await get_tree().process_frame
		await get_tree().process_frame
		
		# 初始化自定义数据层
		var result = TileSetDataHelper.init_custom_data($World/Map.tile_set)
		if not result:
			push_error("初始化tileset数据层失败!")
			return
			
		# 设置当前地图,这个函数是异步的
		await $World.set_current_map(map_id)
		
		# 再次检查tileset是否有效
		if not $World.is_valid_tileset():
			push_error("Tileset初始化失败,重试...")
			# 重新尝试设置tileset
			$World/Map.tile_set = map_data.tilemap.duplicate()
			await get_tree().process_frame
			if not $World.is_valid_tileset():
				push_error("Tileset重试失败!")
				return
		
		print("[Level] Tileset初始化成功")
		
		# 如果已有缓存的地图,则加载它
		if Global.has_existing_mine:
			$World._load_cached_chunks() # 修正：使用正确的函数名
			%Player.global_position = Global.player_last_mine_position
		else:
			# 重置玩家位置
			%Player.position = Vector2.ZERO
			# 初始加载区块
			$World.update_chunks()
			Global.has_existing_mine = true
