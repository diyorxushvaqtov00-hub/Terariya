extends Node2D
class_name WorldGenerator

signal selected_block_changed(block_type: int)

const TILE_SIZE: int = 32
const WORLD_WIDTH: int = 180
const WORLD_HEIGHT: int = 60
const AIR: int = 0
const GRASS: int = 1
const DIRT: int = 2
const STONE: int = 3
const ORE: int = 4
const WOOD: int = 5
const LEAVES: int = 6
const SAND: int = 7
const SNOW: int = 8
const WATER: int = 9

@export var player_path: NodePath = NodePath("../Player")
@export var world_seed: int = 20261119

var tiles: Array = []
var surface_heights: PackedInt32Array = PackedInt32Array()
var _noise := FastNoiseLite.new()
var _cave_noise := FastNoiseLite.new()
var _collision_root: StaticBody2D
var selected_block_type: int = DIRT

func _ready() -> void:
	add_to_group("world_generator")
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
	_cave_noise.seed = world_seed + 104729
	_cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cave_noise.frequency = 0.075
	tiles.clear()
	surface_heights.resize(WORLD_WIDTH)
	for x in range(WORLD_WIDTH):
		var column: PackedInt32Array = PackedInt32Array()
		column.resize(WORLD_HEIGHT)
		var surface := clampi(15 + int(round(_noise.get_noise_1d(float(x)) * 5.0)), 9, 22)
		var biome := get_biome_at(x)
		if biome == "desert":
			surface = clampi(surface + 1, 10, 23)
		elif biome == "snow":
			surface = clampi(surface - 1, 8, 21)
		surface_heights[x] = surface
		for y in range(WORLD_HEIGHT):
			var tile := AIR
			if y == surface:
				tile = SAND if biome == "desert" else (SNOW if biome == "snow" else GRASS)
			elif y > surface and y <= surface + 7:
				tile = SAND if biome == "desert" else DIRT
			elif y > surface + 7:
				tile = STONE
				if y > surface + 12 and _noise.get_noise_2d(float(x) * 1.7, float(y) * 1.7) > 0.62:
					tile = ORE
			column[y] = tile
		tiles.append(column)
	_generate_caves()
	_generate_lakes()
	_generate_trees()
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
		WOOD:
			return Color(0.43, 0.25, 0.12)
		LEAVES:
			return Color(0.20, 0.55, 0.22)
		SAND:
			return Color(0.82, 0.72, 0.43)
		SNOW:
			return Color(0.84, 0.91, 0.98)
		WATER:
			return Color(0.12, 0.48, 0.88, 0.72)
	return Color.TRANSPARENT

func get_surface_y(tile_x: int) -> int:
	return surface_heights[clampi(tile_x, 0, WORLD_WIDTH - 1)]

func get_biome_at(tile_x: int) -> String:
	var safe_x := clampi(tile_x, 0, WORLD_WIDTH - 1)
	if safe_x < 60:
		return "forest"
	if safe_x < 120:
		return "desert"
	return "snow"

func get_spawn_position(tile_x: int) -> Vector2:
	var safe_x := clampi(tile_x, 2, WORLD_WIDTH - 3)
	return Vector2(safe_x * TILE_SIZE + TILE_SIZE * 0.5, get_surface_y(safe_x) * TILE_SIZE)

func get_tile(cell: Vector2i) -> int:
	if not _inside_world(cell):
		return AIR
	return int(tiles[cell.x][cell.y])

func is_position_in_water(world_position: Vector2) -> bool:
	var local_position := to_local(world_position)
	var base_cell := Vector2i(floori(local_position.x / TILE_SIZE), floori(local_position.y / TILE_SIZE))
	for offset_y in [-12, 0, 12, 24]:
		if get_tile(base_cell + Vector2i(0, floori(float(offset_y) / TILE_SIZE))) == WATER:
			return true
	return false

func mine_cell(cell: Vector2i) -> bool:
	if not _inside_world(cell) or get_tile(cell) in [AIR, WATER]:
		return false
	var mined_type := get_tile(cell)
	var player := get_node_or_null(player_path) as PlayerController
	if player != null:
		var drop := "ore" if mined_type == ORE else ("stone" if mined_type == STONE else ("wood" if mined_type == WOOD else ("leaves" if mined_type == LEAVES else ("sand" if mined_type == SAND else ("snow" if mined_type == SNOW else "dirt")))))
		var amount := 1
		if mined_type == WOOD and player.inventory.count("wooden_axe") > 0:
			amount = 2
			player.inventory.use_tool("wooden_axe")
		elif mined_type in [STONE, ORE] and player.inventory.count("wooden_pickaxe") > 0:
			amount = 2 if mined_type == STONE else 1
			player.inventory.use_tool("wooden_pickaxe")
		player.inventory.add_item(drop, amount)
	tiles[cell.x][cell.y] = AIR
	_rebuild_collision()
	queue_redraw()
	return true

