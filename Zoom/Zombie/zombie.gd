extends CharacterBody2D

const SPEED = 150.0

@onready var navigation: NavigationAgent2D = $NavigationAgent2D
@onready var shape: Node2D = $Shape
@onready var HitBox: Area2D = $Shape/Hit_Box
@onready var HitTimer: Timer = $HitTimer
@onready var ParticleHit: GPUParticles2D = $Shape/GPUParticles2D
@onready var SoundPlayer: AudioStreamPlayer = $AudioStreamPlayer
@onready var DetectArea: Area2D = $DetectArea

@export var CheseTarget: Node2D = Node2D.new()

const AttackStream = preload("res://Zoom/Audios/zattack.wav")

var damage: int = 15
var hitDelay: float = 0.5
var haveTarget: bool = false
var last_valid_position: Vector2
var stuck_timer: float = 0.0
var stuck_threshold: float = 2.0 # 卡住检测时间
var last_position: Vector2
var position_check_timer: float = 0.0
var direct_move_timer: float = 0.0
var direct_move_duration: float = 1.0

func _ready() -> void:
	if navigation:
		navigation.target_position = CheseTarget.global_position
		HitTimer.connect("timeout", _check_hit)
		HitTimer.wait_time = hitDelay
		HitTimer.start() # 启动攻击计时器
		last_valid_position = global_position
		last_position = global_position

func _physics_process(delta: float) -> void:
	if not navigation:
		print("No navigation agent!")
		return
		
	if haveTarget:
		if not is_instance_valid(CheseTarget):
			print("Invalid target!")
			haveTarget = false
			return
			
		navigation.target_position = CheseTarget.global_position
		
		# 检查是否卡住
		_check_if_stuck(delta)
		
		# 如果正在直接移动模式
		if direct_move_timer > 0:
			direct_move_timer -= delta
			_move_directly_to_target()
		else:
			# 正常导航模式
			if navigation.is_target_reachable():
				_navigate_to_target()
			else:
				print("Target is not reachable, trying direct movement!")
				direct_move_timer = direct_move_duration
				_move_directly_to_target()
	else:
		checkPlayer()
		
	move_and_slide()

func _check_if_stuck(delta: float) -> void:
	position_check_timer += delta
	
	if position_check_timer >= 0.5: # 每0.5秒检查一次位置
		var distance_moved = global_position.distance_to(last_position)
		
		if distance_moved < 10.0: # 如果移动距离很小
			stuck_timer += position_check_timer
		else:
			stuck_timer = 0.0
			last_valid_position = global_position
			
		last_position = global_position
		position_check_timer = 0.0
		
		# 如果卡住时间超过阈值，切换到直接移动模式
		if stuck_timer >= stuck_threshold:
			print("Zombie seems stuck, switching to direct movement!")
			stuck_timer = 0.0
			direct_move_timer = direct_move_duration

func _navigate_to_target() -> void:
	if navigation.is_navigation_finished():
		return
		
	var next_path_position = navigation.get_next_path_position()
	velocity = (next_path_position - global_position).normalized() * SPEED
	shape.look_at(next_path_position)

func _move_directly_to_target() -> void:
	# 直接朝目标移动，忽略导航
	var direction = (CheseTarget.global_position - global_position).normalized()
	velocity = direction * SPEED
	shape.look_at(CheseTarget.global_position)
	
	# 添加一些随机偏移来避免完全卡住
	var random_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	velocity += random_offset

func die() -> void:
	print("Zombie died!")
	GlobalVars.kill_zombie() # 统计击杀
	# 通知游戏管理器检查游戏状态
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.check_game_status()
	ParticleHit.emitting = true
	queue_free() # 销毁丧尸

func _check_hit() -> void:
	if not HitBox:
		return
		
	for body in HitBox.get_overlapping_bodies():
		if body.is_in_group("player"):
			if body.has_method("GetHit"):
				print("Hit player!")
				body.GetHit(damage)
				HitAnimation()


func HitAnimation() -> void:
	ParticleHit.emitting = true
	if not SoundPlayer.playing:
		SoundPlayer.stream = AttackStream
		SoundPlayer.play()


func checkPlayer() -> void:
	if not DetectArea:
		return
		
	for body in DetectArea.get_overlapping_bodies():
		if body.is_in_group("player"):
			print("Found player!")
			CheseTarget = body
			haveTarget = true
			HitTimer.start() # 发现玩家时启动攻击计时器
			return
