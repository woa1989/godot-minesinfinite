extends Node2D

@onready var WarningSprite: Sprite2D = $warningShap
@onready var LaunchTimer: Timer = $LaunthTimer
@onready var TimerLabel: Label = $TimerLabel
@onready var SoundPlayer: AudioStreamPlayer = $AudioStreamPlayer

const launchStream = preload("res://Zoom/Audios/weapons/launch.wav")

var BulletScene: PackedScene = load("res://Zoom/Player/FireBall.tscn")
var bullet: Area2D

var LaunchaDone: bool = false

func _ready() -> void:
	LaunchTimer.one_shot = true
	LaunchTimer.start(2)
	LaunchTimer.connect("timeout", _on_LaunchTimer_timeout)

func _process(_delta: float) -> void:
	if not LaunchaDone:
		launchPart()
	else:
		UpdateBullet()


func launchPart() -> void:
	WarningSprite.offset.x = WarningSprite.get_rect().size.x / 2
	WarningSprite.scale.x = lerp(WarningSprite.scale.x, 0.8, 0.05)
	TimerLabel.text = str(int(LaunchTimer.time_left))

func makeFireBall() -> void:
	bullet = BulletScene.instantiate()
	add_child(bullet)
	LaunchaDone = true

func UpdateBullet():
	bullet.position.x += 10
	for body in bullet.get_overlapping_bodies():
		if body.is_in_group("zombie"):
			body.die()


func _on_LaunchTimer_timeout() -> void:
	WarningSprite.queue_free()
	TimerLabel.queue_free()
	SoundPlayer.stream = launchStream
	SoundPlayer.play()
	await get_tree().create_timer(10).timeout
	queue_free()
