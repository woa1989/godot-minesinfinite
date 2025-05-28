class_name Player
extends CharacterBody2D

signal dig_down
signal dig_left
signal dig_right
signal dynamite
signal died

@export var speed := 200
@export var fly_accel := 50
@export var idle_fuel_burn_rate := 1.0
@export var active_fuel_burn_rate := 2.0

@onready var Anim = $Digger/AnimationPlayer

var vel := Vector2.ZERO
var mining := false


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func get_input():
	vel.x = 0
	var move_speed = speed
	
	if Input.is_action_pressed("Right"):
		vel.x += move_speed
		$Digger.scale.x = -1
	if Input.is_action_pressed("Left"):
		vel.x -= move_speed
		$Digger.scale.x = 1


func _physics_process(delta):
	if Global.in_store or Global.loading:
		return
	
	get_input()
	
	if Input.is_action_pressed("Fly") or Input.is_action_pressed("Up"):
		mining = false
		Anim.play("Fly")
		vel.y -= fly_accel * delta
		if vel.y < -Global.terminal_velocity:
			vel.y = -Global.terminal_velocity
	else:
		vel.y += Global.gravity * delta
		if vel.y > Global.terminal_velocity:
			Anim.play("Fly")
			vel.y = Global.terminal_velocity
	set_velocity(vel)
	set_up_direction(Vector2.UP)
	move_and_slide()
	vel = velocity
	
	if Input.is_action_just_pressed("Action"):
		emit_signal("dynamite")
	
	
	# Don't mine while flying
	if is_on_floor():
		if Input.is_action_pressed("Down") and !mining:
			mine_below()
		
		if Input.is_action_pressed("Left") and !mining:
			mine_left()
		
		if Input.is_action_pressed("Right") and !mining:
			mine_right()
	
	Global.player_fuel -= delta * idle_fuel_burn_rate
	if vel.length() > 0.1:
		Global.player_fuel -= delta * active_fuel_burn_rate
	if Global.player_fuel < -5:
		die()


func die():
	emit_signal("died")
	vel = Vector2.ZERO


func mine_below():
	if is_on_floor() and Global.tile_below.tile_type != Global.TileType.ROCK:
		mining = true
		if Anim.assigned_animation == "Digging_Down":
			Anim.play("Digging_Down", -1, 2)
			emit_signal("dig_down")
		else:
			Anim.play("Deploy_Down")


func mine_left():
	if is_on_wall() and Global.tile_left.tile_type != Global.TileType.ROCK:
		mining = true
		if Anim.assigned_animation == "Digging_Side":
			Anim.play("Digging_Side", -1, 2)
			emit_signal("dig_left")
		else:
			Anim.play("Deploy_Side")


func mine_right():
	if is_on_wall() and Global.tile_right.tile_type != Global.TileType.ROCK:
		mining = true
		if Anim.assigned_animation == "Digging_Side":
			Anim.play("Digging_Side", -1, 2)
			emit_signal("dig_right")
		else:
			Anim.play("Deploy_Side", -1)


func _on_AnimationPlayer_animation_finished(anim_name):
	
	if anim_name == "Deploy_Down":
		Anim.play("Digging_Down", -1, 2)
		emit_signal("dig_down")
	
	elif anim_name == "Deploy_Side":
		Anim.play("Digging_Side", -1, 2)
		if $Digger.scale.x > 0:
			emit_signal("dig_left")
		else:
			emit_signal("dig_right")
	
	else:
		if anim_name == "Digging_Side" and mining:
			mining = false
			if $Digger.scale.x > 0:
				if Input.is_action_pressed("Left"):
					mine_left()
			else:
				if Input.is_action_pressed("Right"):
					mine_right()
		
		elif anim_name == "Digging_Down" and mining:
			mining = false
			if Input.is_action_pressed("Down"):
				mine_below()
		
		if anim_name != "Idle" and !mining:
			Anim.play("Idle")
