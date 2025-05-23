extends CharacterBody2D

# 信号
signal dig(tile_pos: Vector2i, direction: String) # 挖掘信号
signal slide() # 滑铲信号

# 主要参数
const MOVE_SPEED = 180.0 # 水平移动速度
const JUMP_VELOCITY = -300.0 # 跳跃初速度
const SLIDE_SPEED = 500.0 # 滑铲速度
const SLIDE_TIME = 0.25 # 滑铲持续时间
const SLIDE_COOLDOWN = 0.6 # 滑铲冷却
const BOMB_THROW_FORCE = Vector2(200, -200) # 炸弹投掷力度
const Bomb = preload("res://Items/Bomb.tscn")
var GRAVITY = 1200.0 # 重力（启动时赋值）

# 状态变量
var player_velocity: Vector2 = Vector2.ZERO # 玩家速度
var can_double_jump: bool = true # 是否可以二段跳
var is_sliding: bool = false # 是否处于滑铲
var slide_timer: float = 0.0 # 滑铲计时
var slide_cooldown: float = 0.0 # 滑铲冷却计时
var on_wall: bool = false # 是否贴墙
var wall_dir: int = 0 # -1左墙 1右墙
var wall_jump_ready: bool = false # 是否可以爬墙/墙跳
var wall_jump_cooldown: float = 0.0 # 墙跳冷却
const WALL_JUMP_COOLDOWN_TIME: float = 0.5 # 墙跳冷却时间
var wall_climb_timer: float = 0.0 # 爬墙持续时间
const MAX_WALL_CLIMB_TIME: float = 2.0 # 最大爬墙时间
var is_jumping: bool = false # 是否主动跳起
var mining: bool = false # 是否正在挖掘
var mining_dir: String = "" # 挖掘方向
var mining_pos: Vector2i = Vector2i.ZERO # 挖掘目标格子

func _ready():
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

	# 挖掘动画设为非循环
	if $AnimatedSprite2D.sprite_frames:
		$AnimatedSprite2D.sprite_frames.set_animation_loop("dig", false)

