#map manager: in charge of setting up levels, objective tiles, line of sight and pathfinding
class_name MapManager
extends Node2D

const WALL_SOURCE_ID := 1
const OBJECTIVE_SOURCE_ID := 2

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var obstacle_layer: TileMapLayer = $ObstacleLayer
@onready var objective_layer: TileMapLayer = $ObjectiveLayer

# global switch for line of sight checks (units can also opt out one by one in their data)
@export var line_of_sight_enabled: bool = true

# A* grid whose diagonal steps never clip the corner of a wall or a pricey tile (mine, box...):
# units have a body, so cutting past one would brush it
class TileAStar extends AStarGrid2D:
	func _compute_cost(from_id: Vector2i, to_id: Vector2i) -> float:
		var step := to_id - from_id
		if step.x != 0 and step.y != 0:
			for corner in [Vector2i(to_id.x, from_id.y), Vector2i(from_id.x, to_id.y)]:
				if is_point_solid(corner) or get_point_weight_scale(corner) > 1.0:
					return 1.0e6
		return Vector2(step).length()

#store astar grid for pathfinding
var astar_grid: AStarGrid2D
var tile_size: float = 64.0

# one static collider per solid tile (walls, holes, and a ring around the map) so physical units can't leave the floor
var _solid_body: StaticBody2D
var _solid_shapes: Dictionary = {}

var objective_tiles: Array[Vector2i] = []
var _objective_lookup: Dictionary = {}

#on load, set up grid
func _ready() -> void:
	setup_grid()
	refresh_objectives()

#set up pathfinding grid
func setup_grid() -> void:
	astar_grid = TileAStar.new()
	tile_size = ground_layer.tile_set.tile_size.x

	# 1. Define the grid boundaries based on your Ground layer
	astar_grid.region = ground_layer.get_used_rect()
	astar_grid.cell_size = Vector2(ground_layer.tile_set.tile_size)
	astar_grid.offset = astar_grid.cell_size / 2.0 # Centers points in the middle of tiles

	# 2. Configure pathing behavior
	# 8-way movement, but never cutting the corner of a wall
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE

	# 3. Initialize the grid (must call this before using it)
	astar_grid.update()

	# 4. Holes in the ground and every wall tile are solid
	for x in range(astar_grid.region.position.x, astar_grid.region.end.x):
		for y in range(astar_grid.region.position.y, astar_grid.region.end.y):
			var cell := Vector2i(x, y)
			if ground_layer.get_cell_source_id(cell) == -1:
				astar_grid.set_point_solid(cell, true)
	for cell in obstacle_layer.get_used_cells():
		if astar_grid.is_in_boundsv(cell):
			astar_grid.set_point_solid(cell, true)

	# 5. Physical colliders for every solid tile, plus a border ring outside the map
	_solid_body = StaticBody2D.new()
	_solid_body.name = "SolidTiles"
	add_child(_solid_body)
	var region := astar_grid.region.grow(1)
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var cell := Vector2i(x, y)
			if is_solid(cell):
				_set_tile_collider(cell, true)

# --- PUBLIC HELPER FUNCTIONS ---
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(world_pos))

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return ground_layer.to_global(ground_layer.map_to_local(grid_pos))

func is_in_bounds(grid_pos: Vector2i) -> bool:
	return astar_grid.is_in_boundsv(grid_pos)

# walls, holes and anything off the map
func is_solid(grid_pos: Vector2i) -> bool:
	return not astar_grid.is_in_boundsv(grid_pos) or astar_grid.is_point_solid(grid_pos)

func is_walkable(grid_pos: Vector2i) -> bool:
	return not is_solid(grid_pos)

# cheapest tile path (weights included). the first tile is `from`.
# allow_partial returns the path to the closest reachable tile when `to` can't be reached
func get_tile_path(from: Vector2i, to: Vector2i, allow_partial: bool = false) -> Array[Vector2i]:
	if not is_in_bounds(from) or not is_in_bounds(to):
		return []
	return astar_grid.get_id_path(from, to, allow_partial)

