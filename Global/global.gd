extends Node2D

@export var debug_overlay_active := false
@export var gravity = 500
@export var terminal_velocity = 1000
@export var currency := 10
@export var player_health := 100
@export var player_health_max := 100
@export var player_fuel := 90.0
@export var player_fuel_max := 90.0
@export var dynamite_remaining := 10
@export var cargo_size := 10
@export var cargo_collected := 0

# 地图状态缓存
var loaded_chunks_cache = {} # 已加载区块缓存 {Vector2i: {tile_data}}
var player_last_mine_position = Vector2.ZERO # 玩家最后在矿洞中的位置
var has_existing_mine = false # 是否已经有生成的矿洞

# 商店物品相关
enum ShopItem {
	HEALTH_POTION,
	FUEL_TANK,
	DYNAMITE,
	CARGO_UPGRADE
}

var shop_prices = {
	ShopItem.HEALTH_POTION: 50,
	ShopItem.FUEL_TANK: 100,
	ShopItem.DYNAMITE: 200,
	ShopItem.CARGO_UPGRADE: 500
}

var player_location := Vector2.ZERO
var default_map_position := Vector2.ZERO # 默认地图位置
var default_player_position := Vector2(100, -100) # 默认玩家起始位置
var in_store := false
var default_vars := [0, 0, 0] # 只在 _ready 赋值，无需初始化为 [0,0,0]

var chests_collected = [0, 0, 0] # 对应三种宝箱的收集数量

func buy_item(item: ShopItem) -> bool:
	if currency >= shop_prices[item]:
		currency -= shop_prices[item]
		match item:
			ShopItem.HEALTH_POTION:
				player_health = player_health_max
			ShopItem.FUEL_TANK:
				player_fuel = player_fuel_max
			ShopItem.DYNAMITE:
				dynamite_remaining += 1
			ShopItem.CARGO_UPGRADE:
				cargo_size += 5
		return true
	return false