func place_block(cell: Vector2i, block_type: int = DIRT) -> bool:
	if not _inside_world(cell) or get_tile(cell) != AIR:
		return false
	if block_type not in [DIRT, STONE, SAND, SNOW]:
		return false
	var player := get_node_or_null(player_path) as PlayerController
	var item_id := "stone" if block_type == STONE else ("sand" if block_type == SAND else ("snow" if block_type == SNOW else "dirt"))
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
		"selected_block": selected_block_type,
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
		var grass_surface := -1
		for y in range(WORLD_HEIGHT):
			var tile_value := int(saved_column[y])
			if tile_value < AIR or tile_value > WATER:
				return false
			column[y] = tile_value
			if first_solid == -1 and tile_value != AIR and tile_value != LEAVES:
				first_solid = y
			if grass_surface == -1 and tile_value == GRASS:
				grass_surface = y
		restored_surfaces[x] = grass_surface if grass_surface >= 0 else (first_solid if first_solid >= 0 else 0)
		restored.append(column)
	tiles = restored
	surface_heights = restored_surfaces
	world_seed = int(data.get("seed", world_seed))
	selected_block_type = int(data.get("selected_block", DIRT))
	if selected_block_type not in [DIRT, STONE, SAND, SNOW]:
		selected_block_type = DIRT
	_noise.seed = world_seed
	selected_block_changed.emit(selected_block_type)
	_rebuild_collision()
	queue_redraw()
	return true

func _generate_caves() -> void:
	# Carve deterministic underground pockets while protecting the surface layer.
	for x in range(1, WORLD_WIDTH - 1):
		var cave_floor := surface_heights[x] + 5
		for y in range(cave_floor, WORLD_HEIGHT - 4):
			var tile: int = tiles[x][y]
			if tile == STONE or tile == ORE:
				var cave_value := _cave_noise.get_noise_2d(float(x), float(y))
				if cave_value > 0.32:
					tiles[x][y] = AIR


func _generate_lakes() -> void:
	# Fixed centers and seeded widths make shallow pools reproducible.
	for center_x in [28, 83, 145]:
		var lake_width := 5 + int(absf(_noise.get_noise_1d(float(center_x) + 271.0)) * 4.0)
		var start_x: int = maxi(center_x - lake_width / 2, 1)
		var end_x: int = mini(center_x + lake_width / 2, WORLD_WIDTH - 2)
		var highest_surface := WORLD_HEIGHT
		for x in range(start_x, end_x + 1):
			highest_surface = mini(highest_surface, surface_heights[x])
		var waterline := highest_surface + 2
		for x in range(start_x, end_x + 1):
			for y in range(waterline, surface_heights[x]):
				if tiles[x][y] == AIR:
					tiles[x][y] = WATER

func _has_water_above(tile_x: int, ground_y: int) -> bool:
	for y in range(ground_y - 1, -1, -1):
		if tiles[tile_x][y] == WATER:
			return true
	return false

func _generate_trees() -> void:
	# Fixed spacing plus seeded noise keeps tree placement reproducible.
	for x in range(7, WORLD_WIDTH - 7, 11):
		if _noise.get_noise_1d(float(x) + 913.0) < -0.12:
			continue
		var ground_y := surface_heights[x]
		if tiles[x][ground_y] != GRASS or _has_water_above(x, ground_y):
			continue
		var trunk_height := 3 + int(absf(_noise.get_noise_1d(float(x) * 0.73)) * 3.0)
		for offset in range(1, trunk_height + 1):
			var trunk_y := ground_y - offset
			if trunk_y >= 0:
				tiles[x][trunk_y] = WOOD
		var crown_y := ground_y - trunk_height
		for leaf_x in range(x - 2, x + 3):
			for leaf_y in range(crown_y - 2, crown_y + 2):
				if not _inside_world(Vector2i(leaf_x, leaf_y)):
					continue
				if abs(leaf_x - x) + abs(leaf_y - crown_y) <= 3 and tiles[leaf_x][leaf_y] == AIR:
					tiles[leaf_x][leaf_y] = LEAVES

func _is_solid_tile(tile: int) -> bool:
	return tile != AIR and tile != LEAVES

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
			while x < WORLD_WIDTH and not _is_solid_tile(tiles[x][y]):
				x += 1
			if x >= WORLD_WIDTH:
				break
			var start_x := x
			while x < WORLD_WIDTH and _is_solid_tile(tiles[x][y]):
				x += 1
			var end_x := x
			var shape_node := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2((end_x - start_x) * TILE_SIZE, TILE_SIZE)
			shape_node.shape = shape
			shape_node.position = Vector2((start_x + end_x) * TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
			_collision_root.add_child(shape_node)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("cycle_block"):
		cycle_block_selection()
	if Input.is_action_just_pressed("mine"):
		_edit_target(false)
	if Input.is_action_just_pressed("place"):
		_edit_target(true)

func cycle_block_selection() -> void:
	var build_blocks: Array[int] = [DIRT, STONE, SAND, SNOW]
	var current_index := build_blocks.find(selected_block_type)
	selected_block_type = build_blocks[(current_index + 1) % build_blocks.size()]
	selected_block_changed.emit(selected_block_type)

func get_selected_block_name() -> String:
	match selected_block_type:
		STONE:
			return "STONE"
		SAND:
			return "SAND"
		SNOW:
			return "SNOW"
	return "DIRT"

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
		place_block(cell, selected_block_type)
	else:
		mine_cell(cell)
