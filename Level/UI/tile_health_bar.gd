extends Node2D

@onready var progress_bar: ProgressBar = $ProgressBar

var max_health: int = 1

func _ready():
	# 初始化进度条
	progress_bar.min_value = 0
	progress_bar.max_value = max_health
	progress_bar.value = max_health

# 设置血条的最大值和当前值
func set_health(current: int, maximum: int = -1):
	if maximum > 0:
		max_health = maximum
		progress_bar.max_value = max_health
	progress_bar.value = current
	
	# 如果血量为0，则销毁血条
	if current <= 0:
		queue_free()

# 显示血条
func show_health_bar():
	progress_bar.show()

# 隐藏血条
func hide_health_bar():
	progress_bar.hide()
