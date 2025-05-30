extends CharacterBody2D

const SPEED = 300.0

var Hp: int = 100

@onready var shape: Node2D = $shape
@onready var HPBar: ProgressBar = $ProgressBar
@onready var SoundPlayer: AudioStreamPlayer = $AudioStreamPlayer
@onready var Muzzle: Node2D = $shape/muzzle
@onready var FreezeTimer: Timer = $FreezeTimer

const HitSoundStream = preload("res://Zoom/Audios/Human_Hitted.wav")
const DieSoundStream = preload("res://Zoom/Audios/Human_die.wav")
const ChargeStream = preload("res://Zoom/Audios/weapons/charge.wav")
const CannonBall = preload("res://Zoom/Player/SuperCannonBall.tscn")

var FreezeTime: float = 2.0
var Is_Dead: bool = false
var CanMove: bool = true # 蓄力时不能移动

func _ready() -> void:
	FreezeTimer.connect("timeout", _on_FreezeTimer_timeout)
	pass

func _physics_process(_delta: float) -> void:
	if CanMove:
		var direction = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))
		
		if direction:
			velocity = direction * SPEED
		else:
			velocity = velocity.lerp(Vector2.ZERO, 0.1)
		
	
	move_and_slide()
	
	# # 打印碰撞信息
	# for i in get_slide_collision_count():
	# 	var collision = get_slide_collision(i)
	# 	print("Colliding with: ", collision.get_collider())
	# 	print("Normal: ", collision.get_normal())
	# 	print("Position: ", collision.get_position())

func _process(_delta: float) -> void:
	LookMounse()
	UpdateUI()
	if (Input.is_action_just_pressed("dig") and GlobalVars.bullets > 0):
		shoot()


func LookMounse() -> void:
	# 即使不能移动，也可以瞄准
	shape.look_at(get_global_mouse_position())

func UpdateUI() -> void:
	HPBar.value = Hp
	pass

func GetHit(Damage: int) -> void:
	if not Is_Dead:
		if not SoundPlayer.playing:
			SoundPlayer.stream = HitSoundStream
			SoundPlayer.play(0.0)
		Hp -= Damage
		if Hp <= 0:
			Die()


func Die() -> void:
	Is_Dead = true
	SoundPlayer.stream = DieSoundStream
	SoundPlayer.play(0.0)
	await SoundPlayer.finished
	# 重置游戏状态，包括子弹数
	GlobalVars.reset_game()
	get_tree().change_scene_to_packed(load("res://Zoom/MainScene/MainScene.tscn"))


func shoot() -> void:
	# 射击无法移动
	if GlobalVars.use_bullet():
		var c = CannonBall.instantiate()
		get_tree().current_scene.add_child(c)
		c.global_position = Muzzle.global_position
		c.rotation = shape.rotation
		SoundPlayer.stream = ChargeStream
		SoundPlayer.play(0.0)
		FreezeTimer.start(FreezeTime)
		CanMove = false
		velocity = Vector2.ZERO
		
		# 检查是否用完了所有子弹
		if GlobalVars.bullets <= 0:
			var game_manager = get_node("/root/GameManager")
			if game_manager:
				game_manager.check_game_status()
	
		
func _on_FreezeTimer_timeout() -> void:
	CanMove = true
	pass
