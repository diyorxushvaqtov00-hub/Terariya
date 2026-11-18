extends Node2D
class_name WorldGenerator

const TILE_SIZE: int = 32
const WORLD_WIDTH: int = 180
const WORLD_HEIGHT: int = 60
const AIR: int = 0
const GRASS: int = 1
const DIRT: int = 2
const STONE: int = 3
const ORE: int = 4

@export var player_path: NodePath = NodePath("../Player")
@export var world_seed: int = 20261119

var tiles: Array = []
var surface_heights: PackedInt32Array = PackedInt32Array()
var _noise := FastNoiseLite.new()
var _collision_root: StaticBody2D

func _ready() -> void:
	_collision_root = StaticBody2D.new()
	_collision_root.name = "TerrainCollision"
	_collision_root.collision_layer = 1
	_collision_root.collision_mask = 0
	add_child(_collision_root)
	generate_world()

func generate_world() -> void:
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.035
	tiles.clear()
	surface_heights.resize(WORLD_WIDTH)
	for x in range(WORLD_WIDTH):
		var column: PackedInt32Array = PackedInt32Array()
		column.resize(WORLD_HEIGHT)
		var surface := clampi(15 + int(round(_noise.get_noise_1d(float(x)) * 5.0)), 9, 22)
		surface_heights[x] = surface
		for y in range(WORLD_HEIGHT):
			var tile := AIR
			if y == surface:
				tile = GRASS
			elif y > surface and y <= surface + 7:
				tile = DIRT
			elif y > surface + 7:
				tile = STONE
				if y > surface + 12 and _noise.get_noise_2d(float(x) * 1.7, float(y) * 1.7) > 0.62:
					tile = ORE
			column[y] = tile
		tiles.append(column)
	_rebuild_collision()
	queue_redraw()

func _draw() -> void:
	for x in range(WORLD_WIDTH):
		for y in range(WORLD_HEIGHT):
			var tile: int = tiles[x][y]
			if tile == AIR:
				continue
			var color := _tile_color(tile)
			var rect := Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(rect, color, true)
			draw_rect(rect, color.darkened(0.18), false, 1.0)

func _tile_color(tile: int) -> Color:
	match tile:
		GRASS:
			return Color(0.28, 0.66, 0.28)
		DIRT:
			return Color(0.48, 0.30, 0.18)
		STONE:
			return Color(0.38, 0.42, 0.48)
		ORE:
			return Color(0.20, 0.68, 0.76)
	return Color.TRANSPARENT

func get_surface_y(tile_x: int) -> int:
	return surface_heights[clampi(tile_x, 0, WORLD_WIDTH - 1)]

func get_spawn_position(tile_x: int) -> Vector2:
	var safe_x := clampi(tile_x, 2, WORLD_WIDTH - 3)
	return Vector2(safe_x * TILE_SIZE + TILE_SIZE * 0.5, get_surface_y(safe_x) * TILE_SIZE)

func get_tile(cell: Vector2i) -> int:
	if not _inside_world(cell):
		return AIR
	return int(tiles[cell.x][cell.y])

func mine_cell(cell: Vector2i) -> bool:
	if not _inside_world(cell) or get_tile(cell) == AIR:
		return false
	var mined_type := get_tile(cell)
	var player := get_node_or_null(player_path) as PlayerController
	if player != null:
		var drop := "ore" if mined_type == ORE else ("stone" if mined_type == STONE else "dirt")
		player.inventory.add_item(drop, 1)
	tiles[cell.x][cell.y] = AIR
	_rebuild_collision()
	queue_redraw()
	return true

func place_block(cell: Vector2i, block_type: int = DIRT) -> bool:
	if not _inside_world(cell) or get_tile(cell) != AIR:
		return false
	if block_type not in [DIRT, STONE]:
		return false
	var player := get_node_or_null(player_path) as PlayerController
	var item_id := "stone" if block_type == STONE else "dirt"
	if player != null:
		var block_center := Vector2(cell.x * TILE_SIZE + TILE_SIZE * 0.5, cell.y * TILE_SIZE + TILE_SIZE * 0.5)
		if player.global_position.distance_to(to_global(block_center)) < TILE_SIZE * 1.15:
			return false
		if not player.inventory.remove_item(item_id, 1):
			return false
	tiles[cell.x][cell.y] = block_type
	_rebuild_collision()
	queue_redraw()
	return true

func get_save_data() -> Dictionary:
	var saved_columns: Array = []
	for column in tiles:
		var saved_column: Array = []
		for tile in column:
			saved_column.append(int(tile))
		saved_columns.append(saved_column)
	return {
		"seed": world_seed,
		"width": WORLD_WIDTH,
		"height": WORLD_HEIGHT,
		"tiles": saved_columns
	}

func load_save_data(data: Dictionary) -> bool:
	if int(data.get("width", -1)) != WORLD_WIDTH or int(data.get("height", -1)) != WORLD_HEIGHT:
		return false
	var saved_columns: Variant = data.get("tiles", null)
	if not saved_columns is Array or saved_columns.size() != WORLD_WIDTH:
		return false
	var restored: Array = []
	var restored_surfaces := PackedInt32Array()
	restored_surfaces.resize(WORLD_WIDTH)
	for x in range(WORLD_WIDTH):
		var saved_column: Variant = saved_columns[x]
		if not saved_column is Array or saved_column.size() != WORLD_HEIGHT:
			return false
		var column := PackedInt32Array()
		column.resize(WORLD_HEIGHT)
		var first_solid := -1
		for y in range(WORLD_HEIGHT):
			var tile_value := int(saved_column[y])
			if tile_value < AIR or tile_value > ORE:
				return false
			column[y] = tile_value
			if first_solid == -1 and tile_value != AIR:
				first_solid = y
		restored_surfaces[x] = first_solid if first_solid >= 0 else 0
		restored.append(column)
	tiles = restored
	surface_heights = restored_surfaces
	world_seed = int(data.get("seed", world_seed))
	_noise.seed = world_seed
	_rebuild_collision()
	queue_redraw()
	return true

func _inside_world(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WORLD_WIDTH and cell.y >= 0 and cell.y < WORLD_HEIGHT

func _rebuild_collision() -> void:
	if _collision_root == null:
		return
	for child in _collision_root.get_children():
		_collision_root.remove_child(child)
		child.free()
	for y in range(WORLD_HEIGHT):
		var x := 0
		while x < WORLD_WIDTH:
			while x < WORLD_WIDTH and tiles[x][y] == AIR:
				x += 1
			if x >= WORLD_WIDTH:
				break
			var start_x := x
			while x < WORLD_WIDTH and tiles[x][y] != AIR:
				x += 1
			var end_x := x
			var shape_node := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2((end_x - start_x) * TILE_SIZE, TILE_SIZE)
			shape_node.shape = shape
			shape_node.position = Vector2((start_x + end_x) * TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
			_collision_root.add_child(shape_node)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("mine"):
		_edit_target(false)
	if Input.is_action_just_pressed("place"):
		_edit_target(true)

func _edit_target(placing: bool) -> void:
	var player := get_node_or_null(player_path) as Node2D
	if player == null:
		return
	var controller := player as PlayerController
	var facing := 1
	if controller != null:
		facing = controller.get_facing()
	var target := player.global_position + Vector2(facing * TILE_SIZE * 1.35, TILE_SIZE * 0.5)
	var local_target := to_local(target)
	var cell := Vector2i(floori(local_target.x / TILE_SIZE), floori(local_target.y / TILE_SIZE))
	if placing:
		place_block(cell)
	else:
		mine_cell(cell)
