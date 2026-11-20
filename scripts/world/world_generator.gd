extends Node2D
class_name WorldGenerator

signal selected_block_changed(block_type: int)

const TILE_SIZE: int = 32
const CHUNK_SIZE: int = 16
const CHUNK_LOAD_RADIUS: int = 1
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
const CHEST_REWARD_ORE: int = 8
const SILVER_ORE: int = 10
const GOLD_ORE: int = 11
const MUSHROOM_SOIL: int = 12
const GLOW_MUSHROOM: int = 13
const LAVA: int = 14
const MAGMA_ROCK: int = 15

@export var player_path: NodePath = NodePath("../Player")
@export var world_seed: int = 20261119

var tiles: Array = []
var surface_heights: PackedInt32Array = PackedInt32Array()
var _noise := FastNoiseLite.new()
var _cave_noise := FastNoiseLite.new()
var _cave_detail_noise := FastNoiseLite.new()
var _collision_root: StaticBody2D
var _loaded_collision_chunks: Dictionary = {}
var _chunk_update_elapsed: float = 0.0
var selected_block_type: int = DIRT
var water_flow_interval: float = 0.28
var _water_flow_elapsed: float = 0.0
var _mine_cooldown_remaining: float = 0.0
var _water_flow_direction: int = 1
var _water_sources: Dictionary = {}
var max_water_tiles: int = 1800
var _torch_cells: Array[Vector2i] = []
var _torch_lights: Array[PointLight2D] = []
var _lantern_cells: Array[Vector2i] = []
var _lantern_lights: Array[PointLight2D] = []
var _dungeon_chests: Array[Dictionary] = []
var _dungeon_secret_rooms: Array[Dictionary] = []

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
	_cave_detail_noise.seed = world_seed + 209759
	_cave_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cave_detail_noise.frequency = 0.16
	tiles.clear()
	_water_sources.clear()
	surface_heights.resize(WORLD_WIDTH)
	for x in range(WORLD_WIDTH):
		var column: PackedInt32Array = PackedInt32Array()
		column.resize(WORLD_HEIGHT)
		var forest_desert_blend := _smoothstep01(inverse_lerp(56.0, 64.0, float(x)))
		var desert_snow_blend := _smoothstep01(inverse_lerp(116.0, 124.0, float(x)))
		var base_surface := 15.0 + _noise.get_noise_1d(float(x)) * 5.0
		var surface_offset := forest_desert_blend - desert_snow_blend * 2.0
		var surface := clampi(int(round(base_surface + surface_offset)), 8, 23)
		var biome := get_biome_at(x)
		var transition_roll := (_noise.get_noise_1d(float(x) + 443.0) + 1.0) * 0.5
		surface_heights[x] = surface
		for y in range(WORLD_HEIGHT):
			var tile := AIR
			if y == surface:
				if x >= 116 and x < 124:
					tile = SNOW if transition_roll < desert_snow_blend else SAND
				elif x >= 56 and x < 64:
					tile = SAND if transition_roll < forest_desert_blend else GRASS
				else:
					tile = SAND if biome == "desert" else (SNOW if biome == "snow" else GRASS)
			elif y > surface and y <= surface + 7:
				if x >= 116 and x < 124:
					tile = DIRT if transition_roll < desert_snow_blend else SAND
				elif x >= 56 and x < 64:
					tile = SAND if transition_roll < forest_desert_blend else DIRT
				else:
					tile = SAND if biome == "desert" else DIRT
			elif y > surface + 7:
				tile = STONE
				var deposit_noise := _noise.get_noise_2d(float(x) * 1.7, float(y) * 1.7)
				if y > surface + 25 and deposit_noise > 0.68:
					tile = GOLD_ORE
				elif y > surface + 16 and deposit_noise > 0.62:
					tile = SILVER_ORE
				elif y > surface + 12 and deposit_noise > 0.58:
					tile = ORE
			column[y] = tile
		tiles.append(column)
	_generate_caves()
	_generate_dungeons()
	_generate_mine_shafts()
	_generate_underground_biomes()
	_generate_lakes()
	_generate_trees()
	_rebuild_collision()
	queue_redraw()

func _get_visible_tile_bounds() -> Rect2i:
	var inverse_transform := get_global_transform_with_canvas().affine_inverse()
	var top_left := inverse_transform * Vector2.ZERO
	var bottom_right := inverse_transform * get_viewport_rect().size
	var min_x := clampi(floori(minf(top_left.x, bottom_right.x) / TILE_SIZE) - 1, 0, WORLD_WIDTH)
	var min_y := clampi(floori(minf(top_left.y, bottom_right.y) / TILE_SIZE) - 1, 0, WORLD_HEIGHT)
	var max_x := clampi(ceili(maxf(top_left.x, bottom_right.x) / TILE_SIZE) + 1, 0, WORLD_WIDTH)
	var max_y := clampi(ceili(maxf(top_left.y, bottom_right.y) / TILE_SIZE) + 1, 0, WORLD_HEIGHT)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(maxi(max_x - min_x, 0), maxi(max_y - min_y, 0)))

