extends Node2D

@onready var shop_ui = $CanvasLayer/ShopUI
@onready var status_label = $CanvasLayer/ShopUI/Panel/VBoxContainer/StatusLabel
@onready var currency_label = $CanvasLayer/ShopUI/CurrencyLabel

const MapData = preload("res://Level/map_data.gd")

var loading_screen

func _ready():
	# 连接按钮信号
	var health_btn = $CanvasLayer/ShopUI/Panel/VBoxContainer/HealthPotion
	var fuel_btn = $CanvasLayer/ShopUI/Panel/VBoxContainer/FuelTank
	var dynamite_btn = $CanvasLayer/ShopUI/Panel/VBoxContainer/Dynamite
	var cargo_btn = $CanvasLayer/ShopUI/Panel/VBoxContainer/CargoUpgrade
	var mine_btn = $CanvasLayer/ShopUI/Panel/VBoxContainer/ToMine
	
	health_btn.pressed.connect(func(): buy_item(Global.ShopItem.HEALTH_POTION))
	fuel_btn.pressed.connect(func(): buy_item(Global.ShopItem.FUEL_TANK))
	dynamite_btn.pressed.connect(func(): buy_item(Global.ShopItem.DYNAMITE))
	cargo_btn.pressed.connect(func(): buy_item(Global.ShopItem.CARGO_UPGRADE))
	mine_btn.pressed.connect(to_mine)
	
	Global.in_store = true
	
	setup_loading_screen()
	setup_map_selection()

func _process(_delta):
	currency_label.text = "金币: %d" % Global.currency

func buy_item(item: Global.ShopItem):
	if Global.buy_item(item):
		status_label.text = "购买成功!"
	else:
		status_label.text = "金币不足!"
	
func to_mine():
	Global.in_store = false
	# 切换到矿洞场景，保持现有的loaded_chunks_cache
	get_tree().change_scene_to_file("res://Level/level.tscn")

func setup_loading_screen():
	var LoadingScreen = load("res://Level/UI/LoadingScreen.tscn")
	loading_screen = LoadingScreen.instantiate()
	add_child(loading_screen)

func setup_map_selection():
	# 创建地图选择容器
	var map_container = VBoxContainer.new()
	map_container.custom_minimum_size = Vector2(250, 250)
	
	# 创建一个Panel作为背景
	var panel = Panel.new()
	panel.custom_minimum_size = map_container.custom_minimum_size
	panel.position = Vector2(350, 100) # 调整位置到更合适的高度
	
	# 创建一个MarginContainer来添加内边距
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	
	# 将panel添加到CanvasLayer中
	$CanvasLayer.add_child(panel)
	panel.add_child(margin)
	margin.add_child(map_container)
	
	# 添加标题
	var title = Label.new()
	title.text = "选择地图"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, 30)
	title.add_theme_font_size_override("font_size", 16) # 调整标题字体大小
	map_container.add_child(title)
	
	# 添加分隔符
	var separator = HSeparator.new()
	map_container.add_child(separator)
	
	# 为每个地图创建按钮
	for map_name in MapData.MAPS:
		var map_data = MapData.MAPS[map_name]
		
		# 创建按钮
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 45)
		
		# 使用水平布局容器
		var button_container = HBoxContainer.new()
		button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_child(button_container)
		
		# 创建垂直布局来放置名称和描述
		var text_container = VBoxContainer.new()
		text_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button_container.add_child(text_container)
		
		# 添加地图名称标签
		var name_label = Label.new()
		name_label.text = map_name
		name_label.add_theme_font_size_override("font_size", 14)
		text_container.add_child(name_label)
		
		# 添加地图描述标签
		var desc_label = Label.new()
		desc_label.text = map_data.description
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.modulate = Color(0.8, 0.8, 0.8)
		text_container.add_child(desc_label)
		
		button.pressed.connect(func(): enter_map(map_data.id))
		map_container.add_child(button)
		
		# 在按钮之间添加小间距
		if map_name != MapData.MAPS.keys()[-1]:
			var btn_separator = HSeparator.new()
			map_container.add_child(btn_separator)
			
var loading_progress = 0
func enter_map(map_id: String):
	# 保存要进入的地图ID
	Global.current_map_id = map_id
	
	loading_screen.show_loading()
	loading_progress = 0
	
	# 创建一个计时器来模拟加载过程
	var loading_timer = Timer.new()
	add_child(loading_timer)
	loading_timer.wait_time = 0.05 # 50毫秒更新一次
	loading_timer.one_shot = false
	
	loading_timer.timeout.connect(func():
		loading_progress += 5
		loading_screen.update_progress(loading_progress, "正在准备地图...")
		
		if loading_progress >= 100:
			loading_timer.stop()
			loading_timer.queue_free()
			# 切换到Level场景
			get_tree().change_scene_to_file("res://Level/level.tscn")
	)
	
	loading_timer.start()
