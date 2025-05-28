extends Node2D

# 金币的价值
@export var value: int = 10
# 收集区域
@onready var collection_area: Area2D = $Area2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
# 是否可以被收集
var can_be_collected: bool = false
# 收集检测定时器
var collection_timer: Timer

func _ready():
	# 连接信号 - 注意：body_entered信号已在场景中连接，不需要在代码中重复连接
	# 只连接动画信号
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# 创建主动收集检测定时器
	collection_timer = Timer.new()
	collection_timer.wait_time = 0.1 # 每0.1秒检测一次
	collection_timer.timeout.connect(_check_for_player)
	add_child(collection_timer)
	
	# 初始禁用碰撞检测
	collection_area.set_deferred("monitoring", false)
	
	# 播放出现动画
	animated_sprite.play("appear")

func _on_animation_finished():
	# 当出现动画完成时，切换到循环动画并允许收集
	if animated_sprite.animation == "appear":
		can_be_collected = true
		collection_area.monitoring = true
		collection_timer.start() # 开始主动检测
		animated_sprite.play("idle")
		print("[Gold] 金币出现动画完成，现在可以收集")

# 主动检测玩家的方法
func _check_for_player():
	if not can_be_collected:
		return
		
	# 获取所有在范围内的物体
	var bodies = collection_area.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("collect_gold"):
			print("[Gold] 主动检测到玩家，开始收集")
			_collect_by_player(body)
			return

func _on_body_entered(body):
	print("[Gold] 检测到body进入: ", body.name, " 类型: ", body.get_class())
	# 只有在可收集状态下才能被收集
	if can_be_collected and body.has_method("collect_gold"):
		print("[Gold] 开始收集金币，价值: ", value)
		_collect_by_player(body)
	else:
		print("[Gold] 收集条件不满足 - 可收集:", can_be_collected, " 有collect_gold方法:", body.has_method("collect_gold"))

# 统一的收集处理方法
func _collect_by_player(body):
	body.collect_gold(value)
	# 播放收集效果
	_play_collect_effect()

func _play_collect_effect():
	# 播放收集音效（如果有的话）
	if has_node("AudioStreamPlayer2D"):
		$AudioStreamPlayer2D.play()
	
	# 简单的收集动画 - 快速缩放并消失
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
