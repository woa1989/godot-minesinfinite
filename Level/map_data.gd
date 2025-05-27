extends Node

# 图块类型枚举
enum {EMPTY, DIRT, CHEST1, CHEST2, CHEST3, GROUND, BOOM}

# 每个地图的区块缓存
static var MAPS_CHUNKS = {
	"mine": {},
	"cave": {},
	"dungeon": {}
}

static var MAPS = {
	"矿洞": {
		"id": "mine",
		"tilemap": preload("res://Level/level.tres"),
		"description": "挖掘矿物的地方",
		"atlas_map": {
			EMPTY: null,
			DIRT: Vector2i(4, 0),
			CHEST1: Vector2i(2, 1),
			CHEST2: Vector2i(0, 2),
			CHEST3: Vector2i(3, 6),
			GROUND: Vector2i(0, 7),
			BOOM: Vector2i(7, 5)
		}
	},
	"洞穴": {
		"id": "cave",
		"tilemap": preload("res://Level/level2.tres"), # 可以替换成新的tileset
		"description": "探索未知的洞穴",
		"atlas_map": {
			EMPTY: null,
			DIRT: Vector2i(5, 6), # 使用不同的地形纹理
			CHEST1: Vector2i(9, 10),
			CHEST2: Vector2i(10, 10),
			CHEST3: Vector2i(11, 10),
			GROUND: Vector2i(3, 6), # 不同的地面纹理
			BOOM: Vector2i(13, 5)
		}
	},
	"地下城": {
		"id": "dungeon",
		"tilemap": preload("res://Level/level4.tres"), # 可以替换成新的tileset
		"description": "充满危险的地下城",
		"atlas_map": {
			EMPTY: null,
			DIRT: Vector2i(4, 1), # 使用不同的地形纹理
			CHEST1: Vector2i(3, 1),
			CHEST2: Vector2i(5, 1),
			CHEST3: Vector2i(5, 0),
			GROUND: Vector2i(0, 2), # 不同的地面纹理
			BOOM: Vector2i(3, 0)
		}
	}
}
