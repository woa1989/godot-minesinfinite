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

func _ready() -> void:
	if navigation:
		navigation.target_position = CheseTarget.global_position
		HitTimer.connect("timeout", _check_hit)
		HitTimer.wait_time = hitDelay

func _physics_process(_delta: float) -> void:
	if not navigation:
		print("No navigation agent!")
		return
		
	if haveTarget:
		if not is_instance_valid(CheseTarget):
			print("Invalid target!")
			return
			
		navigation.target_position = CheseTarget.global_position
		print("Target position: ", CheseTarget.global_position)
		
		if not navigation.is_target_reachable():
			print("Target is not reachable!")
		
		if navigation.is_navigation_finished():
			print("Navigation finished!")
			return
			
		var next_path_position = navigation.get_next_path_position()
		print("Next path position: ", next_path_position)
		
		velocity = (next_path_position - global_position).normalized() * SPEED
		print("Velocity: ", velocity)
		
		shape.look_at(next_path_position)
	else:
		checkPlayer()
		
	move_and_slide()

func _check_hit() -> void:
	for body in HitBox.get_overlapping_bodies():
		if body.is_in_group("player"):
			body.GetHit(damage)
			HitAnimation()


func HitAnimation() -> void:
	ParticleHit.emitting = true
	if not SoundPlayer.playing:
		SoundPlayer.stream = AttackStream
		SoundPlayer.play()


func die() -> void:
	queue_free()

func checkPlayer() -> void:
	if not DetectArea:
		return
		
	for body in DetectArea.get_overlapping_bodies():
		if body.is_in_group("player"):
			print("Found player!")
			CheseTarget = body
			haveTarget = true
			return
