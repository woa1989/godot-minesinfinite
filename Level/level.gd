extends Node2D

const MapData = preload("res://Level/map_data.gd")
const TileSetDataHelper = preload("res://Level/tileset_custom_data.gd")

# 添加调试变量
var debug_timer: Timer
var last_cache_size: int = -1
var last_print_time: int = 0

func _ready():
	$CanvasLayer/ToTownButton.pressed.connect(to_town)
	# 初始化当前地图
	init_map()
	
	# 添加调试功能
	_setup_debug_monitoring()
	
	# 添加持久化测试 (仅在调试模式下)
	if OS.is_debug_build():
		_setup_persistence_test()

# 添加调试监控功能 (优化版本，减少输出)
func _setup_debug_monitoring():
	debug_timer = Timer.new()
	debug_timer.wait_time = 10.0 # 增加间隔时间
	debug_timer.autostart = true
	debug_timer.timeout.connect(_debug_cache_status)
	add_child(debug_timer)
	
	# 立即输出一次状态
	await get_tree().create_timer(2.0).timeout
	_debug_cache_status()

func _debug_cache_status():
	# 简化输出，只显示关键信息
	var cache_size = Global.loaded_chunks_cache.size()
	var current_time = Time.get_ticks_msec()
	
	# 只在状态发生变化或每分钟输出一次
	var should_print = false
	
	if last_cache_size != cache_size or (current_time - last_print_time) > 60000:
		last_cache_size = cache_size
		last_print_time = current_time
		should_print = true
	
	if should_print:
		print("[Level] 缓存:", cache_size, "区块 | 矿洞:", Global.has_existing_mine, " | 种子:", Global.noise_seed)

func to_town():
	# 保存玩家在矿洞中的最后位置
	Global.player_last_mine_position = %Player.global_position
	print("[Level] 保存玩家位置:", Global.player_last_mine_position)
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
			push_error("[Level] 初始化tileset数据层失败!")
			return
			
		# 设置当前地图
		await $World.set_current_map(map_id)
		
		# 再次检查tileset是否有效
		if not $World.is_valid_tileset():
			push_error("[Level] Tileset初始化失败,重试...")
			# 重新尝试设置tileset
			$World/Map.tile_set = map_data.tilemap.duplicate()
			await get_tree().process_frame
			if not $World.is_valid_tileset():
				push_error("[Level] Tileset重试失败!")
				return
		
		print("[Level] Tileset初始化成功")
		
		# 如果已有缓存的地图,则加载它
		if Global.has_existing_mine:
			$World._load_cached_chunks() # 加载之前的地图状态
			%Player.global_position = Global.player_last_mine_position
			print("[Level] 从缓存加载地图 - 玩家位置:", Global.player_last_mine_position, " 噪声种子:", Global.noise_seed)
		else:
			# 重置玩家位置
			%Player.position = Vector2.ZERO
			# 初始加载区块
			$World.update_chunks()
			Global.has_existing_mine = true
			print("[Level] 初始化新地图 - 使用噪声种子:", Global.noise_seed)

# 添加持久化测试功能 (减少输出版本)
func _setup_persistence_test():
	# 仅在明确需要时才进行持久化测试 - 默认禁用以减少输出
	if not Global.debug_cache_verbose:
		print("[Level] 持久化测试已禁用（可通过Global.debug_cache_verbose启用）")
		return
