# combat_manager: collects every hit made during a tick and applies them all at once when the tick resolves.
# order of resolution: damage -> stun + push (survivors only) -> deaths.
# because nothing dies until every hit has landed, two units hitting each other on the same tick trade
class_name CombatManager
extends Node

class Hit:
	var target: Entity
	var damage: float
	# how hard the hit shoves: the target's velocity changes by push / target mass
	var push: float
	var stun_ticks: int
	# where the hit came from (world position); the push points away from it
	var origin: Vector2

# natural push per point of damage
@export var push_per_damage: float = 30.0
# natural push per unit of the attacker's pushing force (mass × acceleration), for melee blows
@export var push_per_force: float = 0.15

@onready var entity_manager: EntityManager = $"../EntityManager"
@onready var map_manager: MapManager = $"../MapManager"

var _hits: Array[Hit] = []
var _kills: Array[Entity] = []

func queue_hit(target: Entity, damage: float, push: float, stun_ticks: int, origin: Vector2) -> void:
	var hit := Hit.new()
	hit.target = target
	hit.damage = damage
	hit.push = push
	hit.stun_ticks = stun_ticks
	hit.origin = origin
	_hits.append(hit)

# damages and pushes every hostile entity with health within `radius` tiles of `source`
func queue_explosion(source: Entity, radius: float, damage: float, push: float, stun_ticks: int) -> void:
	for other in entity_manager.get_entities_in_radius(source.current_grid_pos, radius):
		if other.is_alive and other.health and source.is_hostile_to(other):
			queue_hit(other, damage, push, stun_ticks, source.global_position)

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
		if hit.push > 0.0:
			_apply_push(hit.target, hit.origin, hit.push)

	# 3. deaths, all at once
	for hit in hits:
		if _is_live(hit.target) and hit.target.health and hit.target.health.is_depleted():
			kills.append(hit.target)
	for entity in kills:
		if _is_live(entity):
			entity_manager.remove_entity(entity)

# shove `target` away from `origin`. walls and other bodies stop it through normal collisions
func _apply_push(target: Entity, origin: Vector2, push: float) -> void:
	if target.movement == null:
		return
	var away := target.global_position - origin
	if away.length() < 1.0:
		# hit from directly underneath (a mine): push back the way the unit was going
		away = -target.movement.velocity if target.movement.velocity.length() > 1.0 else -Vector2(target.movement.facing)
	target.movement.apply_impulse(away.normalized() * push)

func _is_live(entity: Variant) -> bool:
	return is_instance_valid(entity) and entity.is_alive
