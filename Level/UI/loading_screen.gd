extends Control

@onready var progress_bar = $ProgressBar
@onready var loading_text = $LoadingText

signal loading_done

func _ready():
	hide()

# 显示加载界面
func show_loading():
	show()
	progress_bar.value = 0
	loading_text.text = "正在加载..."

# 更新进度
func update_progress(value: float, text: String = ""):
	progress_bar.value = value
	if text:
		loading_text.text = text

# 完成加载
func loading_complete():
	emit_signal("loading_done")
	hide()