func _draw() -> void:
	var visible_bounds := _get_visible_tile_bounds()
	for x in range(visible_bounds.position.x, visible_bounds.end.x):
		for y in range(visible_bounds.position.y, visible_bounds.end.y):
			var tile: int = tiles[x][y]
			if tile == AIR:
				continue
			var color := _tile_color(tile)
			var rect := Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(rect, color, true)
			draw_rect(rect, color.darkened(0.18), false, 1.0)
			if tile == WATER and (y == 0 or tiles[x][y - 1] != WATER):
				draw_line(rect.position + Vector2(2.0, 2.0), rect.position + Vector2(TILE_SIZE - 2.0, 2.0), Color(0.58, 0.82, 1.0, 0.9), 2.0)
			elif tile == WATER:
				draw_line(rect.position + Vector2(7.0, 5.0), rect.position + Vector2(7.0, TILE_SIZE - 5.0), Color(0.42, 0.70, 1.0, 0.28), 2.0)
			elif tile == GLOW_MUSHROOM:
				draw_circle(rect.position + Vector2(16.0, 14.0), 7.0, Color(0.60, 0.35, 0.95, 0.95))
				draw_rect(Rect2(rect.position + Vector2(14.0, 17.0), Vector2(4.0, 12.0)), Color(0.80, 0.72, 0.90), true)
			elif tile == LAVA:
				draw_line(rect.position + Vector2(2.0, 8.0), rect.position + Vector2(29.0, 8.0), Color(1.0, 0.85, 0.30, 0.9), 2.0)
	for chest in _dungeon_chests:
		var chest_cell: Vector2i = chest["cell"]
		var chest_rect := Rect2(Vector2(chest_cell.x * TILE_SIZE + 4, chest_cell.y * TILE_SIZE + 10), Vector2(24, 19))
		draw_rect(chest_rect, Color(0.43, 0.22, 0.08), true)
		draw_rect(Rect2(chest_rect.position, Vector2(24, 6)), Color(0.72, 0.43, 0.13), true)
		draw_rect(chest_rect, Color(0.18, 0.11, 0.06), false, 2.0)
		if bool(chest.get("opened", false)):
			draw_line(chest_rect.position + Vector2(3, 4), chest_rect.position + Vector2(21, 16), Color(0.12, 0.09, 0.06), 2.0)
	for room in _dungeon_secret_rooms:
		var gate_cells: Array = room["gate_cells"]
		if not gate_cells.is_empty() and get_tile(gate_cells[0]) != AIR:
			var gate_rect := Rect2(Vector2(gate_cells[0].x * TILE_SIZE + 3, gate_cells[0].y * TILE_SIZE), Vector2(26, TILE_SIZE * 2))
			draw_rect(gate_rect, Color(0.16, 0.19, 0.25), true)
			for bar_x in range(4):
				draw_line(gate_rect.position + Vector2(4 + bar_x * 6, 2), gate_rect.position + Vector2(4 + bar_x * 6, gate_rect.size.y - 2), Color(0.72, 0.77, 0.86), 2.0)
		var cache_cell: Vector2i = room["cache_cell"]
		var cache_rect := Rect2(Vector2(cache_cell.x * TILE_SIZE + 3, cache_cell.y * TILE_SIZE + 8), Vector2(26, 22))
		draw_rect(cache_rect, Color(0.36, 0.22, 0.52) if not bool(room.get("cache_opened", false)) else Color(0.20, 0.18, 0.24), true)
		draw_rect(Rect2(cache_rect.position, Vector2(26, 7)), Color(0.92, 0.72, 0.30), true)
		draw_rect(cache_rect, Color(0.12, 0.10, 0.16), false, 2.0)
	for cell in _lantern_cells:
		var lantern_base := Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.82) * TILE_SIZE)
		draw_rect(Rect2(lantern_base + Vector2(-7, -20), Vector2(14, 18)), Color(0.28, 0.31, 0.38), true)
		draw_rect(Rect2(lantern_base + Vector2(-4, -17), Vector2(8, 12)), Color(1.0, 0.72, 0.28, 0.92), true)
		draw_arc(lantern_base + Vector2(0, -20), 7.0, PI, TAU, 16, Color(0.75, 0.78, 0.82), 2.0)
	for cell in _torch_cells:
		var torch_base := Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.82) * TILE_SIZE)
		draw_line(torch_base, torch_base + Vector2(0.0, -17.0), Color(0.48, 0.28, 0.12), 4.0)
		draw_colored_polygon(PackedVector2Array([torch_base + Vector2(-5, -15), torch_base + Vector2(0, -27), torch_base + Vector2(5, -15)]), Color(1.0, 0.55, 0.12, 0.95))
		draw_circle(torch_base + Vector2(0, -20), 3.0, Color(1.0, 0.88, 0.42))

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
		SILVER_ORE:
			return Color(0.72, 0.79, 0.88)
		GOLD_ORE:
			return Color(0.96, 0.68, 0.12)
		MUSHROOM_SOIL:
			return Color(0.30, 0.22, 0.39)
		GLOW_MUSHROOM:
			return Color(0.62, 0.34, 0.90)
		LAVA:
			return Color(0.95, 0.22, 0.035, 0.92)
		MAGMA_ROCK:
			return Color(0.28, 0.16, 0.15)
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

func _smoothstep01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

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
	for offset_y in [-18.0, 0.0, 18.0, 30.0]:
		var sample := to_local(world_position + Vector2(0.0, offset_y))
		var cell := Vector2i(floori(sample.x / TILE_SIZE), floori(sample.y / TILE_SIZE))
		if get_tile(cell) == WATER:
			return true
	return false

