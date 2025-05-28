extends Node2D

# 简单的炸弹功能测试脚本
# 运行这个脚本来验证炸弹系统是否正常工作

func _ready():
	print("=== 炸弹功能测试开始 ===")
	test_time_api()
	test_bomb_config()
	print("=== 炸弹功能测试完成 ===")

# 测试Time API是否正常工作
func test_time_api():
	print("测试 Time API...")
	var current_time = Time.get_unix_time_from_system()
	print("当前Unix时间戳: ", current_time)
	
	# 测试时间戳是否合理（大于2024年1月1日的时间戳）
	var expected_min_time = 1704067200 # 2024-01-01 00:00:00 UTC
	if current_time > expected_min_time:
		print("✓ Time API 工作正常")
	else:
		print("✗ Time API 异常")

# 测试炸弹配置是否正常加载
func test_bomb_config():
	print("测试炸弹配置...")
	var config = preload("res://Items/default_bomb_config.tres")
	if config:
		print("✓ 炸弹配置加载成功")
		print("  - 爆炸时间: ", config.time_left)
		print("  - 爆炸半径: ", config.explosion_radius)
		print("  - 爆炸伤害: ", config.damage)
	else:
		print("✗ 炸弹配置加载失败")

# 可以在游戏中调用这个函数来测试炸弹投掷
func test_bomb_throwing():
	print("测试炸弹投掷...")
	
	# 检查全局炸药数量
	if Global.dynamite_remaining > 0:
		print("✓ 有可用的炸药 (", Global.dynamite_remaining, ")")
		
		# 这里可以添加更多的投掷测试逻辑
		# 比如检查炸弹场景是否能正常实例化
		var bomb_scene = preload("res://Items/Bomb.tscn")
		if bomb_scene:
			print("✓ 炸弹场景加载成功")
		else:
			print("✗ 炸弹场景加载失败")
	else:
		print("✗ 没有可用的炸药")
