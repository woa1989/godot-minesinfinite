extends Node2D

@onready var WarningSprite: Sprite2D = $warningShap
@onready var LaunchTimer: Timer = $LaunthTimer
@onready var TimerLabel: Label = $TimerLabel
@onready var SoundPlayer: AudioStreamPlayer = $AudioStreamPlayer

const launchStream = preload("res://Zoom/Audios/weapons/launch.wav")

var BulletScene: PackedScene = load("res://Zoom/Player/FireBall.tscn")
var bullet: Area2D

var LaunchaDone: bool = false
var launch_direction: Vector2
var player: CharacterBody2D

func _ready() -> void:
	LaunchTimer.one_shot = true
	LaunchTimer.start(2)
	LaunchTimer.connect("timeout", _on_LaunchTimer_timeout)
	# 找到玩家节点
	player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if not is_instance_valid(LaunchTimer):
		return
		
	if not LaunchaDone:
		launchPart()
	else:
		UpdateBullet()


func launchPart() -> void:
	if is_instance_valid(WarningSprite) and is_instance_valid(TimerLabel):
		# 实时跟随玩家瞄准方向和枪口位置
		if is_instance_valid(player):
			var target_rotation = player.shape.rotation
			rotation = target_rotation
			# 跟随玩家枪口位置
			global_position = player.Muzzle.global_position
		
		WarningSprite.offset.x = WarningSprite.get_rect().size.x / 2
		WarningSprite.scale.x = lerp(WarningSprite.scale.x, 0.8, 0.05)
		TimerLabel.text = str(int(LaunchTimer.time_left))
		
		# 使瞄准线闪烁效果更明显
		var time_ratio = LaunchTimer.time_left / 2.0
		var flash_speed = 8.0
		WarningSprite.modulate.a = 0.5 + 0.5 * sin(time_ratio * flash_speed)
		
		# 根据剩余时间改变颜色
		if time_ratio < 0.3:
			WarningSprite.modulate = Color.RED
		elif time_ratio < 0.6:
			WarningSprite.modulate = Color.YELLOW
		else:
			WarningSprite.modulate = Color.WHITE

func makeFireBall() -> void:
	if BulletScene:
		bullet = BulletScene.instantiate()
		if bullet:
			# 在创建火球时重新计算发射方向，确保使用正确的旋转角度
			launch_direction = Vector2.RIGHT.rotated(rotation)
			
			get_tree().current_scene.add_child(bullet)
			bullet.global_position = global_position
			bullet.rotation = rotation
			# 确保火球获得正确的发射方向
			bullet.set_launch_direction(launch_direction)
			LaunchaDone = true
			print("FireBall created at position: ", bullet.global_position, " with direction: ", launch_direction)

func UpdateBullet():
	# 火球现在自己管理移动，SuperCannonBall 不再控制火球移动
	if not is_instance_valid(bullet):
		return
		
	# 检查火球是否仍然存在和有效
	if bullet == null or not is_instance_valid(bullet):
		bullet = null


func _on_LaunchTimer_timeout() -> void:
	if is_instance_valid(WarningSprite):
		WarningSprite.queue_free()
	if is_instance_valid(TimerLabel):
		TimerLabel.queue_free()
	SoundPlayer.stream = launchStream
	SoundPlayer.play()
	makeFireBall() # 立即创建火球
	await get_tree().create_timer(10).timeout
	queue_free()