func is_position_in_lava(world_position: Vector2) -> bool:
	for offset_y in [-16.0, 0.0, 16.0, 28.0]:
		var sample := to_local(world_position + Vector2(0.0, offset_y))
		var cell := Vector2i(floori(sample.x / TILE_SIZE), floori(sample.y / TILE_SIZE))
		if get_tile(cell) == LAVA:
			return true
	return false

func count_water_tiles() -> int:
	var total := 0
	for column in tiles:
		for tile in column:
			if int(tile) == WATER:
				total += 1
	return total

func set_water_source(cell: Vector2i, enabled: bool = true) -> bool:
	if not _inside_world(cell) or get_tile(cell) != WATER:
		return false
	if enabled:
		_water_sources[cell] = true
	else:
		_water_sources.erase(cell)
	return true

func is_water_source(cell: Vector2i) -> bool:
	return _water_sources.has(cell)

func install_water_pump(cell: Vector2i, inventory: PlayerInventory) -> bool:
	if inventory == null or not _inside_world(cell) or get_tile(cell) != WATER:
		return false
	if not inventory.remove_item("water_pump", 1):
		return false
	_water_sources[cell] = true
	return true

func drain_water(cell: Vector2i, inventory: PlayerInventory) -> bool:
	if inventory == null or not _inside_world(cell) or get_tile(cell) != WATER:
		return false
	if not inventory.remove_item("drain_charge", 1):
		return false
	_water_sources.erase(cell)
	tiles[cell.x][cell.y] = AIR
	queue_redraw()
	return true

func fill_bucket(cell: Vector2i, inventory: PlayerInventory) -> bool:
	if not _inside_world(cell) or get_tile(cell) != WATER or inventory == null:
		return false
	if not inventory.remove_item("empty_bucket", 1):
		return false
	inventory.add_item("water_bucket", 1)
	_water_sources.erase(cell)
	tiles[cell.x][cell.y] = AIR
	queue_redraw()
	return true

func pour_bucket(cell: Vector2i, inventory: PlayerInventory, player_position: Vector2 = Vector2.INF) -> bool:
	if not _inside_world(cell) or get_tile(cell) != AIR or inventory == null:
		return false
	if not inventory.remove_item("water_bucket", 1):
		return false
	if player_position != Vector2.INF:
		var center := to_global(Vector2(cell.x * TILE_SIZE + TILE_SIZE * 0.5, cell.y * TILE_SIZE + TILE_SIZE * 0.5))
		if player_position.distance_to(center) < TILE_SIZE * 1.15:
			inventory.add_item("water_bucket", 1)
			return false
	tiles[cell.x][cell.y] = WATER
	inventory.add_item("empty_bucket", 1)
	queue_redraw()
	return true

func mine_cell(cell: Vector2i) -> bool:
	if not _inside_world(cell) or get_tile(cell) in [AIR, WATER, LAVA]:
		return false
	var mined_type := get_tile(cell)
	var player := get_node_or_null(player_path) as PlayerController
	if player != null:
		var drop := "dirt"
		match mined_type:
			GOLD_ORE:
				drop = "gold_ore"
			SILVER_ORE:
				drop = "silver_ore"
			GLOW_MUSHROOM:
				drop = "glow_mushroom"
			MAGMA_ROCK:
				drop = "magma_rock"
			MUSHROOM_SOIL:
				drop = "mushroom_soil"
			ORE:
				drop = "ore"
			STONE:
				drop = "stone"
			WOOD:
				drop = "wood"
			LEAVES:
				drop = "leaves"
			SAND:
				drop = "sand"
			SNOW:
				drop = "snow"
		var amount := 1
		if mined_type == WOOD and player.inventory.count("wooden_axe") > 0:
			amount = 2
			player.inventory.use_tool("wooden_axe")
		elif mined_type in [STONE, ORE] and player.inventory.count("wooden_pickaxe") > 0:
			amount = 2 if mined_type == STONE else 1
			player.inventory.use_tool("wooden_pickaxe")
		player.inventory.add_item(drop, amount)
	tiles[cell.x][cell.y] = AIR
	_refresh_collision_chunk_for_cell(cell)
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
	_refresh_collision_chunk_for_cell(cell)
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
		"water_sources": _serialize_water_sources(),
		"torches": _serialize_torches(),
		"lanterns": _serialize_lanterns(),
		"chests": _serialize_chests(),
		"secret_rooms": _serialize_secret_rooms(),
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
			if tile_value < AIR or tile_value > MAGMA_ROCK:
				return false
			column[y] = tile_value
			if first_solid == -1 and tile_value != AIR and tile_value != LEAVES and tile_value != WATER and tile_value != GLOW_MUSHROOM and tile_value != LAVA:
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
	_water_sources = _restore_water_sources(data.get("water_sources", []))
	_restore_torches(data.get("torches", []))
	_restore_lanterns(data.get("lanterns", []))
	_restore_chests(data.get("chests", []))
	_restore_secret_rooms(data.get("secret_rooms", []))
	selected_block_changed.emit(selected_block_type)
	_rebuild_collision()
	queue_redraw()
	return true

func place_torch(cell: Vector2i, inventory: PlayerInventory) -> bool:
	if not _inside_world(cell) or get_tile(cell) != AIR or inventory == null:
		return false
	if _torch_cells.has(cell) or _lantern_cells.has(cell) or not inventory.remove_item("torch", 1):
		return false
	_torch_cells.append(cell)
	_create_torch_light(cell)
	queue_redraw()
	return true

