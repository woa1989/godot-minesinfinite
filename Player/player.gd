extends CharacterBody2D

# 信号
signal dig(tile_pos: Vector2i, direction: String) # 发射挖掘信号，包含目标位置和方向

# === 基础物理参数 ===
const MOVE_SPEED: float = 180.0 # 水平移动速度
const JUMP_VELOCITY: float = -300.0 # 跳跃初速度（负值表示向上）
const BOMB_THROW_FORCE: Vector2 = Vector2(200, -200) # 炸弹投掷力度(x,y)
var GRAVITY: float # 重力加速度（在_ready中初始化）

# === 移动状态 ===
var player_velocity: Vector2 = Vector2.ZERO # 玩家当前速度向量

# === 跳跃相关状态 ===
var can_double_jump: bool = true # 是否可以执行二段跳
var is_jumping: bool = false # 是否处于主动跳跃状态

# === 墙壁相关状态 ===
var on_wall: bool = false # 是否贴墙
var wall_dir: int = 0 # 墙体方向：-1左墙、1右墙、0无墙
var wall_jump_ready: bool = false # 是否可以执行墙跳
var wall_jump_cooldown: float = 0.0 # 墙跳冷却计时器
const WALL_JUMP_COOLDOWN_TIME: float = 0.5 # 墙跳冷却时间
var wall_climb_timer: float = 0.0 # 当前爬墙持续时间
const MAX_WALL_CLIMB_TIME: float = 2.0 # 最大爬墙时间

# === 挖掘相关状态 ===
var mining: bool = false # 是否正在挖掘
var mining_dir: String = "" # 挖掘方向
var mining_pos: Vector2i = Vector2i.ZERO # 挖掘目标格子位置

# === 预加载资源 ===
const Bomb = preload("res://Items/Bomb.tscn") # 预加载炸弹场景

# === 初始化 ===
func _ready() -> void:
	# 从项目设置获取重力值
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	
	# 设置挖掘动画为非循环
	if $AnimatedSprite2D.sprite_frames:
		$AnimatedSprite2D.sprite_frames.set_animation_loop("dig", false)

# === 主要物理处理 ===
func _physics_process(delta: float) -> void:
	var input_dir: float = Input.get_axis("left", "right") # 获取水平输入
	var on_floor: bool = is_on_floor() # 检查是否在地面
	
	_update_wall_state(on_floor) # 更新墙壁状态
	_update_jump_state(on_floor) # 更新跳跃状态
	_handle_wall_climb(delta, on_floor) # 处理墙壁攀爬
	_handle_movement(input_dir, on_floor) # 处理移动
	_handle_jump_input(on_floor) # 处理跳跃输入
	_apply_gravity(delta, on_floor) # 应用重力
	_handle_mining_input(input_dir) # 处理挖掘输入
	
	# 应用最终速度并移动
	velocity = player_velocity
	move_and_slide()

# === 墙壁状态更新 ===
func _update_wall_state(on_floor: bool) -> void:
	on_wall = is_on_wall() and not on_floor
	if on_wall:
		wall_dir = -1 if get_wall_normal().x > 0 else 1 if get_wall_normal().x < 0 else 0
	else:
		wall_dir = 0

# === 跳跃状态更新 ===
func _update_jump_state(on_floor: bool) -> void:
	if player_velocity.y > 0 and not on_floor:
		is_jumping = false
		wall_jump_ready = false
		wall_climb_timer = 0.0

# === 墙壁攀爬处理 ===
func _handle_wall_climb(delta: float, on_floor: bool) -> void:
	if wall_jump_ready and on_wall and not mining and not on_floor:
		if wall_climb_timer < MAX_WALL_CLIMB_TIME:
			if Input.is_action_pressed("down"):
				_cancel_wall_climb()
			else:
				_do_wall_climb()
				wall_climb_timer += delta
		else:
			_cancel_wall_climb()

# === 移动处理 ===
func _handle_movement(input_dir: float, on_floor: bool) -> void:
	if not mining:
		if input_dir != 0:
			player_velocity.x = input_dir * MOVE_SPEED
			$AnimatedSprite2D.scale.x = input_dir
			$AnimatedSprite2D.play("run" if on_floor else "jump")
		else:
			player_velocity.x = 0
			if on_floor:
				$AnimatedSprite2D.play("idle")

