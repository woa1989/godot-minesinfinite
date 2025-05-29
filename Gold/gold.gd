extends RigidBody2D

# 金币的价值
@export var value: int = 10
# 收集区域
@onready var collection_area: Area2D = $Area2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	# 设置刚体属性
	gravity_scale = 1.0 # 启用重力
	linear_damp = 0.5 # 线性阻尼，使金币不会永远弹跳
	contact_monitor = true
	max_contacts_reported = 1
	freeze = false
	
	print("[Gold] 初始化 - 位置:", position, " 碰撞层:", collision_layer, " 碰撞遮罩:", collection_area.collision_mask)
	
	# 播放出现动画
	animated_sprite.play("appear")
	apply_central_impulse(Vector2(randf_range(-20, 20), -100))

func _on_body_entered(body):
	print("[Gold] 检测到body进入 - 名称:", body.name,
		" 类型:", body.get_class(),
		" 位置:", body.global_position,
		" 碰撞层:", body.collision_layer)
	
	# 检查是否可以被收集
	if body.has_method("collect_gold"):
		print("[Gold] 开始收集金币 - 价值:", value)
		_collect_by_player(body)
	else:
		print("[Gold] 收集条件不满足: body没有collect_gold方法")

# 统一的收集处理方法
func _collect_by_player(body):
	body.collect_gold(value)
	print("[Gold] 正在收集 - 玩家位置:", body.global_position, " 金币位置:", global_position)
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