func place_lantern(cell: Vector2i, inventory: PlayerInventory) -> bool:
	if not _inside_world(cell) or get_tile(cell) != AIR or inventory == null:
		return false
	if _lantern_cells.has(cell) or _torch_cells.has(cell) or not inventory.remove_item("lantern", 1):
		return false
	_lantern_cells.append(cell)
	_create_lantern_light(cell)
	queue_redraw()
	return true

func _serialize_lanterns() -> Array:
	var result: Array = []
	for cell in _lantern_cells:
		if _inside_world(cell) and get_tile(cell) == AIR:
			result.append([cell.x, cell.y])
	return result

func _restore_lanterns(raw_lanterns: Variant) -> void:
	_lantern_cells.clear()
	for light in _lantern_lights:
		if is_instance_valid(light):
			light.queue_free()
	_lantern_lights.clear()
	if not raw_lanterns is Array:
		return
	for entry in raw_lanterns:
		if entry is Array and entry.size() == 2:
			var cell := Vector2i(int(entry[0]), int(entry[1]))
			if _inside_world(cell) and get_tile(cell) == AIR and not _lantern_cells.has(cell) and not _torch_cells.has(cell):
				_lantern_cells.append(cell)
				_create_lantern_light(cell)

func _create_lantern_light(cell: Vector2i) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.88, 0.58, 0.86))
	gradient.add_point(0.42, Color(1.0, 0.66, 0.24, 0.42))
	gradient.add_point(1.0, Color(1.0, 0.42, 0.10, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 160
	texture.height = 160
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var light := PointLight2D.new()
	light.name = "LanternLight_%d_%d" % [cell.x, cell.y]
	light.texture = texture
	light.texture_scale = 4.4
	light.energy = 1.6
	light.color = Color(1.0, 0.82, 0.52)
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.position = Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)
	add_child(light)
	_lantern_lights.append(light)

func _serialize_torches() -> Array:
	var result: Array = []
	for cell in _torch_cells:
		if _inside_world(cell) and get_tile(cell) == AIR:
			result.append([cell.x, cell.y])
	return result

func _restore_torches(raw_torches: Variant) -> void:
	_torch_cells.clear()
	for light in _torch_lights:
		if is_instance_valid(light):
			light.queue_free()
	_torch_lights.clear()
	if not raw_torches is Array:
		return
	for entry in raw_torches:
		if entry is Array and entry.size() == 2:
			var cell := Vector2i(int(entry[0]), int(entry[1]))
			if _inside_world(cell) and get_tile(cell) == AIR and not _torch_cells.has(cell):
				_torch_cells.append(cell)
				_create_torch_light(cell)

func _create_torch_light(cell: Vector2i) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.78, 0.38, 0.72))
	gradient.add_point(0.38, Color(1.0, 0.48, 0.12, 0.32))
	gradient.add_point(1.0, Color(1.0, 0.30, 0.08, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var light := PointLight2D.new()
	light.name = "TorchLight_%d_%d" % [cell.x, cell.y]
	light.texture = texture
	light.texture_scale = 3.0
	light.energy = 1.25
	light.color = Color(1.0, 0.72, 0.42)
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.position = Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)
	add_child(light)
	_torch_lights.append(light)

func _serialize_water_sources() -> Array:
	var result: Array = []
	for cell in _water_sources:
		var source_cell: Vector2i = cell
		if get_tile(source_cell) == WATER:
			result.append([source_cell.x, source_cell.y])
	return result

func _restore_water_sources(raw_sources: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw_sources is Array:
		return result
	for entry in raw_sources:
		if entry is Array and entry.size() == 2:
			var cell := Vector2i(int(entry[0]), int(entry[1]))
			if _inside_world(cell) and get_tile(cell) == WATER:
				result[cell] = true
	return result

func _generate_mine_shafts() -> void:
	# Two abandoned shafts connect separate underground layers with timber supports.
	for center_x in [72, 132]:
		var shaft_y := mini(get_surface_y(center_x) + 13, WORLD_HEIGHT - 8)
		for x in range(center_x - 10, center_x + 11):
			for y in range(shaft_y - 2, shaft_y + 2):
				if _inside_world(Vector2i(x, y)):
					tiles[x][y] = AIR
		for shaft_x in [center_x - 8, center_x, center_x + 8]:
			for y in range(shaft_y - 3, shaft_y + 2):
				if _inside_world(Vector2i(shaft_x, y)):
					tiles[shaft_x][y] = WOOD
		for branch_y in range(shaft_y - 6, shaft_y - 2):
			for side in [-1, 1]:
				var branch_cell := Vector2i(center_x + side * 8, branch_y)
				if _inside_world(branch_cell):
					tiles[branch_cell.x][branch_cell.y] = AIR

func _generate_dungeons() -> void:
	_dungeon_chests.clear()
	_dungeon_secret_rooms.clear()
	# Three fixed underground chambers, one in each biome, keep layouts reproducible.
	for dungeon_index in range(3):
		var center_x: int = [42, 102, 160][dungeon_index]
		var center_y := mini(get_surface_y(center_x) + 19, WORLD_HEIGHT - 9)
		for x in range(center_x - 7, center_x + 8):
			for y in range(center_y - 4, center_y + 4):
				if _inside_world(Vector2i(x, y)):
					tiles[x][y] = AIR
		for x in range(center_x - 8, center_x + 9):
			var floor_cell := Vector2i(x, center_y + 4)
			if _inside_world(floor_cell):
				tiles[floor_cell.x][floor_cell.y] = STONE
		match dungeon_index:
			0:
				# Pillar Hall: two broken columns create cover without blocking the center aisle.
				for pillar_x in [center_x - 5, center_x + 6]:
					for pillar_y in range(center_y - 1, center_y + 3):
						tiles[pillar_x][pillar_y] = STONE
			1:
				# High Gallery: staggered side ledges create vertical routes around the chest.
				for platform_x in range(center_x - 6, center_x - 2):
					tiles[platform_x][center_y - 1] = STONE
				for platform_x in range(center_x + 5, center_x + 8):
					tiles[platform_x][center_y - 2] = STONE
			2:
				# Flooded Vault: a shallow, non-renewable water trench crosses the chamber floor.
				for water_x in range(center_x - 2, center_x + 2):
					tiles[water_x][center_y + 3] = WATER
		var chest_cell := Vector2i(center_x + 3, center_y + 2)
		_dungeon_chests.append({"cell": chest_cell, "opened": false, "variant": dungeon_index})
		# A concealed side vault branches off the chamber's western wall.
		for x in range(center_x - 15, center_x - 8):
			for y in range(center_y - 3, center_y + 4):
				if _inside_world(Vector2i(x, y)):
					tiles[x][y] = AIR
			for y in range(center_y + 1, center_y + 3):
				var floor_cell := Vector2i(x, y + 3)
				if _inside_world(floor_cell):
					tiles[floor_cell.x][floor_cell.y] = STONE
		var gate_cells: Array[Vector2i] = [Vector2i(center_x - 8, center_y + 1), Vector2i(center_x - 8, center_y + 2)]
		for gate_cell in gate_cells:
			if _inside_world(gate_cell):
				tiles[gate_cell.x][gate_cell.y] = STONE
		var cache_cell := Vector2i(center_x - 12, center_y + 2)
		_dungeon_secret_rooms.append({"gate_cells": gate_cells, "cache_cell": cache_cell, "cache_opened": false})

func get_dungeon_chest_count() -> int:
	return _dungeon_chests.size()

func get_dungeon_secret_room_count() -> int:
	return _dungeon_secret_rooms.size()

func get_secret_gate_position(index: int = 0) -> Vector2:
	if index < 0 or index >= _dungeon_secret_rooms.size():
		return Vector2.ZERO
	var gate_cells: Array = _dungeon_secret_rooms[index]["gate_cells"]
	if gate_cells.is_empty():
		return Vector2.ZERO
	var cell: Vector2i = gate_cells[0]
	return to_global(Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 1.0) * TILE_SIZE))

