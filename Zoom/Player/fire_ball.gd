extends Area2D

var speed: float = 500.0
var direction: Vector2
var hit_zombies: Array = [] # 记录已击中的僵尸，实现穿透
var max_pierce: int = 10 # 最大穿透数量，足够击杀所有僵尸

func _ready() -> void:
	# 连接区域进入信号
	connect("body_entered", _on_body_entered)
	connect("area_entered", _on_area_entered) # 也监听Area进入
	print("FireBall: Ready, connecting signals")
	# 开始播放动画
	$AnimatedSprite2D.play("fly")
	print("FireBall: Animation started")
	
	# 设置自动销毁计时器
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 8.0 # 增加存活时间以便穿透更多僵尸
	timer.one_shot = true
	timer.timeout.connect(_auto_destroy)
	timer.start()

func set_launch_direction(launch_dir: Vector2) -> void:
	direction = launch_dir.normalized()
	print("FireBall: Direction set to: ", direction)
	
func _physics_process(delta: float) -> void:
	# 如果没有设置方向，使用旋转角度计算
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(rotation)
		
	# 移动火球
	global_position += direction * speed * delta
	
	# 检查是否有重叠的物体
	for body in get_overlapping_bodies():
		if body.is_in_group("zombie") and not body in hit_zombies:
			print("FireBall: Found new zombie in overlap!")
			_hit_zombie(body)

func _on_body_entered(body: Node2D) -> void:
	print("FireBall: Body entered - ", body.name, " Groups: ", body.get_groups())
	
	if body.is_in_group("zombie") and not body in hit_zombies:
		print("FireBall hit zombie via body_entered!")
		_hit_zombie(body)

func _on_area_entered(area: Area2D) -> void:
	print("FireBall: Area entered - ", area.name, " Groups: ", area.get_groups())
	
	# 检查Area的父节点是否是僵尸
	var parent = area.get_parent()
	if parent and parent.is_in_group("zombie") and not parent in hit_zombies:
		print("FireBall hit zombie area!")
		_hit_zombie(parent)

func _hit_zombie(zombie: Node2D) -> void:
	# 检查是否已经击中过这个僵尸
	if zombie in hit_zombies:
		return
		
	# 添加到已击中列表
	hit_zombies.append(zombie)
	print("FireBall: Hitting zombie: ", zombie.name, " (Hit count: ", hit_zombies.size(), ")")
	
	# 创建击中特效
	_create_hit_effect(zombie.global_position)
	
	# 播放击中音效
	var audio_manager = get_node("/root/AudioManager")
	if audio_manager:
		audio_manager.play_hit_sound()
	
	if zombie.has_method("die"):
		zombie.die() # 调用丧尸的死亡函数
		print("FireBall: Called zombie.die()")
	else:
		print("FireBall: Zombie doesn't have die method!")
		
	# 穿透效果：火球变大一点，表示穿透能力
	scale_up()
		
	# 检查是否达到最大穿透数或击杀所有僵尸
	if hit_zombies.size() >= max_pierce:
		print("FireBall: Reached max pierce count, destroying")
		queue_free()

func _create_hit_effect(pos: Vector2) -> void:
	# 创建简单的击中粒子效果
	var particles = GPUParticles2D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.5
	
	# 设置粒子材质
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, -1, 0)
	particle_material.initial_velocity_min = 50.0
	particle_material.initial_velocity_max = 150.0
	particle_material.gravity = Vector3(0, 200, 0)
	particle_material.scale_min = 2.0
	particle_material.scale_max = 5.0
	particles.process_material = particle_material
	
	# 自动清理
	var timer = Timer.new()
	particles.add_child(timer)
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(func(): particles.queue_free())
	timer.start()

func scale_up() -> void:
	# 每次穿透后火球稍微变大，表示威力增强
	var tween = create_tween()
	tween.tween_property(self, "scale", scale * 1.1, 0.1)

func _auto_destroy() -> void:
	print("FireBall: Auto-destroying after timeout. Hit zombies: ", hit_zombies.size())
	queue_free()
