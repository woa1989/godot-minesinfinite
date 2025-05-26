@tool # 允许在编辑器中编辑
extends Resource
class_name BombConfig # 定义配置类名称

## 炸弹配置参数
## 用于定义不同类型炸弹的属性

# 爆炸范围（像素）
@export var explosion_radius: float = 96.0

# 爆炸伤害
@export var damage: int = 2

# 引爆延迟（秒）
@export var time_left: float = 2.0

# 连锁爆炸时范围增加的倍数
@export var chain_explosion_multiplier: float = 1.2

# 物理属性
@export_group("Physics Properties") # 物理属性组
@export var mass: float = 1.0
@export var friction: float = 1.0
@export var linear_damp: float = 2.0

## 获取配置的描述
func get_description() -> String:
	return """炸弹配置:
	- 爆炸范围: %.1f像素
	- 伤害: %d
	- 引爆延迟: %.1f秒
	- 连锁爆炸倍数: %.1fx""" % [
		explosion_radius,
		damage,
		time_left,
		chain_explosion_multiplier
	]