# total cost of walking a path, matching how A* scores it
func get_path_cost(path: Array[Vector2i]) -> float:
	var cost := 0.0
	for i in range(1, path.size()):
		cost += Vector2(path[i] - path[i - 1]).length() * astar_grid.get_point_weight_scale(path[i])
	return cost

func get_tile_weight(grid_pos: Vector2i) -> float:
	return astar_grid.get_point_weight_scale(grid_pos) if is_in_bounds(grid_pos) else INF

func set_tile_weight(grid_pos: Vector2i, weight: float) -> void:
	if astar_grid.is_in_boundsv(grid_pos):
		astar_grid.set_point_weight_scale(grid_pos, weight)

# tiles a sight line from `from` to `to` passes over, not counting the two end tiles
func get_line_tiles(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var start := Vector2(from)
	var end := Vector2(to)
	var samples := ceili(start.distance_to(end) * 4.0)
	for i in range(1, samples):
		var tile := Vector2i(start.lerp(end, float(i) / samples).round())
		if tile != from and tile != to and (tiles.is_empty() or tiles[-1] != tile):
			tiles.append(tile)
	return tiles

# --- OBJECTIVES ---

func is_objective(grid_pos: Vector2i) -> bool:
	return _objective_lookup.has(grid_pos)

# extra path cost for an objective tile someone is already standing on, so units spread over the zone
const TAKEN_TILE_COST := 4.0

# the objective tile that is cheapest to walk to (checks the few closest by straight distance).
# tiles in `taken` count as pricier
func find_nearest_objective_tile(from: Vector2i, taken: Dictionary = {}) -> Variant:
	var candidates := objective_tiles.duplicate()
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _manhattan(a, from) < _manhattan(b, from))

	var best: Variant = null
	var best_cost := INF
	for tile in candidates.slice(0, 6):
		if tile == from:
			return tile
		var path := get_tile_path(from, tile)
		if path.is_empty():
			continue
		var cost := get_path_cost(path) + (TAKEN_TILE_COST if taken.has(tile) else 0.0)
		if cost < best_cost:
			best_cost = cost
			best = tile
	return best

# rebuild the objective lookup. call after painting objective tiles or walls
func refresh_objectives() -> void:
	objective_tiles.clear()
	_objective_lookup.clear()
	for cell in objective_layer.get_used_cells():
		if is_walkable(cell):
			objective_tiles.append(cell)
			_objective_lookup[cell] = true

# --- RUNTIME EDITING (debug tools, and later level scripting) ---

func set_wall(grid_pos: Vector2i, solid: bool) -> void:
	if not is_in_bounds(grid_pos):
		return
	if solid:
		obstacle_layer.set_cell(grid_pos, WALL_SOURCE_ID, Vector2i.ZERO)
	else:
		obstacle_layer.erase_cell(grid_pos)
	astar_grid.set_point_solid(grid_pos, solid or ground_layer.get_cell_source_id(grid_pos) == -1)
	_set_tile_collider(grid_pos, is_solid(grid_pos))
	refresh_objectives()

func set_objective(grid_pos: Vector2i, enabled: bool) -> void:
	if not is_walkable(grid_pos):
		return
	if enabled:
		objective_layer.set_cell(grid_pos, OBJECTIVE_SOURCE_ID, Vector2i.ZERO)
	else:
		objective_layer.erase_cell(grid_pos)
	refresh_objectives()

func _set_tile_collider(grid_pos: Vector2i, solid: bool) -> void:
	if solid == _solid_shapes.has(grid_pos):
		return
	if not solid:
		_solid_shapes[grid_pos].queue_free()
		_solid_shapes.erase(grid_pos)
		return
	var box := RectangleShape2D.new()
	box.size = Vector2.ONE * tile_size
	var collider := CollisionShape2D.new()
	collider.shape = box
	collider.position = _solid_body.to_local(grid_to_world(grid_pos))
	_solid_body.add_child(collider)
	_solid_shapes[grid_pos] = collider

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