func get_secret_cache_position(index: int = 0) -> Vector2:
	if index < 0 or index >= _dungeon_secret_rooms.size():
		return Vector2.ZERO
	var cell: Vector2i = _dungeon_secret_rooms[index]["cache_cell"]
	return to_global(Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE))

func get_nearest_secret_cache_position(world_position: Vector2) -> Vector2:
	if _dungeon_secret_rooms.is_empty():
		return world_position
	var nearest_position := get_secret_cache_position(0)
	var nearest_distance := world_position.distance_squared_to(nearest_position)
	for index in range(1, _dungeon_secret_rooms.size()):
		var candidate := get_secret_cache_position(index)
		var distance := world_position.distance_squared_to(candidate)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_position = candidate
	return nearest_position

func is_secret_vault_open_nearby(world_position: Vector2) -> bool:
	for index in range(_dungeon_secret_rooms.size()):
		var room: Dictionary = _dungeon_secret_rooms[index]
		var gate_cells: Array = room["gate_cells"]
		if gate_cells.is_empty() or get_tile(gate_cells[0]) != AIR:
			continue
		if world_position.distance_to(get_secret_cache_position(index)) <= TILE_SIZE * 10.0:
			return true
	return false

func unlock_nearby_secret_room(world_position: Vector2, inventory: PlayerInventory) -> bool:
	if inventory == null:
		return false
	for index in range(_dungeon_secret_rooms.size()):
		var room: Dictionary = _dungeon_secret_rooms[index]
		var gate_cells: Array = room["gate_cells"]
		if gate_cells.is_empty() or get_tile(gate_cells[0]) == AIR:
			continue
		if world_position.distance_to(get_secret_gate_position(index)) > TILE_SIZE * 2.5:
			continue
		if not inventory.remove_item("ancient_key", 1):
			return false
		for gate_cell in gate_cells:
			var cell: Vector2i = gate_cell
			if _inside_world(cell):
				tiles[cell.x][cell.y] = AIR
		_rebuild_collision()
		queue_redraw()
		return true
	return false

func open_nearby_secret_cache(world_position: Vector2, inventory: PlayerInventory) -> bool:
	if inventory == null:
		return false
	for index in range(_dungeon_secret_rooms.size()):
		var room: Dictionary = _dungeon_secret_rooms[index]
		var gate_cells: Array = room["gate_cells"]
		if gate_cells.is_empty() or get_tile(gate_cells[0]) != AIR or bool(room.get("cache_opened", false)):
			continue
		if world_position.distance_to(get_secret_cache_position(index)) > TILE_SIZE * 2.5:
			continue
		room["cache_opened"] = true
		_dungeon_secret_rooms[index] = room
		inventory.add_item("dungeon_relic", 1)
		inventory.add_item("gold_ore", 12)
		inventory.add_item("silver_ore", 8)
		inventory.add_item("healing_potion", 3)
		queue_redraw()
		return true
	return false

