# behavior: the "brain" that decides which state a unit should be in each tick.
# behaviors are shared resources (one .tres for every unit using it), so they must stay stateless:
# per-unit memory lives on the unit's components (combat.target, movement.goal_tile)
class_name Behavior
extends Resource

const Id = StateMachine.StateId
# returned by _engage when the target can't be reached or attacked
const NO_ENGAGE := -1
# tiles beyond attack range within which charging units run straight at their target instead of pathing
const CHARGE_REACH := 1.0

func decide(_entity: Entity) -> int:
	return Id.IDLE

# --- shared helpers ---

# forget the target once it is dead or obscured
func _validate_target(entity: Entity) -> void:
	var combat := entity.combat
	if combat.target == null:
		return
	if not combat.has_valid_target() or not combat.can_see(combat.target):
		combat.clear_target()

# nearest hostile, targetable entity inside `range_tiles` that this unit can see
func _acquire_target(entity: Entity, range_tiles: float) -> Entity:
	return entity.world.entities.find_nearest_enemy(entity, range_tiles)

# if a box or enemy structure stopped our movement, break through it
func _take_blocker_as_target(entity: Entity) -> void:
	if entity.movement == null or entity.movement.blocker == null:
		return
	var blocker: Variant = entity.movement.blocker
	entity.movement.blocker = null
	if is_instance_valid(blocker) and blocker.is_alive and blocker.health and blocker.team != entity.team:
		entity.combat.target = blocker

# fight `target`: the Attacking state hits it whenever it is in range, while this keeps the unit moving.
# chargers run straight at a target that is close and in sight; everyone else walks to the nearest tile
# they can attack it from, and units that don't charge hold still once in range.
# `allowed` can veto tiles to walk to (defenders use it to stay near home)
func _engage(entity: Entity, target: Entity, allowed: Callable = Callable()) -> int:
	var combat := entity.combat
	var movement := entity.movement
	var in_range := combat.can_attack(target)
	if movement == null:
		return Id.ATTACKING if in_range else NO_ENGAGE

	var close := entity.current_grid_pos.distance_to(target.current_grid_pos) <= combat.attack_range + CHARGE_REACH
	if combat.charge_while_attacking and close and combat.can_see(target):
		movement.chase(target)
	elif in_range:
		movement.stop()
	else:
		var tile: Variant = entity.world.find_attack_tile(entity, target, allowed)
		if tile == null:
			return NO_ENGAGE
		movement.request_goal(tile)
	return Id.ATTACKING

# walk to the cheapest free objective tile and wait there
func _move_to_objective(entity: Entity) -> int:
	var map := entity.world.map
	var movement := entity.movement
	if movement == null or movement.is_waiting() or map.is_objective(entity.current_grid_pos) and not movement.is_moving():
		return Id.IDLE

	var goal: Variant = movement.goal_tile if movement.has_goal and map.is_objective(movement.goal_tile) else null
	# re-pick the objective tile now and then, in case a cheaper one opened up
	if goal == null or movement.is_repath_due():
		goal = map.find_nearest_objective_tile(movement.get_path_origin(), _taken_tiles(entity, map.objective_tiles))
	if goal == null:
		return Id.IDLE

	movement.request_goal(goal)
	return Id.MOVING if movement.is_moving() else Id.IDLE

# tiles from `tiles` that another unit is standing on or heading for
func _taken_tiles(entity: Entity, tiles: Array[Vector2i]) -> Dictionary:
	var taken := {}
	for tile in tiles:
		for other in entity.world.entities.get_entities_at_grid(tile):
			if other != entity and other.movement and not other.movement.is_moving():
				taken[tile] = true
	for other in entity.world.entities.by_team.get(entity.team, []):
		if other != entity and other.movement and other.movement.has_goal and other.movement.is_moving():
			taken[other.movement.goal_tile] = true
	return taken