# === 跳跃输入处理 ===
func _handle_jump_input(on_floor: bool) -> void:
	if Input.is_action_just_pressed("jump") and not mining:
		if on_floor:
			_perform_ground_jump()
		elif wall_jump_ready and wall_jump_cooldown <= 0 and on_wall:
			_perform_wall_jump()
		elif can_double_jump:
			_perform_double_jump()

# === 重力应用 ===
func _apply_gravity(delta: float, on_floor: bool) -> void:
	if not on_floor and not (on_wall and wall_jump_ready):
		player_velocity.y += GRAVITY * delta
	elif on_floor and player_velocity.y > 0:
		player_velocity.y = 0

# === 跳跃辅助函数 ===
func _perform_ground_jump() -> void:
	player_velocity.y = JUMP_VELOCITY
	can_double_jump = true
	is_jumping = true
	_play_jump_animation()

func _perform_wall_jump() -> void:
	var horizontal_input = Input.get_axis("left", "right")
	if (wall_dir > 0 and horizontal_input < 0) or (wall_dir < 0 and horizontal_input > 0):
		player_velocity.y = JUMP_VELOCITY
		player_velocity.x = - wall_dir * MOVE_SPEED * 2.0
		can_double_jump = true
		is_jumping = true
		_play_jump_animation()
		wall_jump_ready = false
		wall_climb_timer = 0.0
		wall_jump_cooldown = WALL_JUMP_COOLDOWN_TIME

func _perform_double_jump() -> void:
	player_velocity.y = JUMP_VELOCITY
	can_double_jump = false
	is_jumping = true
	_play_jump_animation()

# === 墙壁攀爬辅助函数 ===
func _cancel_wall_climb() -> void:
	wall_jump_ready = false
	is_jumping = false

func _do_wall_climb() -> void:
	player_velocity = Vector2.ZERO
	$AnimatedSprite2D.play("climb")
	$AnimatedSprite2D.scale.x = 1 if wall_dir > 0 else -1

# === 动画和音效 ===
func _play_jump_animation() -> void:
	$AnimatedSprite2D.play("jump")
	if $AudioStreamPlayer2D:
		$AudioStreamPlayer2D.play()

# === 挖掘处理 ===
func _handle_mining_input(input_dir: float) -> void:
	if not Input.is_action_pressed("dig") or mining:
		return

	var direction_map = {
		"up": Vector2(0, -32),
		"down": Vector2(0, 32),
		"right": Vector2(32, 0),
		"left": Vector2(-32, 0)
	}
	
	var dig_dir = ""
	var offset = Vector2.ZERO
	
	if Input.is_action_pressed("up"):
		dig_dir = "up"
	elif Input.is_action_pressed("down"):
		dig_dir = "down"
	elif input_dir > 0:
		dig_dir = "right"
	elif input_dir < 0:
		dig_dir = "left"
		
	if dig_dir != "":
		offset = direction_map[dig_dir]
		_start_mining(dig_dir, get_tile_pos(offset))

# === 工具函数 ===
func _start_mining(dir: String, pos: Vector2i) -> void:
	mining = true
	mining_dir = dir
	mining_pos = pos
	$AnimatedSprite2D.play("dig")
	if $AudioStreamPlayer2D:
		$AudioStreamPlayer2D.play()
	if has_node("DigParticles2D"):
		$DigParticles2D.restart()

# === 动画完成回调 ===
func _on_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "dig" and mining:
		emit_signal("dig", mining_pos, mining_dir)
		mining = false
		mining_dir = ""
		$AnimatedSprite2D.play("idle" if is_on_floor() else "jump")

# === 炸弹投掷处理 ===
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("throw_bomb") and Global.dynamite_remaining > 0:
		throw_bomb()

func throw_bomb() -> void:
	if Global.dynamite_remaining <= 0:
		return
		
	var bomb = Bomb.instantiate()
	get_parent().add_child(bomb)
	bomb.position = position
	
	var direction = sign($AnimatedSprite2D.scale.x)
	var impulse = Vector2(BOMB_THROW_FORCE.x * direction, BOMB_THROW_FORCE.y)
	bomb.apply_central_impulse(impulse)
	
	Global.dynamite_remaining -= 1

# === 瓦片位置计算 ===
func get_tile_pos(offset: Vector2) -> Vector2i:
	var tilemap = get_node_or_null("/root/Level/World/Dirt")
	if tilemap:
		var local_pos = tilemap.to_local(global_position + offset)
		return tilemap.local_to_map(local_pos)
	return Vector2i.ZERO
