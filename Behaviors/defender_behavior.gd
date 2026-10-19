# defender_behavior: objective first. walks to the objective, and only fights while it can do so
# from a tile within `leash_range` (walking distance) of an objective tile
class_name DefenderBehavior
extends Behavior

@export var leash_range: int = 3

func decide(entity: Entity) -> int:
	var combat := entity.combat
	var map := entity.world.map
	_validate_target(entity)
	_take_blocker_as_target(entity)

	var near_objective := func(tile: Vector2i) -> bool: return map.distance_to_objective(tile) <= leash_range

	# only look for fights once we are guarding the objective
	if not combat.has_valid_target() and near_objective.call(entity.current_grid_pos):
		combat.target = _acquire_target(entity, combat.threat_range)

	if combat.has_valid_target():
		# boxes in our way get broken wherever they are; enemies only get chased inside the leash
		var allowed: Callable = near_objective if entity.is_hostile_to(combat.target) else Callable()
		if allowed.is_valid() and not near_objective.call(entity.current_grid_pos) and not combat.can_attack(combat.target):
			combat.clear_target()
		else:
			var state := _engage(entity, combat.target, allowed)
			if state != NO_ENGAGE:
				return state
			combat.clear_target()

	return _move_to_objective(entity)
