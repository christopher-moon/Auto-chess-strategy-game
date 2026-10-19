# behavior: the "brain" that decides which state a unit should be in each tick.
# behaviors are shared resources (one .tres for every unit using it), so they must stay stateless:
# per-unit memory lives on the unit's components (combat.target, movement.goal_tile)
class_name Behavior
extends Resource

const Id = StateMachine.StateId
# returned by _engage when the target can't be reached or attacked
const NO_ENGAGE := -1

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

# attack the target if it's in range, otherwise walk to the nearest tile we can attack it from.
# `allowed` can veto tiles to walk to (defenders use it to stay near the objective)
func _engage(entity: Entity, target: Entity, allowed: Callable = Callable()) -> int:
	if entity.combat.can_attack(target):
		return Id.ATTACKING
	if entity.movement == null:
		return NO_ENGAGE

	var tile: Variant = entity.world.find_attack_tile(entity, target, allowed)
	if tile == null:
		return NO_ENGAGE
	entity.movement.request_goal(tile)
	return Id.MOVING

# walk to the cheapest objective tile and wait there
func _move_to_objective(entity: Entity) -> int:
	var map := entity.world.map
	if entity.movement == null or map.is_objective(entity.current_grid_pos) and not entity.movement.is_moving():
		return Id.IDLE

	var movement := entity.movement
	var goal: Variant = movement.goal_tile if movement.has_goal and map.is_objective(movement.goal_tile) else null
	# re-pick the objective tile now and then, in case a cheaper one opened up
	if goal == null or entity.ticks_alive % MovementComponent.REPATH_TICKS == 0:
		goal = map.find_nearest_objective_tile(movement.get_path_origin())
	if goal == null:
		return Id.IDLE

	movement.request_goal(goal)
	return Id.MOVING
