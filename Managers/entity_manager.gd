#entity manager: in charge of tracking entity position (tile), team, and status (alive/dead)
class_name EntityManager
extends Node

signal entity_registered(entity: Entity)
signal entity_removed(entity: Entity)

@onready var map_manager: MapManager = $"../MapManager"

# --- CATEGORY TRACKING ---
# Storing entities by type and team makes AI targeting very fast.
var actors: Array[Entity] = []
var obstacles: Array[Entity] = []
var triggers: Array[Entity] = []
# Key: Entity.Team, Value: Array of entities on that team
var by_team: Dictionary = {}

# --- SPATIAL TRACKING ---
# Key: Vector2i (Grid coordinates, e.g., Vector2i(2, 3))
# Value: Array (List of entities in that tile)
var grid_occupancy: Dictionary = {}

# --- PUBLIC HELPER FUNCTIONS ---

func register_entity(entity: Entity) -> void:
	# 1. Add to the appropriate category list
	_category_list(entity).append(entity)
	if not by_team.has(entity.team):
		by_team[entity.team] = []
	by_team[entity.team].append(entity)

	# 2. Add to the spatial grid
	_add_to_grid(entity, entity.current_grid_pos)
	entity_registered.emit(entity)

func unregister_entity(entity: Entity) -> void:
	# 1. Remove from category list
	_category_list(entity).erase(entity)
	if by_team.has(entity.team):
		by_team[entity.team].erase(entity)

	# 2. Remove from spatial grid
	_remove_from_grid(entity, entity.current_grid_pos)

# removes an entity from the game for good (death, projectile impact, debug delete)
func remove_entity(entity: Entity) -> void:
	if not entity.is_alive:
		return
	entity.is_alive = false
	unregister_entity(entity)
	entity.died.emit(entity)
	entity_removed.emit(entity)
	entity.queue_free()

func update_entity_grid_position(entity: Entity, grid_pos: Vector2i) -> void:
	if entity.current_grid_pos == grid_pos:
		return # Entity hasn't crossed a tile boundary; do nothing

	_remove_from_grid(entity, entity.current_grid_pos)
	entity.current_grid_pos = grid_pos
	_add_to_grid(entity, grid_pos)

	# let mines (and future pressure plates) know someone stepped on them
	for other in get_entities_at_grid(grid_pos):
		if other != entity and other.combat and other.shell_type == EntityData.EntityShell.TRIGGER:
			other.combat.on_tile_entered(entity)

# Useful for explosions, AOE abilities, or checking if a tile is blocked
func get_entities_at_grid(grid_pos: Vector2i) -> Array:
	return grid_occupancy.get(grid_pos, [])

# every entity whose tile is within `radius` tiles of `center`
func get_entities_in_radius(center: Vector2i, radius: float) -> Array[Entity]:
	var found: Array[Entity] = []
	var reach := ceili(radius)
	for x in range(center.x - reach, center.x + reach + 1):
		for y in range(center.y - reach, center.y + reach + 1):
			var tile := Vector2i(x, y)
			if Vector2(tile).distance_to(Vector2(center)) > radius:
				continue
			for e in get_entities_at_grid(tile):
				found.append(e)
	return found

# the entity physically blocking a tile (box, turret...), or null
func get_blocker_at(grid_pos: Vector2i, ignore: Entity = null) -> Entity:
	for e in get_entities_at_grid(grid_pos):
		if e.blocks_movement and e != ignore:
			return e
	return null

func has_sight_blocker_at(grid_pos: Vector2i) -> bool:
	for e in get_entities_at_grid(grid_pos):
		if e.blocks_line_of_sight:
			return true
	return false

# the closest hostile, targetable entity with health within `range_tiles` that `entity` can see
func find_nearest_enemy(entity: Entity, range_tiles: float) -> Entity:
	var best: Entity = null
	var best_distance := INF
	var origin := Vector2(entity.current_grid_pos)
	for team in by_team:
		if team == entity.team or team == Entity.Team.NEUTRAL:
			continue
		for other: Entity in by_team[team]:
			if not other.is_alive or not other.targetable or other.health == null:
				continue
			var distance := origin.distance_to(Vector2(other.current_grid_pos))
			if distance > range_tiles or distance >= best_distance:
				continue
			if entity.combat and not entity.combat.can_see(other):
				continue
			best = other
			best_distance = distance
	return best

# alive units (actors) of a team
func count_team_actors(team: Entity.Team) -> int:
	var count := 0
	for e in by_team.get(team, []):
		if e.is_alive and e.shell_type == EntityData.EntityShell.ACTOR:
			count += 1
	return count

# ==========================================
# INTERNAL HELPERS
# ==========================================

func _category_list(entity: Entity) -> Array[Entity]:
	match entity.shell_type:
		EntityData.EntityShell.ACTOR: return actors
		EntityData.EntityShell.OBSTACLE: return obstacles
		_: return triggers

func _sync_tile_weight(grid_pos: Vector2i) -> void:
	var max_weight: float = 1.0 # Default AStar weight is 1.0

	# Loop through everything on this tile to find the heaviest object
	for e in get_entities_at_grid(grid_pos):
		if e.pathing_weight > max_weight:
			max_weight = e.pathing_weight

	# Tell the map manager to update the pathfinder
	map_manager.set_tile_weight(grid_pos, max_weight)

func _add_to_grid(entity: Entity, grid_pos: Vector2i) -> void:
	if not grid_occupancy.has(grid_pos):
		grid_occupancy[grid_pos] = []
	grid_occupancy[grid_pos].append(entity)
	if entity.pathing_weight != 1.0:
		_sync_tile_weight(grid_pos)

func _remove_from_grid(entity: Entity, grid_pos: Vector2i) -> void:
	if grid_occupancy.has(grid_pos):
		grid_occupancy[grid_pos].erase(entity)
		# Clean up empty dictionary keys to save memory
		if grid_occupancy[grid_pos].is_empty():
			grid_occupancy.erase(grid_pos)
	if entity.pathing_weight != 1.0:
		_sync_tile_weight(grid_pos)

# ==========================================
# TICK FUNCTIONS
# ==========================================
# NEVER CALL GET_NODE() in a tick loop
func process_ai_tick() -> void:
	# iterate over copies: spawners can add entities and mines can remove themselves mid-tick
	for list in [actors.duplicate(), obstacles.duplicate(), triggers.duplicate()]:
		for entity: Entity in list:
			if entity.is_alive:
				entity.tick()
