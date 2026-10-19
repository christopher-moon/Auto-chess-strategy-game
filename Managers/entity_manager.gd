#entity manager: in charge of tracking entity position (tile), team, and status (alive/dead)
class_name EntityManager
extends Node

@onready var map_manager: MapManager = $"../MapManager" # NEW: Grab the map manager reference

# --- CATEGORY TRACKING ---
# Storing entities by type makes AI targeting very fast.
var actors: Array[Entity] = []
var obstacles: Array[Entity] = []
var triggers: Array[Entity] = []

# --- SPATIAL TRACKING ---
# Key: Vector2 (Grid coordinates, e.g., Vector2(2, 3))
# Value: Array[Node2D] (List of entities in that tile)
var grid_occupancy: Dictionary = {}

# --- PUBLIC HELPER FUNCTIONS ---

func register_entity(entity: Entity) -> void:
	# 1. Add to the appropriate category list
	match entity.shell_type:
		EntityData.EntityShell.ACTOR: actors.append(entity)
		EntityData.EntityShell.OBSTACLE: obstacles.append(entity)
		EntityData.EntityShell.TRIGGER: triggers.append(entity)
		_: push_warning("EntityManager: Unknown category '%s'" % entity.identity.team)
	
	# 2. Add to the spatial grid
	_add_to_grid(entity, entity.current_grid_pos)
	
	# 3. sync tile weights
	_sync_tile_weight(entity.current_grid_pos)

func unregister_entity(entity: Entity) -> void:
	# 1. Remove from category list
	match entity.shell_type:
		EntityData.EntityShell.ACTOR: actors.erase(entity)
		EntityData.EntityShell.OBSTACLE: obstacles.erase(entity)
		EntityData.EntityShell.TRIGGER: triggers.erase(entity)
		
	# 2. Remove from spatial grid
	_remove_from_grid(entity, entity.current_grid_pos)
	
	# 3. sync tile weights
	_sync_tile_weight(entity.current_grid_pos)

func update_entity_grid_position(entity: Entity, position: Vector2) -> void:
	if entity.current_grid_pos == position:
		return # Entity hasn't crossed a tile boundary; do nothing
		
	_remove_from_grid(entity, entity.current_grid_pos)
	_add_to_grid(entity, position)
	
	entity.current_grid_pos = position

# Useful for explosions, AOE abilities, or checking if a tile is blocked
func get_entities_at_grid(grid_pos: Vector2) -> Array:
	return grid_occupancy.get(grid_pos, [])

# ==========================================
# INTERNAL HELPERS
# ==========================================

func _sync_tile_weight(grid_pos: Vector2) -> void:
	var entities = get_entities_at_grid(grid_pos)
	var max_weight: float = 1.0 # Default AStar weight is 1.0
	
	# Loop through everything on this tile to find the heaviest object
	for e in entities:
		if e.pathing_weight > max_weight:
			max_weight = e.pathing_weight
			
	# Tell the map manager to update the pathfinder
	map_manager.set_tile_weight(Vector2i(grid_pos), max_weight)

func _add_to_grid(entity: Node2D, grid_pos: Vector2) -> void:
	if not grid_occupancy.has(grid_pos):
		grid_occupancy[grid_pos] = []
	grid_occupancy[grid_pos].append(entity)

func _remove_from_grid(entity: Node2D, grid_pos: Vector2) -> void:
	if grid_occupancy.has(grid_pos):
		grid_occupancy[grid_pos].erase(entity)
		# Clean up empty dictionary keys to save memory
		if grid_occupancy[grid_pos].is_empty():
			grid_occupancy.erase(grid_pos)
			
# ==========================================
# TICK FUNCTIONS
# ==========================================
# NEVER CALL GET_NODE() in a tick loop
func process_ai_tick() -> void:
	# Loop through units and trigger their AI logic
	for actor in actors:
		_tick_entity(actor)
		
	for obs in obstacles:
		_tick_entity(obs)

func _tick_entity(entity: Node2D) -> void:
	print("tick")
	# Assuming your entities have a StateMachine node as per your tree design
	#var state_machine = entity.get_node_or_null("StateMachine")
	#if state_machine and state_machine.has_method("on_tick"):
		#state_machine.on_tick()
