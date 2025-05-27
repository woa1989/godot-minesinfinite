extends CharacterBody2D

@onready var animateSprite = $AnimatedSprite2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const WALL_SLIDING_SPEED = 1200

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var jumpsMade = 0
var doWallJump = false

func _physics_process(delta: float) -> void:
	var direction = Input.get_axis(&"left", &"right")
	
	if is_on_wall_only() && (Input.is_action_just_pressed(&"left") || Input.is_action_just_pressed(&"right")):
		velocity.y = WALL_SLIDING_SPEED * delta
	elif not is_on_floor():
		velocity.y += gravity * delta
	else:
		jumpsMade = 0
	
	if Input.is_action_just_pressed(&"ui_accept"):
		if is_on_wall_only():
			velocity.y = JUMP_VELOCITY
			velocity.x = - direction * SPEED
			doWallJump = true
			$WallJumpTimer.start()
		elif is_on_floor() || jumpsMade < 2:
			velocity.y = JUMP_VELOCITY
			jumpsMade += 1
	
	if direction && not doWallJump: velocity.x = direction * SPEED
	elif not doWallJump: velocity.x = move_toward(velocity.x, 0, SPEED)
	
	_setAnimation(direction)
	move_and_slide()
	

func _setAnimation(direction):
	if velocity.x > 0: animateSprite.flip_h = false
	elif velocity.x < 0: animateSprite.flip_h = true
	elif velocity.x == 0:
		if direction > 0: animateSprite.flip_h = false
		elif direction > 0: animateSprite.flip_h = true
		
	if is_on_wall_only() && (velocity.x != 0 && direction != 0):
		animateSprite.flip_h = !animateSprite.flip_h
		
	if !is_on_floor(): animateSprite.play("jump")
	elif direction != 0: animateSprite.play("run")
	else: animateSprite.play("idle")
		
func _on_wall_jump_timer_timeout():
	doWallJump = false
