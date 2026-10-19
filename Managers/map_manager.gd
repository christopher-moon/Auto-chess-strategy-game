#map manager: in charge of setting up levels and handling pathfinding
class_name MapManager
extends Node2D

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var obstacle_layer: TileMapLayer = $ObstacleLayer

#store astar grid for pathfinding
var astar_grid: AStarGrid2D

#on load, set up grid
func _ready() -> void:
	setup_grid()

#set up pathfinding grid
func setup_grid():
	astar_grid = AStarGrid2D.new()
	
	# 1. Define the grid boundaries based on your Ground layer
	var map_rect = ground_layer.get_used_rect()
	astar_grid.region = map_rect
	astar_grid.cell_size = Vector2(64, 64)
	astar_grid.offset = Vector2(32, 32) # Centers points in the middle of tiles
	
	# 2. Configure pathing behavior
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER # Snappy 4-way movement
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	
	# 3. Initialize the grid (must call this before using it)
	astar_grid.update()
	
	# 4. Fill the grid with 'Solid' walls and 'Weighted' obstacles
	sync_obstacles_to_grid()

func sync_obstacles_to_grid():
	# Loop through every tile you drew in the ObstacleLayer
	for cell in obstacle_layer.get_used_cells():
		# In Godot, you can use 'Custom Data' on tiles to differentiate 
		# between a hard wall (solid) and a mine (weighted).
		# For now, let's treat everything on the obstacle layer as a solid wall.
		astar_grid.set_point_solid(cell, true)

# --- PUBLIC HELPER FUNCTIONS ---
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return ground_layer.local_to_map(world_pos)
	
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return ground_layer.map_to_local(grid_pos)

func get_world_path(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	# Convert world pixels to grid coordinates (e.g., 128, 128 -> 2, 2)
	var start_grid = world_to_grid(start_pos)
	var end_grid = world_to_grid(end_pos)
	
	# Check if points are valid
	if not astar_grid.is_in_boundsv(start_grid) or not astar_grid.is_in_boundsv(end_grid):
		return []
		
	# Get the path as world positions
	return astar_grid.get_point_path(start_grid, end_grid)
	
func set_tile_weight(grid_pos: Vector2i, weight: float) -> void:
	if astar_grid.is_in_boundsv(grid_pos):
		astar_grid.set_point_weight_scale(grid_pos, weight)
