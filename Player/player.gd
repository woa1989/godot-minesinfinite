extends CharacterBody2D

# 信号
signal dig(tile_pos: Vector2i, direction: String)
signal slide()

# 参数
const MOVE_SPEED = 100.0
const JUMP_VELOCITY = -300.0
const SLIDE_SPEED = 500.0
const SLIDE_TIME = 0.25
const SLIDE_COOLDOWN = 0.6
const WALL_SLIDE_SPEED = 80.0
var GRAVITY = 1200.0 # 默认值，_ready中赋值

# 状态
var player_velocity: Vector2 = Vector2.ZERO
var can_double_jump: bool = true
var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_cooldown: float = 0.0
var on_wall: bool = false
var wall_dir: int = 0 # -1左墙 1右墙
var mining: bool = false
var mining_dir: String = ""
var mining_pos: Vector2i = Vector2i.ZERO
var wall_jump_ready: bool = false # 只有跳跃时才允许爬墙

func _ready():
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	var input_dir = Input.get_axis("left", "right")
	var on_floor = is_on_floor()
	var was_on_wall = on_wall
	on_wall = is_on_wall() and not on_floor
	wall_dir = 0
	if on_wall:
		wall_dir = -1 if get_wall_normal().x > 0 else 1

	# 只有跳跃时碰墙才允许爬墙
	if on_wall and not was_on_wall and player_velocity.y < 0:
		wall_jump_ready = true
	elif on_floor:
		wall_jump_ready = false
	elif not on_wall:
		wall_jump_ready = false

	# 滑铲冷却
	if slide_cooldown > 0:
		slide_cooldown -= delta

	# 滑铲逻辑
	if not is_sliding and slide_cooldown <= 0 and on_floor and Input.is_action_pressed("down") and input_dir != 0:
		is_sliding = true
		slide_timer = SLIDE_TIME
		slide_cooldown = SLIDE_COOLDOWN
		player_velocity.x = input_dir * SLIDE_SPEED
		$AnimatedSprite2D.play("sliding")
		emit_signal("slide") # 播放音效/粒子
		if $AudioStreamPlayer2D:
			$AudioStreamPlayer2D.play()

	# 滑铲中
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0 or not Input.is_action_pressed("down"):
			is_sliding = false
		else:
			move_and_slide()
			return

	# 按键移动
	if not is_sliding:
		if input_dir != 0:
			player_velocity.x = input_dir * MOVE_SPEED
			$AnimatedSprite2D.scale.x = input_dir
			if on_floor:
				$AnimatedSprite2D.play("run")
			else:
				$AnimatedSprite2D.play("jump")
		else:
			player_velocity.x = move_toward(player_velocity.x, 0, MOVE_SPEED * delta)
			if on_floor:
				$AnimatedSprite2D.play("idle")

	# 跳跃/二段跳
	if Input.is_action_just_pressed("jump"):
		if on_floor:
			player_velocity.y = JUMP_VELOCITY
			can_double_jump = true
			$AnimatedSprite2D.play("jump")
			if $AudioStreamPlayer2D:
				$AudioStreamPlayer2D.play()
		elif wall_jump_ready:
			player_velocity.y = JUMP_VELOCITY
			player_velocity.x = - wall_dir * MOVE_SPEED * 1.2
			can_double_jump = true
			$AnimatedSprite2D.play("jump")
			if $AudioStreamPlayer2D:
				$AudioStreamPlayer2D.play()
			wall_jump_ready = false
		elif can_double_jump:
			player_velocity.y = JUMP_VELOCITY
			can_double_jump = false
			$AnimatedSprite2D.play("jump")
			if $AudioStreamPlayer2D:
				$AudioStreamPlayer2D.play()

	# 墙滑（只有跳跃时碰墙才允许）
	if on_wall and wall_jump_ready and not on_floor and player_velocity.y > 0:
		player_velocity.y = WALL_SLIDE_SPEED
		$AnimatedSprite2D.play("climb")

	# 重力
	if not on_floor and not (on_wall and wall_jump_ready):
		player_velocity.y += GRAVITY * delta
	elif on_floor and player_velocity.y > 0:
		player_velocity.y = 0

	# 挖矿（空中也可挖）
	if Input.is_action_pressed("dig") and not mining:
		if Input.is_action_pressed("up"):
			mining_dir = "up"
			mining_pos = get_tile_pos(Vector2(0, -32))
		elif Input.is_action_pressed("down"):
			mining_dir = "down"
			mining_pos = get_tile_pos(Vector2(0, 32))
		elif input_dir > 0:
			mining_dir = "right"
			mining_pos = get_tile_pos(Vector2(32, 0))
		elif input_dir < 0:
			mining_dir = "left"
			mining_pos = get_tile_pos(Vector2(-32, 0))
		if mining_dir != "":
			mining = true
			$AnimatedSprite2D.play("dig")
			emit_signal("dig", mining_pos, mining_dir)
			if $AudioStreamPlayer2D:
				$AudioStreamPlayer2D.play()
			# 粒子播放接口（如有）
			if has_node("DigParticles2D"):
				$DigParticles2D.restart()

	if mining and $AnimatedSprite2D.animation != "dig":
		mining = false
		mining_dir = ""

	velocity = player_velocity
	move_and_slide()

func get_tile_pos(offset: Vector2) -> Vector2i:
	var tilemap = get_node_or_null("/root/Level/World/Dirt")
	if tilemap:
		var local_pos = tilemap.to_local(global_position + offset)
		return tilemap.local_to_map(local_pos)
	return Vector2i.ZERO
