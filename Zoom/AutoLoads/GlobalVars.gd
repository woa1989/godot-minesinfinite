extends Node

var bullets: int = 3 # 游戏要求：3颗子弹消灭所有僵尸
var max_bullets: int = 3
var zombies_killed: int = 0
var total_zombies: int = 0 # 记录总僵尸数量

func _ready() -> void:
	print("GlobalVars initialized - Bullets: ", bullets)

func add_bullets(amount: int) -> void:
	bullets = min(bullets + amount, max_bullets)
	print("Bullets added. Current bullets: ", bullets)

func use_bullet() -> bool:
	if bullets > 0:
		bullets -= 1
		print("Bullet used. Remaining bullets: ", bullets)
		return true
	return false

func kill_zombie() -> void:
	zombies_killed += 1
	print("Zombie killed! Total kills: ", zombies_killed, "/", total_zombies)
	
	# 检查是否完成游戏
	if zombies_killed >= total_zombies and total_zombies > 0:
		print("All zombies killed! Victory!")

func set_total_zombies(count: int) -> void:
	total_zombies = count
	print("Total zombies set to: ", total_zombies)

func reset_game() -> void:
	bullets = max_bullets
	zombies_killed = 0
	total_zombies = 0
	print("Game reset - Bullets: ", bullets)