func get_nearest_dungeon_arena_position(world_position: Vector2) -> Vector2:
	if _dungeon_chests.is_empty():
		return world_position
	var nearest_position := world_position
	var nearest_distance := INF
	for chest in _dungeon_chests:
		var cell: Vector2i = chest["cell"]
		var center_x := cell.x - 3
		var floor_y := (cell.y + 2) * TILE_SIZE
		var arena_position := to_global(Vector2((center_x + 0.5) * TILE_SIZE, floor_y))
		var distance := world_position.distance_squared_to(arena_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_position = arena_position
	return nearest_position

func get_dungeon_guard_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for chest in _dungeon_chests:
		var cell: Vector2i = chest["cell"]
		var floor_y := (cell.y + 2) * TILE_SIZE
		positions.append(to_global(Vector2((cell.x - 6) * TILE_SIZE + TILE_SIZE * 0.5, floor_y)))
		positions.append(to_global(Vector2((cell.x + 1) * TILE_SIZE + TILE_SIZE * 0.5, floor_y)))
	return positions

func get_dungeon_spike_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for chest in _dungeon_chests:
		var cell: Vector2i = chest["cell"]
		var floor_y := (cell.y + 2) * TILE_SIZE
		positions.append(to_global(Vector2((cell.x - 4) * TILE_SIZE + TILE_SIZE * 0.5, floor_y)))
		positions.append(to_global(Vector2((cell.x + 3) * TILE_SIZE + TILE_SIZE * 0.5, floor_y)))
	return positions

func get_dungeon_blade_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for chest in _dungeon_chests:
		var cell: Vector2i = chest["cell"]
		var ceiling_y := (cell.y - 5) * TILE_SIZE
		positions.append(to_global(Vector2((cell.x - 1) * TILE_SIZE + TILE_SIZE * 0.5, ceiling_y)))
	return positions

func open_nearby_chest(world_position: Vector2, inventory: PlayerInventory) -> bool:
	if inventory == null:
		return false
	for index in range(_dungeon_chests.size()):
		var chest: Dictionary = _dungeon_chests[index]
		if bool(chest.get("opened", false)):
			continue
		var cell: Vector2i = chest["cell"]
		var chest_position := to_global(Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE))
		if world_position.distance_to(chest_position) > TILE_SIZE * 2.4:
			continue
		if not inventory.remove_item("dungeon_key", 1):
			return false
		chest["opened"] = true
		_dungeon_chests[index] = chest
		inventory.add_item("ore", CHEST_REWARD_ORE)
		inventory.add_item("silver_ore", 4 + index * 2)
		inventory.add_item("torch", 3)
		inventory.add_item("healing_potion", 2)
		if index == 2:
			inventory.add_item("gold_ore", 8)
			inventory.add_item("dungeon_relic", 1)
		queue_redraw()
		return true
	return false

func _serialize_chests() -> Array:
	var result: Array = []
	for chest in _dungeon_chests:
		var cell: Vector2i = chest["cell"]
		result.append([cell.x, cell.y, bool(chest.get("opened", false))])
	return result

func _restore_chests(raw_chests: Variant) -> void:
	_dungeon_chests.clear()
	if not raw_chests is Array:
		return
	for entry in raw_chests:
		if entry is Array and entry.size() == 3:
			var cell := Vector2i(int(entry[0]), int(entry[1]))
			if _inside_world(cell) and get_tile(cell) == AIR:
				_dungeon_chests.append({"cell": cell, "opened": bool(entry[2])})

func _serialize_secret_rooms() -> Array:
	var result: Array = []
	for room in _dungeon_secret_rooms:
		var cache_cell: Vector2i = room["cache_cell"]
		result.append([cache_cell.x, cache_cell.y, bool(room.get("cache_opened", false))])
	return result

func _restore_secret_rooms(raw_rooms: Variant) -> void:
	if not raw_rooms is Array or raw_rooms.is_empty():
		# Migrate worlds saved before secret vaults existed without resetting player edits.
		for room in _dungeon_secret_rooms:
			var gate_cells: Array = room["gate_cells"]
			if gate_cells.is_empty():
				continue
			var first_gate: Vector2i = gate_cells[0]
			for x in range(first_gate.x - 7, first_gate.x):
				for y in range(first_gate.y - 4, first_gate.y + 3):
					if _inside_world(Vector2i(x, y)):
						tiles[x][y] = AIR
				for floor_y in range(first_gate.y + 3, first_gate.y + 5):
					var floor_cell := Vector2i(x, floor_y)
					if _inside_world(floor_cell):
						tiles[floor_cell.x][floor_cell.y] = STONE
			for gate_cell in gate_cells:
				var cell: Vector2i = gate_cell
				if _inside_world(cell):
					tiles[cell.x][cell.y] = STONE
		_rebuild_collision()
		queue_redraw()
		return
	for entry in raw_rooms:
		if entry is Array and entry.size() == 3:
			var cache_cell := Vector2i(int(entry[0]), int(entry[1]))
			for index in range(_dungeon_secret_rooms.size()):
				var room: Dictionary = _dungeon_secret_rooms[index]
				if room["cache_cell"] == cache_cell:
					room["cache_opened"] = bool(entry[2])
					_dungeon_secret_rooms[index] = room
					break

