extends Node

# 音效管理器

@onready var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()

var hit_sound = preload("res://Zoom/Audios/Human_Hitted.wav")
var victory_sound = preload("res://Zoom/Audios/Human_die.wav") # 暂时使用现有音效

func _ready() -> void:
	add_child(audio_player)
	print("Audio Manager initialized")

func play_hit_sound() -> void:
	if hit_sound:
		audio_player.stream = hit_sound
		audio_player.play()

func play_victory_sound() -> void:
	if victory_sound:
		audio_player.stream = victory_sound
		audio_player.play()

func play_sound(sound_stream: AudioStream) -> void:
	if sound_stream:
		audio_player.stream = sound_stream
		audio_player.play()
