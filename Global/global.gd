extends Node2D

@export var debug_overlay_active := false
@export var gravity = 500
@export var terminal_velocity = 1000
@export var currency := 10
@export var player_health := 100
@export var player_health_max := 100
@export var player_fuel := 90.0
@export var player_fuel_max := 90.0
@export var dynamite_remaining := 0
@export var cargo_size := 10
@export var cargo_collected := 0

var player_location := Vector2.ZERO
var default_map_position := Vector2.ZERO # 默认地图位置
var default_player_position := Vector2(100, -100) # 默认玩家起始位置
var in_store := false
var default_vars := [0, 0, 0] # 只在 _ready 赋值，无需初始化为 [0,0,0]

var chests_collected = [0, 0, 0] # 对应三种宝箱的收集数量