func _generate_caves() -> void:
	# Carve deterministic underground pockets while protecting the surface layer.
	for x in range(1, WORLD_WIDTH - 1):
		var cave_floor := surface_heights[x] + 5
		for y in range(cave_floor, WORLD_HEIGHT - 4):
			var tile: int = tiles[x][y]
			if tile == STONE or tile == ORE:
				var cave_value := _cave_noise.get_noise_2d(float(x), float(y))
				var detail_value := _cave_detail_noise.get_noise_2d(float(x), float(y))
				if cave_value > 0.32 or (cave_value > 0.08 and detail_value > 0.48):
					tiles[x][y] = AIR


func _generate_underground_biomes() -> void:
	# A guaranteed glowing mushroom cavern in the western underground.
	var mushroom_x := 25
	var mushroom_y := mini(get_surface_y(mushroom_x) + 29, WORLD_HEIGHT - 7)
	for x in range(mushroom_x - 7, mushroom_x + 8):
		for y in range(mushroom_y - 3, mushroom_y + 3):
			if _inside_world(Vector2i(x, y)):
				tiles[x][y] = AIR
		if mushroom_x - 6 <= x and x <= mushroom_x + 6:
			var floor_cell := Vector2i(x, mushroom_y + 3)
			if _inside_world(floor_cell):
				tiles[floor_cell.x][floor_cell.y] = MUSHROOM_SOIL
	for offset in [-5, -2, 2, 5]:
		var mushroom_cell := Vector2i(mushroom_x + offset, mushroom_y + 2)
		if _inside_world(mushroom_cell):
			tiles[mushroom_cell.x][mushroom_cell.y] = GLOW_MUSHROOM

	# A separate deep desert magma chamber with a non-solid lava pool.
	var magma_x := 82
	var magma_y := mini(get_surface_y(magma_x) + 30, WORLD_HEIGHT - 8)
	for x in range(magma_x - 8, magma_x + 9):
		for y in range(magma_y - 3, magma_y + 3):
			if _inside_world(Vector2i(x, y)):
				tiles[x][y] = AIR
		var floor_cell := Vector2i(x, magma_y + 3)
		if _inside_world(floor_cell):
			tiles[floor_cell.x][floor_cell.y] = MAGMA_ROCK
	for x in range(magma_x - 4, magma_x + 5):
		for y in range(magma_y + 1, magma_y + 3):
			if _inside_world(Vector2i(x, y)):
				tiles[x][y] = LAVA
	for offset in [-7, -6, 6, 7]:
		var rim_cell := Vector2i(magma_x + offset, magma_y + 2)
		if _inside_world(rim_cell):
			tiles[rim_cell.x][rim_cell.y] = MAGMA_ROCK

func _generate_lakes() -> void:
	# Fixed centers and seeded widths create reproducible, guaranteed shallow basins.
	for center_x in [28, 83, 145]:
		var lake_width := 5 + int(absf(_noise.get_noise_1d(float(center_x) + 271.0)) * 4.0)
		var half_width := int(lake_width / 2)
		var start_x: int = maxi(center_x - half_width, 1)
		var end_x: int = mini(center_x + half_width, WORLD_WIDTH - 2)
		var waterline := surface_heights[center_x]
		for x in range(start_x, end_x + 1):
			var ground_y: int = surface_heights[x]
			if ground_y <= waterline:
				# Cut a level basin through higher ground so the water surface stays flat.
				for y in range(ground_y, waterline + 1):
					tiles[x][y] = WATER
			else:
				# Fill the lower part of the natural valley up to the same waterline.
				for y in range(waterline, ground_y):
					if tiles[x][y] == AIR:
						tiles[x][y] = WATER
			if waterline >= 0 and waterline < WORLD_HEIGHT and tiles[x][waterline] == WATER:
				_water_sources[Vector2i(x, waterline)] = true

func _simulate_water_step() -> int:
	# Collect source/destination pairs first so water advances one tile per step.
	if count_water_tiles() >= max_water_tiles:
		return 0
	var sources: Array[Vector2i] = []
	var destinations: Array[Vector2i] = []
	var reserved: Dictionary = {}
	for y in range(WORLD_HEIGHT - 2, -1, -1):
		for x in range(1, WORLD_WIDTH - 1):
			if tiles[x][y] != WATER:
				continue
			var below := Vector2i(x, y + 1)
			if tiles[below.x][below.y] == AIR and not reserved.has(below):
				sources.append(Vector2i(x, y))
				destinations.append(below)
				reserved[below] = true
				continue
			for side in [_water_flow_direction, -_water_flow_direction]:
				var target := Vector2i(x + side, y)
				var support := Vector2i(target.x, target.y + 1)
				var supported := tiles[support.x][support.y] != AIR and tiles[support.x][support.y] != LEAVES
				if tiles[target.x][target.y] == AIR and supported and not reserved.has(target):
					sources.append(Vector2i(x, y))
					destinations.append(target)
					reserved[target] = true
					break
	if sources.is_empty():
		_water_flow_direction *= -1
		return 0
	for index in range(sources.size()):
		var source: Vector2i = sources[index]
		var destination: Vector2i = destinations[index]
		if not (_water_sources.has(source) and destination.x == source.x and destination.y == source.y + 1):
			tiles[source.x][source.y] = AIR
			_water_sources.erase(source)
	for destination in destinations:
		tiles[destination.x][destination.y] = WATER
	_water_flow_direction *= -1
	queue_redraw()
	return sources.size()

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
	return tile != AIR and tile != LEAVES and tile != WATER and tile != GLOW_MUSHROOM and tile != LAVA

