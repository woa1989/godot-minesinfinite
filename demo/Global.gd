extends Node2D

enum TileType { EMPTY, ROCK, LAVA, MINERAL, DIRT }
enum Mineral { NONE, COPPER, IRON, SILVER, GOLD, PLATINUM, URANIUM, RADINIUM, LAVERDARNIUM, JASMINIUM }

const MineralCosts = [30, 60, 100, 250, 750, 2000, 5000, 20000, 100000]

class Tile:
	var tile_type
	var mineral_type

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
var tile_left := Tile.new()
var tile_right := Tile.new()
var tile_below := Tile.new()
var in_store := false
var loading := false
var default_vars := [0, 0, 0]


var minerals_collected = [0, 0, 0, 0, 0, 0, 0, 0 ,0]


func _ready():
	default_vars = [player_fuel_max, player_health_max, cargo_size]


func reset_player():
	player_fuel_max = default_vars[0]
	player_fuel = player_fuel_max
	player_health_max = default_vars[1]
	player_health = player_health_max
	cargo_size = default_vars[2]
	cargo_collected = 0
	minerals_collected = [0, 0, 0, 0, 0, 0, 0, 0 ,0]
	dynamite_remaining = 0
