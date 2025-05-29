extends Node2D

var is_paused: bool = false
var alert_scene: PackedScene = preload("res://Zoom/Level/Alerm.tscn")
var alert_instance: Node = null

func _ready() -> void:
	# 监听 UI 中 Stop 按钮的点击
	var ui = $CanvasLayer/UI
	var stop_button = ui.get_node("Stop")
	if stop_button:
		stop_button.pressed.connect(_on_stop_pressed)

func _input(event: InputEvent) -> void:
	# 监听 ESC 键
	if event.is_action_pressed("pause_game") and not event.is_echo():
		_toggle_pause()

func _on_stop_pressed() -> void:
	_toggle_pause()

func _toggle_pause() -> void:
	if is_paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	if alert_instance:
		return # 已经暂停了
		
	is_paused = true
	get_tree().paused = true
	
	# 实例化 Alert 场景
	alert_instance = alert_scene.instantiate()
	add_child(alert_instance)
	
	# 连接 Alert 的信号
	var alert_container = alert_instance.get_node("Control/Alert")
	if alert_container:
		# 连接 back 按钮信号
		alert_container.back_pressed.connect(_resume_game)
		# 连接 exit 按钮信号 
		alert_container.exit_pressed.connect(_exit_to_main)

func _resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	
	if alert_instance:
		alert_instance.queue_free()
		alert_instance = null

func _exit_to_main() -> void:
	is_paused = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Zoom/MainScene/MainScene.tscn")
