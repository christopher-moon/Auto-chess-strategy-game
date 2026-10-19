# combat_manager: collects every hit made during a tick and applies them all at once when the tick resolves.
# order of resolution: damage -> stun + knockback (survivors only) -> deaths.
# because nothing dies until every hit has landed, two units hitting each other on the same tick trade
class_name CombatManager
extends Node

class Hit:
	var target: Entity
	var damage: float
	var knockback: int
	var stun_ticks: int
	# the tile the hit came from; knockback pushes away from it
	var origin_tile: Vector2i

@onready var entity_manager: EntityManager = $"../EntityManager"
@onready var map_manager: MapManager = $"../MapManager"

var _hits: Array[Hit] = []
var _kills: Array[Entity] = []

func queue_hit(target: Entity, damage: float, knockback: int, stun_ticks: int, origin_tile: Vector2i) -> void:
	var hit := Hit.new()
	hit.target = target
	hit.damage = damage
	hit.knockback = knockback
	hit.stun_ticks = stun_ticks
	hit.origin_tile = origin_tile
	_hits.append(hit)

# damages every hostile entity with health within `radius` tiles of `center`
func queue_explosion(source: Entity, center: Vector2i, radius: float, damage: float, knockback: int, stun_ticks: int) -> void:
	for other in entity_manager.get_entities_in_radius(center, radius):
		if other.is_alive and other.health and source.is_hostile_to(other):
			queue_hit(other, damage, knockback, stun_ticks, center)

# removes an entity at the end of the tick (e.g. a mine that just exploded)
func queue_kill(entity: Entity) -> void:
	_kills.append(entity)

# called by the TimeManager right after every entity has taken its tick
func resolve() -> void:
	if _hits.is_empty() and _kills.is_empty():
		return
	var hits := _hits
	var kills := _kills
	_hits = []
	_kills = []

	# 1. all damage lands together
	for hit in hits:
		if _is_live(hit.target) and hit.target.health:
			hit.target.health.apply_damage(hit.damage)

	# 2. stun and knockback, only for those still standing
	for hit in hits:
		if not _is_live(hit.target) or hit.target.health == null or hit.target.health.is_depleted():
			continue
		if hit.stun_ticks > 0:
			hit.target.apply_stun(hit.stun_ticks)
		if hit.knockback > 0:
			_apply_knockback(hit.target, hit.origin_tile, hit.knockback)

	# 3. deaths, all at once
	for hit in hits:
		if _is_live(hit.target) and hit.target.health and hit.target.health.is_depleted():
			kills.append(hit.target)
	for entity in kills:
		if _is_live(entity):
			entity_manager.remove_entity(entity)

# push `target` up to `tiles` tiles straight away from `origin`, stopping before walls, holes and blockers
func _apply_knockback(target: Entity, origin: Vector2i, tiles: int) -> void:
	if target.movement == null:
		return
	var away := target.current_grid_pos - origin
	if away == Vector2i.ZERO:
		# hit from directly underneath (a mine): push back the way the unit came
		away = -target.movement.facing
	# snap to the main axis to match the 4-way grid
	var direction := Vector2i(signi(away.x), 0) if absi(away.x) >= absi(away.y) else Vector2i(0, signi(away.y))

	var destination := target.current_grid_pos
	for i in tiles:
		var next := destination + direction
		if not target.world.is_tile_open(next, target):
			break
		destination = next
	if destination != target.current_grid_pos:
		target.movement.knock_to(destination)

func _is_live(entity: Variant) -> bool:
	return is_instance_valid(entity) and entity.is_alive