func _inside_world(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WORLD_WIDTH and cell.y >= 0 and cell.y < WORLD_HEIGHT

func _rebuild_collision() -> void:
	if _collision_root == null:
		return
	for child in _collision_root.get_children():
		child.queue_free()
	_loaded_collision_chunks.clear()
	_update_loaded_collision_chunks()

func _refresh_collision_chunk_for_cell(cell: Vector2i) -> void:
	if not _inside_world(cell):
		return
	var chunk_coord := Vector2i(cell.x / CHUNK_SIZE, cell.y / CHUNK_SIZE)
	if not _loaded_collision_chunks.has(chunk_coord):
		return
	var old_body := _loaded_collision_chunks[chunk_coord] as StaticBody2D
	if is_instance_valid(old_body):
		old_body.queue_free()
	_loaded_collision_chunks.erase(chunk_coord)
	_create_collision_chunk(chunk_coord)

func refresh_collision_stream() -> void:
	_update_loaded_collision_chunks()

func _update_loaded_collision_chunks() -> void:
	if _collision_root == null:
		return
	var tile_position := Vector2i(WORLD_WIDTH / 2, get_surface_y(WORLD_WIDTH / 2))
	var player := get_node_or_null(player_path) as Node2D
	if player != null:
		var local_position := to_local(player.global_position)
		tile_position = Vector2i(floori(local_position.x / TILE_SIZE), floori(local_position.y / TILE_SIZE))
	var chunk_columns := ceili(float(WORLD_WIDTH) / float(CHUNK_SIZE))
	var chunk_rows := ceili(float(WORLD_HEIGHT) / float(CHUNK_SIZE))
	var center_chunk := Vector2i(
		clampi(floori(float(tile_position.x) / float(CHUNK_SIZE)), 0, chunk_columns - 1),
		clampi(floori(float(tile_position.y) / float(CHUNK_SIZE)), 0, chunk_rows - 1)
	)
	var desired_chunks: Dictionary = {}
	for chunk_y in range(maxi(center_chunk.y - CHUNK_LOAD_RADIUS, 0), mini(center_chunk.y + CHUNK_LOAD_RADIUS + 1, chunk_rows)):
		for chunk_x in range(maxi(center_chunk.x - CHUNK_LOAD_RADIUS, 0), mini(center_chunk.x + CHUNK_LOAD_RADIUS + 1, chunk_columns)):
			desired_chunks[Vector2i(chunk_x, chunk_y)] = true
	for loaded_key in _loaded_collision_chunks.keys():
		if not desired_chunks.has(loaded_key):
			var old_body := _loaded_collision_chunks[loaded_key] as StaticBody2D
			if is_instance_valid(old_body):
				old_body.queue_free()
			_loaded_collision_chunks.erase(loaded_key)
	for desired_key in desired_chunks.keys():
		if not _loaded_collision_chunks.has(desired_key):
			_create_collision_chunk(desired_key)

func _create_collision_chunk(chunk_coord: Vector2i) -> void:
	var chunk_body := StaticBody2D.new()
	chunk_body.name = "TerrainChunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
	chunk_body.collision_layer = 1
	chunk_body.collision_mask = 0
	_collision_root.add_child(chunk_body)
	var start_x := chunk_coord.x * CHUNK_SIZE
	var end_x := mini(start_x + CHUNK_SIZE, WORLD_WIDTH)
	var start_y := chunk_coord.y * CHUNK_SIZE
	var end_y := mini(start_y + CHUNK_SIZE, WORLD_HEIGHT)
	for y in range(start_y, end_y):
		var x := start_x
		while x < end_x:
			while x < end_x and not _is_solid_tile(tiles[x][y]):
				x += 1
			if x >= end_x:
				break
			var run_start := x
			while x < end_x and _is_solid_tile(tiles[x][y]):
				x += 1
			var shape_node := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2((x - run_start) * TILE_SIZE, TILE_SIZE)
			shape_node.shape = shape
			shape_node.position = Vector2((run_start + x) * TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
			chunk_body.add_child(shape_node)
	_loaded_collision_chunks[chunk_coord] = chunk_body

func _process(delta: float) -> void:
	_chunk_update_elapsed += delta
	if _chunk_update_elapsed >= 0.2:
		_chunk_update_elapsed = 0.0
		_update_loaded_collision_chunks()
	_mine_cooldown_remaining = maxf(_mine_cooldown_remaining - delta, 0.0)
	_water_flow_elapsed += delta
	if _water_flow_elapsed >= water_flow_interval:
		_water_flow_elapsed = 0.0
		_simulate_water_step()
	if Input.is_action_just_pressed("cycle_block"):
		cycle_block_selection()
	if Input.is_action_pressed("mine") and _mine_cooldown_remaining <= 0.0:
		_edit_target(false)
		var player := get_node_or_null(player_path) as PlayerController
		var mining_multiplier := player.inventory.get_mining_speed_multiplier() if player != null else 1.0
		_mine_cooldown_remaining = 0.34 / mining_multiplier
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
