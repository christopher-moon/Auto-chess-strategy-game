# attacker_behavior: combat first. fights any enemy inside its threat range, and only heads for the
# nearest objective tile when no enemy is in sight
class_name AttackerBehavior
extends Behavior

func decide(entity: Entity) -> int:
	var combat := entity.combat
	_validate_target(entity)
	_take_blocker_as_target(entity)

	if not combat.has_valid_target():
		combat.target = _acquire_target(entity, combat.threat_range)

	if combat.has_valid_target():
		var state := _engage(entity, combat.target)
		if state != NO_ENGAGE:
			return state
		combat.clear_target()

	return _move_to_objective(entity)
