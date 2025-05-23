extends CharacterBody2D

# 信号
signal dig(tile_pos: Vector2i, direction: String)
signal slide()

# 参数
const MOVE_SPEED = 180.0
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
var wall_jump_ready: bool = false # 只有主动跳起空中碰墙才能爬墙
var wall_jump_cooldown: float = 0.0 # 墙跳冷却时间
const WALL_JUMP_COOLDOWN_TIME: float = 0.5 # 墙跳冷却时间（秒）
var wall_climb_timer: float = 0.0 # 爬墙持续时间
const MAX_WALL_CLIMB_TIME: float = 2.0 # 最大爬墙时间（秒）
var is_jumping: bool = false # 只有主动跳起才为true

func _ready():
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	# 确保DigTimer节点存在
	if has_node("DigTimer"):
		# 设置挖掘计时器的默认时间(秒)为挖掘动画的大致时长
		$DigTimer.wait_time = 0.6
		$DigTimer.one_shot = true # 设置为单次触发
	
	# 确保AnimatedSprite2D的dig动画设置为非循环播放
	if $AnimatedSprite2D and $AnimatedSprite2D.sprite_frames:
		$AnimatedSprite2D.sprite_frames.set_animation_loop("dig", false)
		
	# 手动连接animation_finished信号
	if not $AnimatedSprite2D.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		$AnimatedSprite2D.connect("animation_finished", Callable(self, "_on_animation_finished"))

func _physics_process(delta):
	var input_dir = Input.get_axis("left", "right")
	var on_floor = is_on_floor()
	
	on_wall = is_on_wall() and not on_floor
	# 保证 wall_dir 只要 on_wall 就有值
	if on_wall:
		var normal = get_wall_normal().x
		if normal > 0:
			wall_dir = -1
		elif normal < 0:
			wall_dir = 1
		# 如果 normal == 0，保持上一次的 wall_dir
	else:
		wall_dir = 0

	# 只有主动跳起（is_jumping为true）空中碰墙才能爬墙
	if on_wall and not on_floor and is_jumping:
		if not wall_jump_ready:
			wall_climb_timer = 0.0 # 刚进入爬墙时重置计时
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
		if slide_timer <= 0 or not Input.is_action_pressed("down"):
			is_sliding = false
		else:
			move_and_slide()
			return

	# 按键移动
	if not is_sliding and not mining: # 添加 mining 检查，防止打断挖掘动画
		if input_dir != 0:
			player_velocity.x = input_dir * MOVE_SPEED
			$AnimatedSprite2D.scale.x = input_dir
			if on_floor and not mining: # 添加 mining 检查
				$AnimatedSprite2D.play("run")
			elif not mining: # 添加 mining 检查
				$AnimatedSprite2D.play("jump")
		else:
			player_velocity.x = 0 # 松开方向键立即停止
			if on_floor and not mining: # 添加 mining 检查
				$AnimatedSprite2D.play("idle")

	# 跳跃/二段跳/墙跳
	if Input.is_action_just_pressed("jump") and not mining: # 添加 mining 检查
		if on_floor:
			player_velocity.y = JUMP_VELOCITY
			can_double_jump = true
			is_jumping = true
			$AnimatedSprite2D.play("jump")
			if $AudioStreamPlayer2D:
				$AudioStreamPlayer2D.play()
		elif wall_jump_ready and wall_jump_cooldown <= 0 and on_wall:
			# 只要在爬墙状态，按跳跃就能墙跳，方向自动给反方向
			var wall_jump_input_dir = - wall_dir
			player_velocity.y = JUMP_VELOCITY
			player_velocity.x = wall_jump_input_dir * MOVE_SPEED * 2.0
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
	if wall_jump_ready and on_wall and not mining: # 添加 mining 检查
		if wall_climb_timer < MAX_WALL_CLIMB_TIME:
			player_velocity.y = 0
			player_velocity.x = 0
			$AnimatedSprite2D.play("climb")
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
		var new_mining_dir = ""
		var new_mining_pos = Vector2i.ZERO
		
		# 确定挖掘方向
		if Input.is_action_pressed("up"):
			new_mining_dir = "up"
			new_mining_pos = get_tile_pos(Vector2(0, -32))
		elif Input.is_action_pressed("down"):
			new_mining_dir = "down"
			new_mining_pos = get_tile_pos(Vector2(0, 32))
		elif input_dir > 0:
			new_mining_dir = "right"
			new_mining_pos = get_tile_pos(Vector2(32, 0))
		elif input_dir < 0:
			new_mining_dir = "left"
			new_mining_pos = get_tile_pos(Vector2(-32, 0))
		
		if new_mining_dir != "":
			mining = true
			mining_dir = new_mining_dir
			mining_pos = new_mining_pos
			$AnimatedSprite2D.play("dig")
			# 设置动画播放模式为非循环
			$AnimatedSprite2D.sprite_frames.set_animation_loop("dig", false)
			
			# 播放音效和粒子效果
			if $AudioStreamPlayer2D:
				$AudioStreamPlayer2D.play()
			if has_node("DigParticles2D"):
				$DigParticles2D.restart()
			
			# 启动挖掘计时器，控制挖掘动画时长
			if has_node("DigTimer"):
				$DigTimer.stop() # 先停止计时器，确保重新开始计时
				$DigTimer.start() # 使用默认的时间

	velocity = player_velocity
	move_and_slide()

func get_tile_pos(offset: Vector2) -> Vector2i:
	var tilemap = get_node_or_null("/root/Level/World/Dirt")
	if tilemap:
		var local_pos = tilemap.to_local(global_position + offset)
		return tilemap.local_to_map(local_pos)
	return Vector2i.ZERO

# 记录上一个动画状态
var previous_animation = ""

# 当动画改变时被触发
func _on_animated_sprite_2d_animation_changed():
	var current_animation = $AnimatedSprite2D.animation
	
	# 只有当从挖掘动画切换到其他动画时才处理，并且确保不是刚开始播放挖掘动画
	if previous_animation == "dig" and current_animation != "dig" and mining:
		print("动画从dig变为了", current_animation, "，由动画系统自动切换")
		mining = false
		mining_dir = ""
	
	# 更新上一个动画记录
	previous_animation = current_animation

# 挖掘计时器超时时触发
func _on_dig_timer_timeout():
	if mining:
		print("挖掘计时器到时，结束挖掘")
		# 在计时器超时时也触发挖掘信号
		emit_signal("dig", mining_pos, mining_dir)
		mining = false
		mining_dir = ""
		# 根据角色当前状态选择合适的动画
		if is_on_floor():
			$AnimatedSprite2D.play("idle")
		else:
			$AnimatedSprite2D.play("jump")

# AnimatedSprite2D动画播放完成时触发
func _on_animation_finished():
	# 只在挖掘动画完成时处理
	if $AnimatedSprite2D.animation == "dig" and mining:
		print("挖掘动画播放完成")
		# 在动画完成时触发挖掘信号
		emit_signal("dig", mining_pos, mining_dir)
		mining = false
		mining_dir = ""
		# 根据角色当前状态选择合适的动画
		if is_on_floor():
			$AnimatedSprite2D.play("idle")
		else:
			$AnimatedSprite2D.play("jump")
