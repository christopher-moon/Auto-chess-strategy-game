# world: shared references to the level's managers, plus queries that need more than one of them.
# The spawner hands this to every entity, so components never have to search the scene tree.
class_name World
extends RefCounted

var map: MapManager
var entities: EntityManager
var combat: CombatManager
var spawner: EntitySpawner
var time: TimeManager

func _init(map_mgr: MapManager, entity_mgr: EntityManager, combat_mgr: CombatManager, entity_spawner: EntitySpawner, time_mgr: TimeManager) -> void:
	map = map_mgr
	entities = entity_mgr
	combat = combat_mgr
	spawner = entity_spawner
	time = time_mgr

# convert a duration in seconds to a whole number of AI ticks (at least 1)
func seconds_to_ticks(seconds: float) -> int:
	return maxi(1, roundi(seconds / time.tick_rate))

# true when nothing blocks sight between two tiles (walls, or entities flagged blocks_line_of_sight).
# the two end tiles never block, so a unit can always see the box it is standing next to
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if not map.line_of_sight_enabled:
		return true
	for tile in map.get_line_tiles(from, to):
		if map.is_solid(tile) or entities.has_sight_blocker_at(tile):
			return false
	return true

# true when a unit could physically stand on this tile (in bounds, no wall, no box/structure)
func is_tile_open(tile: Vector2i, ignore: Entity = null) -> bool:
	return map.is_walkable(tile) and entities.get_blocker_at(tile, ignore) == null

# nearest open tile around `tile` (the 8 neighbours), preferring tiles with nobody on them.
# returns null when every neighbour is blocked
func find_open_tile_near(tile: Vector2i) -> Variant:
	var fallback: Variant = null
	for offset in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var candidate: Vector2i = tile + offset
		if not is_tile_open(candidate):
			continue
		if entities.get_entities_at_grid(candidate).is_empty():
			return candidate
		if fallback == null:
			fallback = candidate
	return fallback

# the tile a unit should walk to so it can attack `target`: the first tile on the cheapest path
# towards the target that is inside attack range (and has line of sight, when the unit needs it).
# `allowed` can reject tiles, e.g. defenders refuse tiles too far from the objective.
# returns null when no such tile exists
func find_attack_tile(entity: Entity, target: Entity, allowed: Callable = Callable()) -> Variant:
	var path := map.get_tile_path(entity.movement.get_path_origin(), target.current_grid_pos, true)
	for tile in path:
		if not entity.combat.can_attack_from(tile, target):
			continue
		if allowed.is_valid() and not allowed.call(tile):
			continue
		return tile
	return null
