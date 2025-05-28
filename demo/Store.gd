extends Sprite2D

signal player_entered


func _on_Area2D_body_entered(_body):
	emit_signal("player_entered")
