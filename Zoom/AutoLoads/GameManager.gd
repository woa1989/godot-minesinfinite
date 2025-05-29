extends Node

# 游戏管理器，负责统计僵尸数量和游戏状态

func _ready() -> void:
	# 在场景加载完成后统计僵尸数量
	call_deferred("count_zombies")

func count_zombies() -> void:
	var zombies = get_tree().get_nodes_in_group("zombie")
	var zombie_count = zombies.size()
	GlobalVars.set_total_zombies(zombie_count)
	print("Game Manager: Found ", zombie_count, " zombies in the scene")

func check_game_status() -> void:
	# 检查游戏状态
	if GlobalVars.zombies_killed >= GlobalVars.total_zombies and GlobalVars.total_zombies > 0:
		print("Victory! All zombies eliminated!")
		_on_victory()
	elif GlobalVars.bullets <= 0 and GlobalVars.zombies_killed < GlobalVars.total_zombies:
		print("Game Over! No more bullets!")
		_on_game_over()

func _on_victory() -> void:
	print("Victory condition met!")
	# 播放胜利音效
	var audio_manager = get_node("/root/AudioManager")
	if audio_manager:
		audio_manager.play_victory_sound()
	# 延迟重新开始游戏
	await get_tree().create_timer(3.0).timeout
	restart_game()

func _on_game_over() -> void:
	print("Game over condition met!")
	# 延迟重新开始游戏
	await get_tree().create_timer(3.0).timeout
	restart_game()

func restart_game() -> void:
	print("Restarting game...")
	GlobalVars.reset_game()
	# 重新加载当前场景
	get_tree().reload_current_scene()