func _physics_process(delta):
	var input_dir = Input.get_axis("left", "right")
	var on_floor = is_on_floor()
	on_wall = is_on_wall() and not on_floor

	# 计算墙体方向
	if on_wall:
		var normal = get_wall_normal().x
		if normal > 0:
			wall_dir = -1
		elif normal < 0:
			wall_dir = 1
	else:
		wall_dir = 0

	# 只有主动跳起空中碰墙才能爬墙
	if on_wall and not on_floor and is_jumping:
		if not wall_jump_ready:
			wall_climb_timer = 0.0
		wall_jump_ready = true
		wall_climb_timer += delta
	else:
		wall_jump_ready = false
		wall_climb_timer = 0.0

	# 墙跳冷却
	if wall_jump_cooldown > 0:
		wall_jump_cooldown -= delta

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
		emit_signal("slide")
		if $AudioStreamPlayer2D:
			$AudioStreamPlayer2D.play()

	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			is_sliding = false
			$AnimatedSprite2D.play("idle")
		else:
			velocity = player_velocity
			move_and_slide()
			if not Input.is_action_pressed("down"):
				is_sliding = false
				$AnimatedSprite2D.play("idle")
			return

	# 按键移动（无惯性，松开立即停）
	if not is_sliding and not mining:
		if input_dir != 0:
			player_velocity.x = input_dir * MOVE_SPEED
			$AnimatedSprite2D.scale.x = input_dir
			if on_floor:
				$AnimatedSprite2D.play("run")
			else:
				$AnimatedSprite2D.play("jump")
		else:
			player_velocity.x = 0
			if on_floor:
				$AnimatedSprite2D.play("idle")

	# 跳跃/二段跳/墙跳
	if Input.is_action_just_pressed("jump") and not mining:
		if on_floor:
			player_velocity.y = JUMP_VELOCITY
			can_double_jump = true
			is_jumping = true
			$AnimatedSprite2D.play("jump")
			if $AudioStreamPlayer2D:
				$AudioStreamPlayer2D.play()
		elif wall_jump_ready and wall_jump_cooldown <= 0 and on_wall:
			# 墙跳，方向自动给反方向
			player_velocity.y = JUMP_VELOCITY
			player_velocity.x = - wall_dir * MOVE_SPEED * 2.0
			can_double_jump = true
			is_jumping = true
			$AnimatedSprite2D.play("jump")
			if $AudioStreamPlayer2D:
				$AudioStreamPlayer2D.play()
			wall_jump_ready = false
			wall_climb_timer = 0.0
			wall_jump_cooldown = WALL_JUMP_COOLDOWN_TIME
		elif can_double_jump:
			player_velocity.y = JUMP_VELOCITY
			can_double_jump = false
			is_jumping = true
			$AnimatedSprite2D.play("jump")
			if $AudioStreamPlayer2D:
				$AudioStreamPlayer2D.play()

	# 爬墙动画和静止逻辑（无墙滑）
	if wall_jump_ready and on_wall and not mining:
		if wall_climb_timer < MAX_WALL_CLIMB_TIME:
			player_velocity.y = 0
			player_velocity.x = 0
			$AnimatedSprite2D.play("climb")
			# 上墙时角色面朝离开墙的方向
			if wall_dir > 0:
				$AnimatedSprite2D.scale.x = 1
			elif wall_dir < 0:
				$AnimatedSprite2D.scale.x = -1
		else:
			# 超时后直接掉落
			wall_jump_ready = false
			is_jumping = false

	# 重力
	if not on_floor and not (on_wall and wall_jump_ready):
		player_velocity.y += GRAVITY * delta
	elif on_floor and player_velocity.y > 0:
		player_velocity.y = 0

	# 挖矿（空中也可挖）
	if Input.is_action_pressed("dig") and not mining:
		var dir = ""
		var pos = Vector2i.ZERO
		if Input.is_action_pressed("up"):
			dir = "up"
			pos = get_tile_pos(Vector2(0, -32))
		elif Input.is_action_pressed("down"):
			dir = "down"
			pos = get_tile_pos(Vector2(0, 32))
		elif input_dir > 0:
			dir = "right"
			pos = get_tile_pos(Vector2(32, 0))
		elif input_dir < 0:
			dir = "left"
			pos = get_tile_pos(Vector2(-32, 0))
		if dir != "":
			mining = true
			mining_dir = dir
			mining_pos = pos
			$AnimatedSprite2D.play("dig")
			if $AudioStreamPlayer2D:
				$AudioStreamPlayer2D.play()
			if has_node("DigParticles2D"):
				$DigParticles2D.restart()

	velocity = player_velocity
	move_and_slide()

# 挖掘动画播放完后，重置挖掘状态并发射信号
func _on_animation_finished():
	if $AnimatedSprite2D.animation == "dig" and mining:
		emit_signal("dig", mining_pos, mining_dir)
		mining = false
		mining_dir = ""
		# 挖掘后切回idle或jump动画
		if is_on_floor():
			$AnimatedSprite2D.play("idle")
		else:
			$AnimatedSprite2D.play("jump")

# 计算目标瓦片格子
func get_tile_pos(offset: Vector2) -> Vector2i:
	var tilemap = get_node_or_null("/root/Level/World/Dirt")
	if tilemap:
		var local_pos = tilemap.to_local(global_position + offset)
		return tilemap.local_to_map(local_pos)
	return Vector2i.ZERO

func _unhandled_input(event):
	if event.is_action_pressed("throw_bomb") and Global.dynamite_remaining > 0:
		throw_bomb()

func throw_bomb():
	if Global.dynamite_remaining <= 0:
		return
		
	# 创建炸弹实例
	var bomb = Bomb.instantiate()
	get_parent().add_child(bomb)
	bomb.position = position
	
	# 根据玩家朝向设置投掷方向
	var direction = sign($AnimatedSprite2D.scale.x) # 使用sign函数获取方向，1表示右，-1表示左
	var impulse = Vector2(BOMB_THROW_FORCE.x * direction, BOMB_THROW_FORCE.y)
	bomb.apply_central_impulse(impulse)
	
	# 减少炸弹数量
	Global.dynamite_remaining -= 1
	
	# TODO: 播放投掷动画和音效
